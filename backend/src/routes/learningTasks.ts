import { Router } from "express";
import { Prisma } from "@prisma/client";
import { prisma } from "../prisma";

export const learningTasksRouter = Router();

const MAX_REWARD_POINTS = 1000000;
const MAX_AGE = 18;

function serializeTask(t: {
  id: string;
  name: string;
  description: string | null;
  subject: string | null;
  minAge: number | null;
  maxAge: number | null;
  rewardPoints: number;
}) {
  return {
    id: t.id,
    name: t.name,
    description: t.description,
    subject: t.subject,
    minAge: t.minAge,
    maxAge: t.maxAge,
    rewardPoints: t.rewardPoints,
  };
}

learningTasksRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;

  const tasks = await prisma.learningTask.findMany({
    where: { familyId },
    orderBy: { createdAt: "asc" },
  });

  res.json(tasks.map(serializeTask));
});

learningTasksRouter.post("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { name, description, subject, minAge, maxAge, rewardPoints } = req.body;

  if (typeof name !== "string" || name.trim().length === 0) {
    return res.status(400).json({ error: "name is required" });
  }
  if (description !== undefined && description !== null && typeof description !== "string") {
    return res.status(400).json({ error: "description must be a string" });
  }
  if (subject !== undefined && subject !== null && typeof subject !== "string") {
    return res.status(400).json({ error: "subject must be a string" });
  }
  for (const [label, value] of [
    ["minAge", minAge],
    ["maxAge", maxAge],
  ] as const) {
    if (value !== undefined && value !== null) {
      if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > MAX_AGE) {
        return res.status(400).json({ error: `${label} must be an integer between 0 and ${MAX_AGE}` });
      }
    }
  }
  if (
    minAge !== undefined &&
    minAge !== null &&
    maxAge !== undefined &&
    maxAge !== null &&
    minAge > maxAge
  ) {
    return res.status(400).json({ error: "minAge must not be greater than maxAge" });
  }
  if (
    typeof rewardPoints !== "number" ||
    !Number.isInteger(rewardPoints) ||
    rewardPoints <= 0 ||
    rewardPoints > MAX_REWARD_POINTS
  ) {
    return res
      .status(400)
      .json({ error: `rewardPoints must be an integer between 1 and ${MAX_REWARD_POINTS}` });
  }

  const task = await prisma.learningTask.create({
    data: {
      familyId,
      name: name.trim(),
      description: description ? description.trim() : null,
      subject: subject ? subject.trim() : null,
      minAge: minAge ?? null,
      maxAge: maxAge ?? null,
      rewardPoints,
    },
  });

  res.status(201).json(serializeTask(task));
});

learningTasksRouter.patch("/:taskId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { taskId } = req.params;
  const { name, description, subject, minAge, maxAge, rewardPoints } = req.body;

  const existing = await prisma.learningTask.findFirst({ where: { id: taskId, familyId } });
  if (!existing) {
    return res.status(404).json({ error: "Task not found" });
  }

  if (name !== undefined && (typeof name !== "string" || name.trim().length === 0)) {
    return res.status(400).json({ error: "name must be a non-empty string" });
  }
  if (description !== undefined && description !== null && typeof description !== "string") {
    return res.status(400).json({ error: "description must be a string" });
  }
  if (subject !== undefined && subject !== null && typeof subject !== "string") {
    return res.status(400).json({ error: "subject must be a string" });
  }
  for (const [label, value] of [
    ["minAge", minAge],
    ["maxAge", maxAge],
  ] as const) {
    if (value !== undefined && value !== null) {
      if (typeof value !== "number" || !Number.isInteger(value) || value < 0 || value > MAX_AGE) {
        return res.status(400).json({ error: `${label} must be an integer between 0 and ${MAX_AGE}` });
      }
    }
  }
  const effectiveMinAge = minAge !== undefined ? minAge : existing.minAge;
  const effectiveMaxAge = maxAge !== undefined ? maxAge : existing.maxAge;
  if (
    effectiveMinAge !== undefined &&
    effectiveMinAge !== null &&
    effectiveMaxAge !== undefined &&
    effectiveMaxAge !== null &&
    effectiveMinAge > effectiveMaxAge
  ) {
    return res.status(400).json({ error: "minAge must not be greater than maxAge" });
  }
  if (
    rewardPoints !== undefined &&
    (typeof rewardPoints !== "number" ||
      !Number.isInteger(rewardPoints) ||
      rewardPoints <= 0 ||
      rewardPoints > MAX_REWARD_POINTS)
  ) {
    return res
      .status(400)
      .json({ error: `rewardPoints must be an integer between 1 and ${MAX_REWARD_POINTS}` });
  }

  const task = await prisma.learningTask.update({
    where: { id: taskId },
    data: {
      ...(name !== undefined ? { name: name.trim() } : {}),
      ...(description !== undefined ? { description: description ? description.trim() : null } : {}),
      ...(subject !== undefined ? { subject: subject ? subject.trim() : null } : {}),
      ...(minAge !== undefined ? { minAge } : {}),
      ...(maxAge !== undefined ? { maxAge } : {}),
      ...(rewardPoints !== undefined ? { rewardPoints } : {}),
    },
  });

  res.json(serializeTask(task));
});

learningTasksRouter.delete("/:taskId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { taskId } = req.params;

  const task = await prisma.learningTask.findFirst({ where: { id: taskId, familyId } });
  if (!task) {
    return res.status(404).json({ error: "Task not found" });
  }

  try {
    await prisma.learningTask.delete({ where: { id: taskId } });
  } catch (e) {
    if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === "P2003") {
      return res.status(409).json({ error: "Cannot delete a task that has already been completed" });
    }
    throw e;
  }

  res.status(204).send();
});
