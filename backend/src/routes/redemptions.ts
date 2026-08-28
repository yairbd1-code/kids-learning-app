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
      status: r.status,
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
          status: "APPROVED",
          pointsTransactionId: transaction.id,
        },
      });

      return { redemption, newBalance };
    });

    res.status(201).json({
      id: result.redemption.id,
      rewardName: reward.name,
      pointsSpent: result.redemption.pointsSpent,
      status: result.redemption.status,
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

redemptionsRouter.patch("/:redemptionId", async (req, res) => {
  const { childId, redemptionId } = req.params as { childId: string; redemptionId: string };
  const familyId = req.auth!.familyId;
  const { approve } = req.body;

  if (typeof approve !== "boolean") {
    return res.status(400).json({ error: "approve (boolean) is required" });
  }

  const child = await prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  const redemption = await prisma.redemption.findFirst({
    where: { id: redemptionId, childId },
    include: { reward: true },
  });
  if (!redemption) {
    return res.status(404).json({ error: "Redemption not found" });
  }
  if (redemption.status !== "PENDING") {
    return res.status(400).json({ error: "רק בקשות ממתינות אפשר לאשר או לדחות" });
  }

  if (!approve) {
    const rejected = await prisma.redemption.update({
      where: { id: redemptionId },
      data: { status: "REJECTED" },
    });
    return res.json({
      id: rejected.id,
      rewardName: redemption.reward.name,
      pointsSpent: rejected.pointsSpent,
      status: rejected.status,
      createdAt: rejected.createdAt,
      newBalance: child.wallet.balance,
    });
  }

  const walletId = child.wallet.id;
  try {
    const result = await prisma.$transaction(async (tx) => {
      const transaction = await tx.pointsTransaction.create({
        data: {
          walletId,
          amount: -redemption.pointsSpent,
          reason: `מימוש פרס: ${redemption.reward.name}`,
        },
      });

      const newBalance = await applyPointsDelta(tx, walletId, -redemption.pointsSpent);

      const approved = await tx.redemption.update({
        where: { id: redemptionId },
        data: { status: "APPROVED", pointsTransactionId: transaction.id },
      });

      return { approved, newBalance };
    });

    res.json({
      id: result.approved.id,
      rewardName: redemption.reward.name,
      pointsSpent: result.approved.pointsSpent,
      status: result.approved.status,
      createdAt: result.approved.createdAt,
      newBalance: result.newBalance,
    });
  } catch (e) {
    if (e instanceof InsufficientBalanceError) {
      return res.status(400).json({ error: "אין לילד מספיק נקודות כרגע לאישור הבקשה" });
    }
    throw e;
  }
});
