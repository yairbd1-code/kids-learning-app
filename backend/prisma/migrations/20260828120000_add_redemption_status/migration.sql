-- CreateEnum
CREATE TYPE "RedemptionStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

-- DropForeignKey
ALTER TABLE "redemptions" DROP CONSTRAINT "redemptions_points_transaction_id_fkey";

-- AlterTable
ALTER TABLE "redemptions" ADD COLUMN     "status" "RedemptionStatus" NOT NULL DEFAULT 'APPROVED',
ALTER COLUMN "points_transaction_id" DROP NOT NULL;

-- AddForeignKey
ALTER TABLE "redemptions" ADD CONSTRAINT "redemptions_points_transaction_id_fkey" FOREIGN KEY ("points_transaction_id") REFERENCES "points_transactions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
