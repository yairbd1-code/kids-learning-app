import { Router, json } from "express";
import Anthropic from "@anthropic-ai/sdk";
import { prisma } from "../prisma";
import { ALLOWED_SUBJECTS } from "./practice";

export const curriculumNotesRouter = Router({ mergeParams: true });

// תמונה מהמצלמה יכולה להיות כמה MB — ברירת המחדל של express.json (100kb)
// קטנה מדי, אז לנתיב הזה בלבד מרחיבים את המגבלה.
const imageJsonParser = json({ limit: "10mb" });

let anthropicClient: Anthropic | null = null;
function getAnthropicClient(): Anthropic | null {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  if (!anthropicClient) {
    anthropicClient = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return anthropicClient;
}

curriculumNotesRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const childId = (req.params as { childId: string }).childId;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const notes = await prisma.childCurriculumNote.findMany({
    where: { childId },
    orderBy: { createdAt: "desc" },
  });

  res.json(notes);
});

curriculumNotesRouter.post("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const childId = (req.params as { childId: string }).childId;
  const { subject, noteText } = req.body;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }
  if (!(ALLOWED_SUBJECTS as readonly string[]).includes(subject)) {
    return res.status(400).json({ error: "Unknown subject" });
  }
  if (typeof noteText !== "string" || noteText.trim().length === 0) {
    return res.status(400).json({ error: "noteText is required" });
  }

  const note = await prisma.childCurriculumNote.create({
    data: { childId, subject, noteText: noteText.trim(), source: "manual" },
  });

  res.status(201).json(note);
});

curriculumNotesRouter.post("/from-image", imageJsonParser, async (req, res) => {
  const familyId = req.auth!.familyId;
  const childId = (req.params as { childId: string }).childId;
  const { subject, imageBase64, mediaType } = req.body;

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }
  if (!(ALLOWED_SUBJECTS as readonly string[]).includes(subject)) {
    return res.status(400).json({ error: "Unknown subject" });
  }
  if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
    return res.status(400).json({ error: "imageBase64 is required" });
  }
  const validMediaTypes = ["image/jpeg", "image/png", "image/webp"];
  if (typeof mediaType !== "string" || !validMediaTypes.includes(mediaType)) {
    return res.status(400).json({ error: "mediaType must be image/jpeg, image/png, or image/webp" });
  }

  const client = getAnthropicClient();
  if (!client) {
    return res.status(503).json({
      error: "זיהוי תמונה עם AI לא מוגדר עדיין בשרת (חסר ANTHROPIC_API_KEY).",
    });
  }

  // חשוב: bytes התמונה לא נשמרים ב-DB ולא לדיסק בשום שלב — הם מועברים
  // ל-Claude לעיבוד ונשמטים מהזיכרון מיד אחרי סוף הבקשה, בהתאם למה שסוכם
  // (למחוק את התמונה מיד אחרי הקריאה).
  let extractedText: string;
  try {
    const message = await client.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: mediaType as "image/jpeg" | "image/png" | "image/webp", data: imageBase64 },
            },
            {
              type: "text",
              text:
                "זו תמונה של דף מספר לימוד או רשימת נושאים לבית ספר. תאר בכמה משפטים " +
                "בעברית מה החומר הלימודי שמופיע כאן (נושאים, פרקים, מושגים מרכזיים) - " +
                "כך שאפשר יהיה להשתמש בתיאור כדי ליצור שאלות תרגול מתאימות. אם אין " +
                "בתמונה תוכן לימודי רלוונטי, כתוב \"לא זוהה תוכן לימודי בתמונה\".",
            },
          ],
        },
      ],
    });
    const textBlock = message.content.find((block) => block.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new Error("No text response from model");
    }
    extractedText = textBlock.text.trim();
  } catch (e) {
    console.error("Curriculum image OCR failed:", e);
    return res.status(502).json({ error: "קריאת התמונה נכשלה, נסו שוב" });
  }

  const note = await prisma.childCurriculumNote.create({
    data: { childId, subject, noteText: extractedText, source: "photo" },
  });

  res.status(201).json(note);
});

curriculumNotesRouter.delete("/:noteId", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { childId, noteId } = req.params as { childId: string; noteId: string };

  const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
  if (!child) {
    return res.status(404).json({ error: "Child not found" });
  }

  const note = await prisma.childCurriculumNote.findFirst({ where: { id: noteId, childId } });
  if (!note) {
    return res.status(404).json({ error: "Note not found" });
  }

  await prisma.childCurriculumNote.delete({ where: { id: noteId } });
  res.status(204).send();
});
