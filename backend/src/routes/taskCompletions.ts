import { Router } from "express";
import { prisma } from "../prisma";
import { applyPointsDelta, InsufficientBalanceError } from "../points";

export const taskCompletionsRouter = Router({ mergeParams: true });

taskCompletionsRouter.get("/", async (req, res) => {
  const childId = (req.params as { childId: string }).childId;
  const familyId = req.auth!.familyId;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const completions = await prisma.taskCompletion.findMany({
    where: { childId },
    include: { task: true },
    orderBy: { createdAt: "desc" },
  });

  res.json(
    completions.map((c) => ({
      id: c.id,
      taskName: c.task.name,
      pointsAwarded: c.pointsAwarded,
      createdAt: c.createdAt,
    })),
  );
});

taskCompletionsRouter.post("/", async (req, res) => {
  const childId = (req.params as { childId: string }).childId;
  const familyId = req.auth!.familyId;
  const { taskId } = req.body;

  if (typeof taskId !== "string" || taskId.length === 0) {
    return res.status(400).json({ error: "taskId is required" });
  }

  const child = await prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  const task = await prisma.learningTask.findFirst({ where: { id: taskId, familyId } });
  if (!task) {
    return res.status(404).json({ error: "Task not found" });
  }

  const walletId = child.wallet.id;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const transaction = await tx.pointsTransaction.create({
        data: {
          walletId,
          amount: task.rewardPoints,
          reason: `השלמת משימה: ${task.name}`,
        },
      });

      const newBalance = await applyPointsDelta(tx, walletId, task.rewardPoints);

      const completion = await tx.taskCompletion.create({
        data: {
          childId,
          taskId: task.id,
          pointsAwarded: task.rewardPoints,
          pointsTransactionId: transaction.id,
        },
      });

      return { completion, newBalance };
    });

    res.status(201).json({
      id: result.completion.id,
      taskName: task.name,
      pointsAwarded: result.completion.pointsAwarded,
      createdAt: result.completion.createdAt,
      newBalance: result.newBalance,
    });
  } catch (e) {
    if (e instanceof InsufficientBalanceError) {
      // לא אמור לקרות (זיכוי תמיד חוקי), אבל נשמר לעקביות עם applyPointsDelta.
      return res.status(400).json({ error: "Unable to credit points" });
    }
    throw e;
  }
});
