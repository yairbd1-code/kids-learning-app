import { Router } from "express";
import bcrypt from "bcryptjs";
import { OAuth2Client } from "google-auth-library";
import { prisma } from "../prisma";
import { signAuthToken } from "../auth/jwt";
import { requireAuth } from "../auth/middleware";

export const authRouter = Router();

const googleClient = new OAuth2Client();

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// תווים ללא אותיות/ספרות דו-משמעיות (0/O, 1/I) כדי שקוד המשפחה יהיה קריא וקל
// להקלדה בין ההורים.
const JOIN_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function generateJoinCode(): string {
  let code = "";
  for (let i = 0; i < 6; i++) {
    code += JOIN_CODE_CHARS[Math.floor(Math.random() * JOIN_CODE_CHARS.length)];
  }
  return code;
}

async function createFamilyWithUniqueJoinCode(name: string) {
  for (let attempt = 0; attempt < 5; attempt++) {
    try {
      return await prisma.family.create({ data: { name, joinCode: generateJoinCode() } });
    } catch (e) {
      const isUniqueConflict = (e as { code?: string })?.code === "P2002";
      if (!isUniqueConflict || attempt === 4) throw e;
    }
  }
  throw new Error("Failed to generate a unique family join code");
}

authRouter.post("/register", async (req, res) => {
  const { familyName, parentName, email, password } = req.body;

  if (typeof familyName !== "string" || familyName.trim().length === 0) {
    return res.status(400).json({ error: "familyName is required" });
  }
  if (typeof parentName !== "string" || parentName.trim().length === 0) {
    return res.status(400).json({ error: "parentName is required" });
  }
  if (typeof email !== "string" || !isValidEmail(email)) {
    return res.status(400).json({ error: "A valid email is required" });
  }
  if (typeof password !== "string" || password.length < 8) {
    return res.status(400).json({ error: "password must be at least 8 characters" });
  }

  const normalizedEmail = email.trim().toLowerCase();

  const existing = await prisma.parentUser.findUnique({ where: { email: normalizedEmail } });
  if (existing) {
    return res.status(409).json({ error: "Email is already registered" });
  }

  const passwordHash = await bcrypt.hash(password, 10);

  const family = await createFamilyWithUniqueJoinCode(familyName.trim());
  const parent = await prisma.parentUser.create({
    data: {
      familyId: family.id,
      name: parentName.trim(),
      email: normalizedEmail,
      passwordHash,
    },
  });

  const token = signAuthToken({ parentId: parent.id, familyId: family.id });

  res.status(201).json({
    token,
    parent: { id: parent.id, name: parent.name, email: parent.email },
    family: { id: family.id, name: family.name, joinCode: family.joinCode },
  });
});

