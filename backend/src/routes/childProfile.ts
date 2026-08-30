import { Router } from "express";
import { prisma } from "../prisma";
import { ALLOWED_THEMES, isValidTheme } from "./children";

export const childProfileRouter = Router();

childProfileRouter.get("/", async (req, res) => {
  const { childId, familyId } = req.childAuth!;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  res.json({ id: child.id, name: child.name, themeId: child.themeId, photoUrl: child.photoUrl });
});

// ילד/ה יכול/ה לבחור צבע לעצמו/ה (זה בדיוק העיצוב שסוכם - "לא נבחר לפי
// מגדר בכוונה, כל ילד/ה יכול/ה לבחור כל צבע"). שינוי תמונת פרופיל נשאר
// אצל ההורה בלבד (PATCH /children/:id הרגיל), לא כאן.
childProfileRouter.patch("/", async (req, res) => {
  const { childId, familyId } = req.childAuth!;
  const { themeId } = req.body;

  if (!isValidTheme(themeId)) {
    return res.status(400).json({ error: `themeId must be one of: ${ALLOWED_THEMES.join(", ")}` });
  }

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const updated = await prisma.child.update({ where: { id: childId }, data: { themeId } });

  res.json({
    id: updated.id,
    name: updated.name,
    themeId: updated.themeId,
    photoUrl: updated.photoUrl,
  });
});
