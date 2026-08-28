-- CreateEnum
CREATE TYPE "Difficulty" AS ENUM ('EASY', 'MEDIUM', 'HARD');

-- AlterTable
ALTER TABLE "children" ADD COLUMN     "pin_hash" TEXT;

-- CreateTable
CREATE TABLE "questions" (
    "id" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "difficulty" "Difficulty" NOT NULL,
    "min_age" INTEGER,
    "max_age" INTEGER,
    "question_text" TEXT NOT NULL,
    "options" TEXT[],
    "correct_option_index" INTEGER NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "questions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "child_subject_progress" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "subject" TEXT NOT NULL,
    "current_difficulty" "Difficulty" NOT NULL DEFAULT 'MEDIUM',
    "consecutive_correct" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "child_subject_progress_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "practice_attempts" (
    "id" TEXT NOT NULL,
    "child_id" TEXT NOT NULL,
    "question_id" TEXT NOT NULL,
    "is_correct" BOOLEAN NOT NULL,
    "points_awarded" INTEGER NOT NULL DEFAULT 0,
    "points_transaction_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "practice_attempts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "child_subject_progress_child_id_subject_key" ON "child_subject_progress"("child_id", "subject");

-- CreateIndex
CREATE UNIQUE INDEX "practice_attempts_points_transaction_id_key" ON "practice_attempts"("points_transaction_id");

-- AddForeignKey
ALTER TABLE "child_subject_progress" ADD CONSTRAINT "child_subject_progress_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "practice_attempts" ADD CONSTRAINT "practice_attempts_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "children"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "practice_attempts" ADD CONSTRAINT "practice_attempts_question_id_fkey" FOREIGN KEY ("question_id") REFERENCES "questions"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "practice_attempts" ADD CONSTRAINT "practice_attempts_points_transaction_id_fkey" FOREIGN KEY ("points_transaction_id") REFERENCES "points_transactions"("id") ON DELETE SET NULL ON UPDATE CASCADE;
