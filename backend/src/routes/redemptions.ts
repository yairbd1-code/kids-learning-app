import { Router } from "express";
import { prisma } from "../prisma";
import { applyPointsDelta, InsufficientBalanceError } from "../points";

export const redemptionsRouter = Router({ mergeParams: true });

redemptionsRouter.get("/", async (req, res) => {
  const childId = (req.params as { childId: string }).childId;
  const familyId = req.auth!.familyId;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const redemptions = await prisma.redemption.findMany({
    where: { childId },
    include: { reward: true },
    orderBy: { createdAt: "desc" },
  });

  res.json(
    redemptions.map((r) => ({
      id: r.id,
      rewardName: r.reward.name,
      pointsSpent: r.pointsSpent,
      createdAt: r.createdAt,
    })),
  );
});

redemptionsRouter.post("/", async (req, res) => {
  const childId = (req.params as { childId: string }).childId;
  const familyId = req.auth!.familyId;
  const { rewardId } = req.body;

  if (typeof rewardId !== "string" || rewardId.length === 0) {
    return res.status(400).json({ error: "rewardId is required" });
  }

  const child = await prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  const reward = await prisma.reward.findFirst({ where: { id: rewardId, familyId } });
  if (!reward) {
    return res.status(404).json({ error: "Reward not found" });
  }

  if (child.wallet.balance < reward.costPoints) {
    return res.status(400).json({ error: "Insufficient points balance" });
  }

  const walletId = child.wallet.id;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const transaction = await tx.pointsTransaction.create({
        data: {
          walletId,
          amount: -reward.costPoints,
          reason: `מימוש פרס: ${reward.name}`,
        },
      });

      const newBalance = await applyPointsDelta(tx, walletId, -reward.costPoints);

      const redemption = await tx.redemption.create({
        data: {
          childId,
          rewardId: reward.id,
          pointsSpent: reward.costPoints,
          pointsTransactionId: transaction.id,
        },
      });

      return { redemption, newBalance };
    });

    res.status(201).json({
      id: result.redemption.id,
      rewardName: reward.name,
      pointsSpent: result.redemption.pointsSpent,
      createdAt: result.redemption.createdAt,
      newBalance: result.newBalance,
    });
  } catch (e) {
    if (e instanceof InsufficientBalanceError) {
      return res.status(400).json({ error: "Insufficient points balance" });
    }
    throw e;
  }
});
