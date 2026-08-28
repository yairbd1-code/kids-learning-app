-- AlterTable
ALTER TABLE "children" ADD COLUMN     "disabled_subjects" TEXT[] DEFAULT ARRAY[]::TEXT[];
