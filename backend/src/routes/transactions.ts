import { Router } from "express";
import { prisma } from "../prisma";
import { applyPointsDelta, InsufficientBalanceError } from "../points";

export const transactionsRouter = Router({ mergeParams: true });

const MAX_ABS_AMOUNT = 100000;

async function findOwnedChildWithWallet(childId: string, familyId: string) {
  return prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
}

transactionsRouter.get("/", async (req, res) => {
  const childId = (req.params as { childId: string }).childId;
  const familyId = req.auth!.familyId;

  const child = await findOwnedChildWithWallet(childId, familyId);
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  const transactions = await prisma.pointsTransaction.findMany({
    where: { walletId: child.wallet.id },
    orderBy: { createdAt: "desc" },
  });

  res.json(
    transactions.map((t) => ({
      id: t.id,
      amount: t.amount,
      reason: t.reason,
      createdAt: t.createdAt,
    })),
  );
});

transactionsRouter.post("/", async (req, res) => {
  const childId = (req.params as { childId: string }).childId;
  const familyId = req.auth!.familyId;
  const { amount, reason } = req.body;

  const child = await findOwnedChildWithWallet(childId, familyId);
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  if (typeof amount !== "number" || !Number.isInteger(amount) || amount === 0) {
    return res.status(400).json({ error: "amount must be a nonzero integer" });
  }
  if (Math.abs(amount) > MAX_ABS_AMOUNT) {
    return res.status(400).json({ error: `amount must be at most ${MAX_ABS_AMOUNT}` });
  }
  if (typeof reason !== "string" || reason.trim().length === 0) {
    return res.status(400).json({ error: "reason is required" });
  }

  const walletId = child.wallet.id;

  try {
    const result = await prisma.$transaction(async (tx) => {
      const transaction = await tx.pointsTransaction.create({
        data: { walletId, amount, reason: reason.trim() },
      });
      const newBalance = await applyPointsDelta(tx, walletId, amount);
      return { transaction, newBalance };
    });

    res.status(201).json({
      id: result.transaction.id,
      amount: result.transaction.amount,
      reason: result.transaction.reason,
      createdAt: result.transaction.createdAt,
      newBalance: result.newBalance,
    });
  } catch (e) {
    if (e instanceof InsufficientBalanceError) {
      return res.status(400).json({ error: "Insufficient points balance" });
    }
    throw e;
  }
});
