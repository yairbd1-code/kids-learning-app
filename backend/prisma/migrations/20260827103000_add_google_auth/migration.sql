-- CreateEnum
CREATE TYPE "AuthProvider" AS ENUM ('PASSWORD', 'GOOGLE');

-- AlterTable
ALTER TABLE "parent_users" ADD COLUMN     "auth_provider" "AuthProvider" NOT NULL DEFAULT 'PASSWORD',
ADD COLUMN     "google_id" TEXT,
ALTER COLUMN "password_hash" DROP NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "parent_users_google_id_key" ON "parent_users"("google_id");
