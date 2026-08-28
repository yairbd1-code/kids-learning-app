-- Clearing existing seed/test content: the practice engine's data model is
-- being restructured from a flat 3-tier difficulty to grade (1-8) x 3-tier,
-- so old rows (age-range based, no grade_level) are no longer compatible.
DELETE FROM "practice_attempts";
DELETE FROM "questions";

-- AlterTable
ALTER TABLE "child_subject_progress" ADD COLUMN     "current_grade" INTEGER NOT NULL DEFAULT 1;

-- AlterTable
ALTER TABLE "questions" DROP COLUMN "max_age",
DROP COLUMN "min_age",
ADD COLUMN     "grade_level" INTEGER NOT NULL;
