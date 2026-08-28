-- CreateTable
CREATE TABLE "points_transactions" (
    "id" TEXT NOT NULL,
    "wallet_id" TEXT NOT NULL,
    "amount" INTEGER NOT NULL,
    "reason" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "points_transactions_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "points_transactions" ADD CONSTRAINT "points_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "points_wallets"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
