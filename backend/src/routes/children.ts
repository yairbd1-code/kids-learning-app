import { Router } from "express";
import bcrypt from "bcryptjs";
import { prisma } from "../prisma";
import { signChildToken } from "../auth/jwt";

export const childrenRouter = Router();

function serializeChild(child: {
  id: string;
  name: string;
  age: number;
  grade: string | null;
  pinHash: string | null;
  wallet: { balance: number } | null;
}) {
  return {
    id: child.id,
    name: child.name,
    age: child.age,
    grade: child.grade,
    pointsBalance: child.wallet?.balance ?? 0,
    hasPin: child.pinHash !== null,
  };
}

childrenRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;

  const children = await prisma.child.findMany({
    where: { familyId },
    include: { wallet: true },
    orderBy: { createdAt: "asc" },
  });

  res.json(children.map(serializeChild));
});

childrenRouter.post("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { name, age, grade } = req.body;

  if (typeof name !== "string" || name.trim().length === 0) {
    return res.status(400).json({ error: "name is required" });
  }
  if (typeof age !== "number" || !Number.isInteger(age) || age < 0 || age > 18) {
    return res.status(400).json({ error: "age must be an integer between 0 and 18" });
  }
  if (grade !== undefined && grade !== null && typeof grade !== "string") {
    return res.status(400).json({ error: "grade must be a string" });
  }

  const child = await prisma.child.create({
    data: {
      familyId,
      name: name.trim(),
      age,
      grade: grade ?? null,
      wallet: { create: {} },
    },
    include: { wallet: true },
  });

  res.status(201).json(serializeChild(child));
});

childrenRouter.patch("/:childId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { childId } = req.params;
  const { name, age, grade } = req.body;

  const existing = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!existing) {
    return res.status(404).json({ error: "Child not found" });
  }

  if (name !== undefined && (typeof name !== "string" || name.trim().length === 0)) {
    return res.status(400).json({ error: "name must be a non-empty string" });
  }
  if (
    age !== undefined &&
    (typeof age !== "number" || !Number.isInteger(age) || age < 0 || age > 18)
  ) {
    return res.status(400).json({ error: "age must be an integer between 0 and 18" });
  }
  if (grade !== undefined && grade !== null && typeof grade !== "string") {
    return res.status(400).json({ error: "grade must be a string" });
  }

  const child = await prisma.child.update({
    where: { id: childId },
    data: {
      ...(name !== undefined ? { name: name.trim() } : {}),
      ...(age !== undefined ? { age } : {}),
      ...(grade !== undefined ? { grade } : {}),
    },
    include: { wallet: true },
  });

  res.json(serializeChild(child));
});

childrenRouter.delete("/:childId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { childId } = req.params;

  const child = await prisma.child.findFirst({
    where: { id: childId, familyId },
    include: { wallet: true },
  });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  await prisma.$transaction(async (tx) => {
    await tx.practiceAttempt.deleteMany({ where: { childId } });
    await tx.childSubjectProgress.deleteMany({ where: { childId } });
    await tx.taskCompletion.deleteMany({ where: { childId } });
    await tx.redemption.deleteMany({ where: { childId } });
    if (child.wallet) {
      await tx.pointsTransaction.deleteMany({ where: { walletId: child.wallet.id } });
      await tx.pointsWallet.delete({ where: { id: child.wallet.id } });
    }
    await tx.child.delete({ where: { id: childId } });
  });

  res.status(204).send();
});

childrenRouter.post("/:childId/pin", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { childId } = req.params;
  const { pin } = req.body;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  if (typeof pin !== "string" || !/^\d{4}$/.test(pin)) {
    return res.status(400).json({ error: "pin must be a 4-digit string" });
  }

  const pinHash = await bcrypt.hash(pin, 10);
  await prisma.child.update({ where: { id: childId }, data: { pinHash } });

  res.status(204).send();
});

childrenRouter.post("/:childId/child-session", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { childId } = req.params;
  const { pin } = req.body;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }
  if (!child.pinHash) {
    return res.status(400).json({ error: "No PIN has been set for this child yet" });
  }
  if (typeof pin !== "string") {
    return res.status(400).json({ error: "pin is required" });
  }

  const matches = await bcrypt.compare(pin, child.pinHash);
  if (!matches) {
    return res.status(401).json({ error: "Incorrect PIN" });
  }

  const token = signChildToken({ childId: child.id, familyId });
  res.json({ token, child: { id: child.id, name: child.name } });
});