authRouter.post("/join", async (req, res) => {
  const { joinCode, parentName, email, password } = req.body;

  if (typeof joinCode !== "string" || joinCode.trim().length === 0) {
    return res.status(400).json({ error: "joinCode is required" });
  }
  if (typeof parentName !== "string" || parentName.trim().length === 0) {
    return res.status(400).json({ error: "parentName is required" });
  }
  if (typeof email !== "string" || !isValidEmail(email)) {
    return res.status(400).json({ error: "A valid email is required" });
  }
  if (typeof password !== "string" || password.length < 8) {
    return res.status(400).json({ error: "password must be at least 8 characters" });
  }

  const normalizedEmail = email.trim().toLowerCase();
  const normalizedCode = joinCode.trim().toUpperCase();

  const family = await prisma.family.findUnique({ where: { joinCode: normalizedCode } });
  if (!family) {
    return res.status(404).json({ error: "קוד משפחה שגוי" });
  }

  const existing = await prisma.parentUser.findUnique({ where: { email: normalizedEmail } });
  if (existing) {
    return res.status(409).json({ error: "Email is already registered" });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const parent = await prisma.parentUser.create({
    data: {
      familyId: family.id,
      name: parentName.trim(),
      email: normalizedEmail,
      passwordHash,
    },
  });

  const token = signAuthToken({ parentId: parent.id, familyId: family.id });

  res.status(201).json({
    token,
    parent: { id: parent.id, name: parent.name, email: parent.email },
    family: { id: family.id, name: family.name, joinCode: family.joinCode },
  });
});

authRouter.post("/login", async (req, res) => {
  const { email, password } = req.body;

  if (typeof email !== "string" || typeof password !== "string") {
    return res.status(400).json({ error: "email and password are required" });
  }

  const normalizedEmail = email.trim().toLowerCase();

  const parent = await prisma.parentUser.findUnique({
    where: { email: normalizedEmail },
    include: { family: true },
  });

  const invalidCredentials = () => res.status(401).json({ error: "Invalid email or password" });

  if (!parent) {
    return invalidCredentials();
  }

  if (!parent.passwordHash) {
    return res.status(400).json({
      error: "This account uses Google sign-in. Please continue with Google instead.",
    });
  }

  const passwordMatches = await bcrypt.compare(password, parent.passwordHash);
  if (!passwordMatches) {
    return invalidCredentials();
  }

  const token = signAuthToken({ parentId: parent.id, familyId: parent.familyId });

  res.json({
    token,
    parent: { id: parent.id, name: parent.name, email: parent.email },
    family: { id: parent.family.id, name: parent.family.name, joinCode: parent.family.joinCode },
  });
});

authRouter.post("/google", async (req, res) => {
  const googleClientId = process.env.GOOGLE_CLIENT_ID;
  if (!googleClientId) {
    return res.status(501).json({ error: "Google sign-in is not configured on this server yet" });
  }

  const { idToken } = req.body;
  if (typeof idToken !== "string" || idToken.length === 0) {
    return res.status(400).json({ error: "idToken is required" });
  }

  let payload;
  try {
    const ticket = await googleClient.verifyIdToken({ idToken, audience: googleClientId });
    payload = ticket.getPayload();
  } catch {
    return res.status(401).json({ error: "Invalid Google token" });
  }

  if (!payload?.email || !payload.email_verified || !payload.sub) {
    return res.status(401).json({ error: "Google account email is not verified" });
  }

  const googleId = payload.sub;
  const email = payload.email.toLowerCase();
  const name = payload.name ?? email;

  let parent = await prisma.parentUser.findUnique({
    where: { googleId },
    include: { family: true },
  });

  if (!parent) {
    const existingByEmail = await prisma.parentUser.findUnique({
      where: { email },
      include: { family: true },
    });

    if (existingByEmail) {
      parent = await prisma.parentUser.update({
        where: { id: existingByEmail.id },
        data: { googleId },
        include: { family: true },
      });
    } else {
      const family = await createFamilyWithUniqueJoinCode(`המשפחה של ${name}`);
      parent = await prisma.parentUser.create({
        data: {
          familyId: family.id,
          name,
          email,
          googleId,
          authProvider: "GOOGLE",
        },
        include: { family: true },
      });
    }
  }

  const token = signAuthToken({ parentId: parent.id, familyId: parent.familyId });

  res.json({
    token,
    parent: { id: parent.id, name: parent.name, email: parent.email },
    family: { id: parent.family.id, name: parent.family.name, joinCode: parent.family.joinCode },
  });
});

authRouter.get("/me", requireAuth, async (req, res) => {
  const parent = await prisma.parentUser.findUnique({
    where: { id: req.auth!.parentId },
    include: { family: true },
  });

  if (!parent) {
    return res.status(404).json({ error: "Parent not found" });
  }

  res.json({
    parent: { id: parent.id, name: parent.name, email: parent.email },
    family: { id: parent.family.id, name: parent.family.name, joinCode: parent.family.joinCode },
  });
});

authRouter.patch("/me", requireAuth, async (req, res) => {
  const { name, familyName, currentPassword, newPassword } = req.body;

  const parent = await prisma.parentUser.findUnique({
    where: { id: req.auth!.parentId },
    include: { family: true },
  });
  if (!parent) {
    return res.status(404).json({ error: "Parent not found" });
  }

  if (name !== undefined && (typeof name !== "string" || name.trim().length === 0)) {
    return res.status(400).json({ error: "name must be a non-empty string" });
  }
  if (
    familyName !== undefined &&
    (typeof familyName !== "string" || familyName.trim().length === 0)
  ) {
    return res.status(400).json({ error: "familyName must be a non-empty string" });
  }

  let passwordHash: string | undefined;
  if (newPassword !== undefined) {
    if (!parent.passwordHash) {
      return res.status(400).json({
        error: "This account uses Google sign-in and has no password to change",
      });
    }
    if (typeof newPassword !== "string" || newPassword.length < 8) {
      return res.status(400).json({ error: "newPassword must be at least 8 characters" });
    }
    if (typeof currentPassword !== "string") {
      return res.status(400).json({ error: "currentPassword is required to set a new password" });
    }
    const currentMatches = await bcrypt.compare(currentPassword, parent.passwordHash);
    if (!currentMatches) {
      return res.status(401).json({ error: "currentPassword is incorrect" });
    }
    passwordHash = await bcrypt.hash(newPassword, 10);
  }

  const updated = await prisma.parentUser.update({
    where: { id: parent.id },
    data: {
      ...(name !== undefined ? { name: name.trim() } : {}),
      ...(passwordHash !== undefined ? { passwordHash } : {}),
    },
  });

  const family =
    familyName !== undefined
      ? await prisma.family.update({
          where: { id: parent.familyId },
          data: { name: familyName.trim() },
        })
      : parent.family;

  res.json({
    parent: { id: updated.id, name: updated.name, email: updated.email },
    family: { id: family.id, name: family.name, joinCode: family.joinCode },
  });
});

authRouter.get("/family-members", requireAuth, async (req, res) => {
  const familyId = req.auth!.familyId;

  const members = await prisma.parentUser.findMany({
    where: { familyId },
    orderBy: { createdAt: "asc" },
  });

  res.json(
    members.map((m) => ({
      id: m.id,
      name: m.name,
      email: m.email,
      authProvider: m.authProvider,
    })),
  );
});
