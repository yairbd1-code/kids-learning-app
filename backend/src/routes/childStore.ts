import { Router } from "express";
import { prisma } from "../prisma";

export const childStoreRouter = Router();

childStoreRouter.get("/balance", async (req, res) => {
  const { childId, familyId } = req.childAuth!;

  const child = await prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  res.json({ balance: child.wallet.balance });
});

childStoreRouter.get("/rewards", async (req, res) => {
  const { familyId } = req.childAuth!;

  const rewards = await prisma.reward.findMany({
    where: { familyId },
    orderBy: { costPoints: "asc" },
  });

  res.json(rewards.map((r) => ({ id: r.id, name: r.name, costPoints: r.costPoints })));
});

childStoreRouter.get("/redemptions", async (req, res) => {
  const { childId, familyId } = req.childAuth!;

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

childStoreRouter.post("/redemptions", async (req, res) => {
  const { childId, familyId } = req.childAuth!;
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
    return res.status(400).json({ error: "אין מספיק נקודות לבקשה הזו" });
  }

  // בקשה בלבד — אין קיזוז נקודות עדיין. הנקודות מקוזזות רק כשההורה מאשר,
  // כי המימוש עצמו (מתן הפרס בפועל) תלוי בהורה.
  const redemption = await prisma.redemption.create({
    data: {
      childId,
      rewardId: reward.id,
      pointsSpent: reward.costPoints,
      status: "PENDING",
    },
  });

  res.status(201).json({
    id: redemption.id,
    rewardName: reward.name,
    pointsSpent: redemption.pointsSpent,
    status: redemption.status,
    createdAt: redemption.createdAt,
  });
});
