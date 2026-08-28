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

// הערכת כיתת פתיחה סבירה לפי גיל, כדי שילד חדש לא יתחיל תמיד מכיתה א'.
// כיתה א' בישראל מתחילה סביב גיל 6, ולכן: כיתה משוערת = גיל - 5.
function defaultGradeForAge(age: number): number {
  const estimated = age - 5;
  return Math.min(MAX_GRADE, Math.max(MIN_GRADE, estimated));
}

practiceRouter.get("/subjects", async (req, res) => {
  const { childId, familyId } = req.childAuth!;
  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const enabledSubjects = ALLOWED_SUBJECTS.filter(
    (subject) => !child.disabledSubjects.includes(subject),
  );
  res.json(enabledSubjects);
});

async function findQuestionForSubject(
  child: { id: string; age: number },
  subject: string,
  familyId: string,
) {
  const progress = await prisma.childSubjectProgress.upsert({
    where: { childId_subject: { childId: child.id, subject } },
    create: { childId: child.id, subject, currentGrade: defaultGradeForAge(child.age) },
    update: {},
  });

  const candidates = await prisma.question.findMany({
    where: {
      subject,
      gradeLevel: progress.currentGrade,
      difficulty: progress.currentDifficulty,
      approved: true,
      OR: [{ familyId: null }, { familyId }],
    },
  });

  if (candidates.length === 0) return null;
  return candidates[Math.floor(Math.random() * candidates.length)];
}

function serializeQuestion(question: {
  id: string;
  subject: string;
  gradeLevel: number;
  difficulty: Difficulty;
  questionText: string;
  options: string[];
}) {
  return {
    id: question.id,
    subject: question.subject,
    gradeLevel: question.gradeLevel,
    difficulty: question.difficulty,
    questionText: question.questionText,
    options: question.options,
  };
}

// בוחר מקצוע אקראי לפי משקלים (weights); ברירת מחדל: פיצול שווה בין המקצועות הפעילים.
function pickWeightedSubject(enabledSubjects: string[], weights: unknown): string {
  const weightMap = (
    weights && typeof weights === "object" && !Array.isArray(weights) ? weights : {}
  ) as Record<string, number>;

  const entries = enabledSubjects.map((subject) => ({
    subject,
    weight: typeof weightMap[subject] === "number" && weightMap[subject] >= 0 ? weightMap[subject] : 1,
  }));

  const totalWeight = entries.reduce((sum, e) => sum + e.weight, 0);
  if (totalWeight <= 0) {
    return enabledSubjects[Math.floor(Math.random() * enabledSubjects.length)];
  }

  let roll = Math.random() * totalWeight;
  for (const entry of entries) {
    roll -= entry.weight;
    if (roll <= 0) return entry.subject;
  }
  return entries[entries.length - 1].subject;
}

// חייב להירשם לפני "/:subject/next-question" — אחרת "mixed" ייתפס כפרמטר subject.
practiceRouter.get("/mixed/next-question", async (req, res) => {
  const { childId, familyId } = req.childAuth!;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const enabledSubjects = ALLOWED_SUBJECTS.filter(
    (subject) => !child.disabledSubjects.includes(subject),
  );
  if (enabledSubjects.length === 0) {
    return res.status(404).json({ error: "אין מקצועות פעילים עבור ילד זה" });
  }

  // מנסים תחילה את המקצוע שנבחר לפי המשקלים, ואם אין לו שאלות זמינות כרגע
  // (מאגר דל), עוברים לנסות את שאר המקצועות הפעילים לפי סדר אקראי, כדי
  // שילד לא "ייתקע" רק כי המקצוע שנבחר באקראי חסר תוכן ברמה שלו כרגע.
  const firstPick = pickWeightedSubject([...enabledSubjects], child.subjectWeights);
  const remaining = enabledSubjects.filter((s) => s !== firstPick);
  for (let i = remaining.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [remaining[i], remaining[j]] = [remaining[j], remaining[i]];
  }
  const trialOrder = [firstPick, ...remaining];

  for (const subject of trialOrder) {
    const question = await findQuestionForSubject(child, subject, familyId);
    if (question) {
      return res.json(serializeQuestion(question));
    }
  }

  res.status(404).json({ error: "No questions available for this level yet" });
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
  if (child.disabledSubjects.includes(subject)) {
    return res.status(403).json({ error: "מקצוע זה חסום עבור ילד זה" });
  }

  const question = await findQuestionForSubject(child, subject, familyId);
  if (!question) {
    return res.status(404).json({ error: "No questions available for this level yet" });
  }

  res.json(serializeQuestion(question));
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
  if (child.disabledSubjects.includes(question.subject)) {
    return res.status(403).json({ error: "מקצוע זה חסום עבור ילד זה" });
  }

  const isCorrect = selectedOptionIndex === question.correctOptionIndex;
  const walletId = child.wallet.id;
  const subject = question.subject;

  const result = await prisma.$transaction(async (tx) => {
    const progress = await tx.childSubjectProgress.upsert({
      where: { childId_subject: { childId, subject } },
      create: { childId, subject, currentGrade: defaultGradeForAge(child.age) },
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
