import { Prisma } from "@prisma/client";

export class InsufficientBalanceError extends Error {}

/**
 * Locks the wallet row (SELECT ... FOR UPDATE) before applying the delta, so
 * concurrent requests against the same wallet can't race past the balance
 * check and both succeed when only one should (lost-update / overspend bug).
 */
export async function applyPointsDelta(
  tx: Prisma.TransactionClient,
  walletId: string,
  amount: number,
): Promise<number> {
  const rows = await tx.$queryRaw<{ balance: number }[]>`
    SELECT balance FROM points_wallets WHERE id = ${walletId} FOR UPDATE
  `;
  const current = rows[0]?.balance ?? 0;
  const newBalance = current + amount;

  if (newBalance < 0) {
    throw new InsufficientBalanceError();
  }

  await tx.pointsWallet.update({ where: { id: walletId }, data: { balance: newBalance } });
  return newBalance;
}
