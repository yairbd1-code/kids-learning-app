import { Router } from "express";
import { Difficulty } from "@prisma/client";
import { prisma } from "../prisma";
import { applyPointsDelta } from "../points";

export const practiceRouter = Router();

export const ALLOWED_SUBJECTS = ["english", "math", "hebrew"] as const;
export type Subject = (typeof ALLOWED_SUBJECTS)[number];

const POINTS_PER_CORRECT = 3;
const LEVEL_UP_STREAK = 3;
const DIFFICULTY_ORDER: Difficulty[] = ["EASY", "MEDIUM", "HARD"];
const MIN_GRADE = 1;
const MAX_GRADE = 8;

function advanceLevel(currentGrade: number, currentDifficulty: Difficulty) {
  const currentIndex = DIFFICULTY_ORDER.indexOf(currentDifficulty);
  if (currentIndex < DIFFICULTY_ORDER.length - 1) {
    return { grade: currentGrade, difficulty: DIFFICULTY_ORDER[currentIndex + 1] };
  }
  if (currentGrade < MAX_GRADE) {
    return { grade: currentGrade + 1, difficulty: DIFFICULTY_ORDER[0] };
  }
  return { grade: currentGrade, difficulty: currentDifficulty };
}

function retreatLevel(currentGrade: number, currentDifficulty: Difficulty) {
  const currentIndex = DIFFICULTY_ORDER.indexOf(currentDifficulty);
  if (currentIndex > 0) {
    return { grade: currentGrade, difficulty: DIFFICULTY_ORDER[currentIndex - 1] };
  }
  if (currentGrade > MIN_GRADE) {
    return { grade: currentGrade - 1, difficulty: DIFFICULTY_ORDER[DIFFICULTY_ORDER.length - 1] };
  }
  return { grade: currentGrade, difficulty: currentDifficulty };
}

practiceRouter.get("/subjects", (_req, res) => {
  res.json(ALLOWED_SUBJECTS);
});

practiceRouter.get("/:subject/next-question", async (req, res) => {
  const { childId, familyId } = req.childAuth!;
  const subject = req.params.subject;

  if (!(ALLOWED_SUBJECTS as readonly string[]).includes(subject)) {
    return res.status(400).json({ error: "Unknown subject" });
  }

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const progress = await prisma.childSubjectProgress.upsert({
    where: { childId_subject: { childId, subject } },
    create: { childId, subject },
    update: {},
  });

  const candidates = await prisma.question.findMany({
    where: {
      subject,
      gradeLevel: progress.currentGrade,
      difficulty: progress.currentDifficulty,
    },
  });

  if (candidates.length === 0) {
    return res.status(404).json({ error: "No questions available for this level yet" });
  }

  const question = candidates[Math.floor(Math.random() * candidates.length)];

  res.json({
    id: question.id,
    subject: question.subject,
    gradeLevel: question.gradeLevel,
    difficulty: question.difficulty,
    questionText: question.questionText,
    options: question.options,
  });
});

practiceRouter.post("/answer", async (req, res) => {
  const { childId, familyId } = req.childAuth!;
  const { questionId, selectedOptionIndex } = req.body;

  if (typeof questionId !== "string" || typeof selectedOptionIndex !== "number") {
    return res.status(400).json({ error: "questionId and selectedOptionIndex are required" });
  }

  const child = await prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
  if (!child || !child.wallet) {
    return res.status(404).json({ error: "Child not found" });
  }

  const question = await prisma.question.findUnique({ where: { id: questionId } });
  if (!question) {
    return res.status(404).json({ error: "Question not found" });
  }

  const isCorrect = selectedOptionIndex === question.correctOptionIndex;
  const walletId = child.wallet.id;
  const subject = question.subject;

  const result = await prisma.$transaction(async (tx) => {
    const progress = await tx.childSubjectProgress.upsert({
      where: { childId_subject: { childId, subject } },
      create: { childId, subject },
      update: {},
    });

    let pointsAwarded = 0;
    let newBalance = child.wallet!.balance;
    let newStreak = progress.consecutiveCorrect;
    let newGrade = progress.currentGrade;
    let newDifficulty = progress.currentDifficulty;

    if (isCorrect) {
      pointsAwarded = POINTS_PER_CORRECT;
      const transaction = await tx.pointsTransaction.create({
        data: { walletId, amount: pointsAwarded, reason: `תרגול נכון: ${subject}` },
      });
      newBalance = await applyPointsDelta(tx, walletId, pointsAwarded);

      newStreak += 1;
      if (newStreak >= LEVEL_UP_STREAK) {
        const next = advanceLevel(progress.currentGrade, progress.currentDifficulty);
        newGrade = next.grade;
        newDifficulty = next.difficulty;
        newStreak = 0;
      }

      await tx.childSubjectProgress.update({
        where: { id: progress.id },
        data: { currentGrade: newGrade, currentDifficulty: newDifficulty, consecutiveCorrect: newStreak },
      });

      const attempt = await tx.practiceAttempt.create({
        data: {
          childId,
          questionId,
          isCorrect,
          pointsAwarded,
          pointsTransactionId: transaction.id,
        },
      });

      return { attempt, newGrade, newDifficulty, newBalance };
    }

    newStreak = 0;
    const prev = retreatLevel(progress.currentGrade, progress.currentDifficulty);
    newGrade = prev.grade;
    newDifficulty = prev.difficulty;

    await tx.childSubjectProgress.update({
      where: { id: progress.id },
      data: { currentGrade: newGrade, currentDifficulty: newDifficulty, consecutiveCorrect: newStreak },
    });

    const attempt = await tx.practiceAttempt.create({
      data: { childId, questionId, isCorrect, pointsAwarded: 0 },
    });

    return { attempt, newGrade, newDifficulty, newBalance };
  });

  res.json({
    correct: isCorrect,
    correctOptionIndex: question.correctOptionIndex,
    explanation: question.explanation,
    pointsAwarded: result.attempt.pointsAwarded,
    newBalance: result.newBalance,
    newGrade: result.newGrade,
    newDifficulty: result.newDifficulty,
  });
});
