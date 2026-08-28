import { Router } from "express";
import { Difficulty } from "@prisma/client";
import { prisma } from "../prisma";
import { ALLOWED_SUBJECTS } from "./practice";

export const subjectProgressRouter = Router({ mergeParams: true });

const VALID_DIFFICULTIES: Difficulty[] = ["EASY", "MEDIUM", "HARD"];
const MIN_GRADE = 1;
const MAX_GRADE = 8;

subjectProgressRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const childId = (req.params as { childId: string }).childId;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const progress = await prisma.childSubjectProgress.findMany({ where: { childId } });
  const bySubject = new Map(progress.map((p) => [p.subject, p]));

  res.json(
    ALLOWED_SUBJECTS.map((subject) => {
      const p = bySubject.get(subject);
      return {
        subject,
        currentGrade: p?.currentGrade ?? 1,
        currentDifficulty: p?.currentDifficulty ?? "MEDIUM",
      };
    }),
  );
});

subjectProgressRouter.patch("/:subject", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { childId, subject } = req.params as { childId: string; subject: string };
  const { currentGrade, currentDifficulty } = req.body;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }
  if (!(ALLOWED_SUBJECTS as readonly string[]).includes(subject)) {
    return res.status(400).json({ error: "Unknown subject" });
  }
  if (typeof currentDifficulty !== "string" || !VALID_DIFFICULTIES.includes(currentDifficulty as Difficulty)) {
    return res.status(400).json({ error: "currentDifficulty must be EASY, MEDIUM, or HARD" });
  }
  if (
    typeof currentGrade !== "number" ||
    !Number.isInteger(currentGrade) ||
    currentGrade < MIN_GRADE ||
    currentGrade > MAX_GRADE
  ) {
    return res.status(400).json({ error: `currentGrade must be an integer between ${MIN_GRADE} and ${MAX_GRADE}` });
  }

  const progress = await prisma.childSubjectProgress.upsert({
    where: { childId_subject: { childId, subject } },
    create: {
      childId,
      subject,
      currentGrade,
      currentDifficulty: currentDifficulty as Difficulty,
      consecutiveCorrect: 0,
    },
    update: {
      currentGrade,
      currentDifficulty: currentDifficulty as Difficulty,
      consecutiveCorrect: 0,
    },
  });

  res.json({ subject: progress.subject, currentGrade: progress.currentGrade, currentDifficulty: progress.currentDifficulty });
});
