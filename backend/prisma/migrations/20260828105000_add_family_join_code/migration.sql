-- AlterTable
ALTER TABLE "families" ADD COLUMN "join_code" TEXT;

-- Backfill a random 6-character code for any families created before this column existed.
UPDATE "families" SET "join_code" = upper(substr(md5(random()::text || id::text), 1, 6))
WHERE "join_code" IS NULL;

-- AlterTable
ALTER TABLE "families" ALTER COLUMN "join_code" SET NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "families_join_code_key" ON "families"("join_code");
