import { Router } from "express";
import { prisma } from "../prisma";
import { ALLOWED_SUBJECTS } from "./practice";

export const practiceStatsRouter = Router({ mergeParams: true });

practiceStatsRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const childId = (req.params as { childId: string }).childId;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const [attempts, progressRows] = await Promise.all([
    prisma.practiceAttempt.findMany({
      where: { childId },
      include: { question: { select: { subject: true } } },
    }),
    prisma.childSubjectProgress.findMany({ where: { childId } }),
  ]);

  const progressBySubject = new Map(progressRows.map((p) => [p.subject, p]));
  const statsBySubject = new Map<string, { total: number; correct: number }>();

  for (const attempt of attempts) {
    const subject = attempt.question.subject;
    const current = statsBySubject.get(subject) ?? { total: 0, correct: 0 };
    current.total += 1;
    if (attempt.isCorrect) current.correct += 1;
    statsBySubject.set(subject, current);
  }

  const result = ALLOWED_SUBJECTS.map((subject) => {
    const stats = statsBySubject.get(subject) ?? { total: 0, correct: 0 };
    const progress = progressBySubject.get(subject);
    return {
      subject,
      currentGrade: progress?.currentGrade ?? null,
      currentDifficulty: progress?.currentDifficulty ?? null,
      totalAnswered: stats.total,
      totalCorrect: stats.correct,
      correctPercent: stats.total === 0 ? null : Math.round((stats.correct / stats.total) * 100),
    };
  });

  res.json(result);
});
