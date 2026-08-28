import { Router } from "express";
import { Prisma } from "@prisma/client";
import { prisma } from "../prisma";

export const rewardsRouter = Router();

const MAX_COST_POINTS = 1000000;

rewardsRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;

  const rewards = await prisma.reward.findMany({
    where: { familyId },
    orderBy: { createdAt: "asc" },
  });

  res.json(
    rewards.map((r) => ({ id: r.id, name: r.name, costPoints: r.costPoints })),
  );
});

rewardsRouter.post("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { name, costPoints } = req.body;

  if (typeof name !== "string" || name.trim().length === 0) {
    return res.status(400).json({ error: "name is required" });
  }
  if (
    typeof costPoints !== "number" ||
    !Number.isInteger(costPoints) ||
    costPoints <= 0 ||
    costPoints > MAX_COST_POINTS
  ) {
    return res.status(400).json({ error: `costPoints must be an integer between 1 and ${MAX_COST_POINTS}` });
  }

  const reward = await prisma.reward.create({
    data: { familyId, name: name.trim(), costPoints },
  });

  res.status(201).json({ id: reward.id, name: reward.name, costPoints: reward.costPoints });
});

rewardsRouter.patch("/:rewardId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { rewardId } = req.params;
  const { name, costPoints } = req.body;

  const existing = await prisma.reward.findFirst({ where: { id: rewardId, familyId } });
  if (!existing) {
    return res.status(404).json({ error: "Reward not found" });
  }

  if (name !== undefined && (typeof name !== "string" || name.trim().length === 0)) {
    return res.status(400).json({ error: "name must be a non-empty string" });
  }
  if (
    costPoints !== undefined &&
    (typeof costPoints !== "number" ||
      !Number.isInteger(costPoints) ||
      costPoints <= 0 ||
      costPoints > MAX_COST_POINTS)
  ) {
    return res
      .status(400)
      .json({ error: `costPoints must be an integer between 1 and ${MAX_COST_POINTS}` });
  }

  const reward = await prisma.reward.update({
    where: { id: rewardId },
    data: {
      ...(name !== undefined ? { name: name.trim() } : {}),
      ...(costPoints !== undefined ? { costPoints } : {}),
    },
  });

  res.json({ id: reward.id, name: reward.name, costPoints: reward.costPoints });
});

rewardsRouter.delete("/:rewardId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { rewardId } = req.params;

  const reward = await prisma.reward.findFirst({ where: { id: rewardId, familyId } });
  if (!reward) {
    return res.status(404).json({ error: "Reward not found" });
  }

  try {
    await prisma.reward.delete({ where: { id: rewardId } });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2003") {
      return res.status(409).json({ error: "Cannot delete a reward that has already been redeemed" });
    }
    throw e;
  }

  res.status(204).send();
});
