-- CreateEnum
CREATE TYPE "QuestionSource" AS ENUM ('SEED', 'AI');

-- AlterTable
ALTER TABLE "questions" ADD COLUMN     "approved" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "family_id" TEXT,
ADD COLUMN     "source" "QuestionSource" NOT NULL DEFAULT 'SEED';

-- AddForeignKey
ALTER TABLE "questions" ADD CONSTRAINT "questions_family_id_fkey" FOREIGN KEY ("family_id") REFERENCES "families"("id") ON DELETE SET NULL ON UPDATE CASCADE;
