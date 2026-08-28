import { Router } from "express";
import Anthropic from "@anthropic-ai/sdk";
import { Difficulty, QuestionSource } from "@prisma/client";
import { prisma } from "../prisma";
import { ALLOWED_SUBJECTS, Subject } from "./practice";

export const questionDraftsRouter = Router();

const VALID_DIFFICULTIES: Difficulty[] = ["EASY", "MEDIUM", "HARD"];
const MIN_GRADE = 1;
const MAX_GRADE = 8;
const MIN_COUNT = 1;
const MAX_COUNT = 10;

const GRADE_LABELS = ["א", "ב", "ג", "ד", "ה", "ו", "ז", "ח"];

const SUBJECT_LABELS: Record<Subject, string> = {
  math: "חשבון",
  english: "אנגלית",
  hebrew: "עברית (לשון)",
};

let anthropicClient: Anthropic | null = null;

function getAnthropicClient(): Anthropic | null {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  if (!anthropicClient) {
    anthropicClient = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  }
  return anthropicClient;
}

interface DraftQuestionShape {
  questionText: string;
  options: string[];
  correctOptionIndex: number;
  explanation: string;
}

function parseGeneratedQuestions(raw: string): DraftQuestionShape[] {
  // המודל אמור להחזיר JSON טהור, אבל ליתר ביטחון מסירים גדרות markdown אם יש.
  const cleaned = raw.trim().replace(/^```(?:json)?/i, "").replace(/```$/, "").trim();
  const parsed: unknown = JSON.parse(cleaned);
  if (!Array.isArray(parsed)) {
    throw new Error("Model did not return a JSON array");
  }

  return parsed.map((item, index) => {
    if (typeof item !== "object" || item === null) {
      throw new Error(`Item ${index} is not an object`);
    }
    const q = item as Record<string, unknown>;
    if (typeof q.questionText !== "string" || q.questionText.trim().length === 0) {
      throw new Error(`Item ${index} missing questionText`);
    }
    if (!Array.isArray(q.options) || q.options.length !== 4 || !q.options.every((o) => typeof o === "string")) {
      throw new Error(`Item ${index} must have exactly 4 string options`);
    }
    if (
      typeof q.correctOptionIndex !== "number" ||
      !Number.isInteger(q.correctOptionIndex) ||
      q.correctOptionIndex < 0 ||
      q.correctOptionIndex > 3
    ) {
      throw new Error(`Item ${index} has an invalid correctOptionIndex`);
    }
    if (typeof q.explanation !== "string" || q.explanation.trim().length === 0) {
      throw new Error(`Item ${index} missing explanation`);
    }
    return {
      questionText: q.questionText,
      options: q.options as string[],
      correctOptionIndex: q.correctOptionIndex,
      explanation: q.explanation,
    };
  });
}

questionDraftsRouter.get("/", async (req, res) => {
  const familyId = req.auth!.familyId;
  const statusParam = req.query.status as string | undefined;

  const where: { familyId: string; approved?: boolean } = { familyId };
  if (statusParam === "pending") where.approved = false;
  if (statusParam === "approved") where.approved = true;

  const drafts = await prisma.question.findMany({
    where,
    orderBy: { createdAt: "desc" },
  });

  res.json(drafts);
});

questionDraftsRouter.post("/generate", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { subject, gradeLevel, difficulty, count, childId } = req.body;

  if (!(ALLOWED_SUBJECTS as readonly string[]).includes(subject)) {
    return res.status(400).json({ error: "Unknown subject" });
  }
  if (typeof gradeLevel !== "number" || !Number.isInteger(gradeLevel) || gradeLevel < MIN_GRADE || gradeLevel > MAX_GRADE) {
    return res.status(400).json({ error: `gradeLevel must be an integer between ${MIN_GRADE} and ${MAX_GRADE}` });
  }
  if (typeof difficulty !== "string" || !VALID_DIFFICULTIES.includes(difficulty as Difficulty)) {
    return res.status(400).json({ error: "difficulty must be EASY, MEDIUM, or HARD" });
  }
  const requestedCount = typeof count === "number" ? count : 5;
  if (!Number.isInteger(requestedCount) || requestedCount < MIN_COUNT || requestedCount > MAX_COUNT) {
    return res.status(400).json({ error: `count must be an integer between ${MIN_COUNT} and ${MAX_COUNT}` });
  }
  if (childId !== undefined && typeof childId !== "string") {
    return res.status(400).json({ error: "childId must be a string" });
  }

  const client = getAnthropicClient();
  if (!client) {
    return res.status(503).json({
      error: "יצירת שאלות עם AI לא מוגדרת עדיין בשרת (חסר ANTHROPIC_API_KEY).",
    });
  }

  let curriculumContext = "";
  if (typeof childId === "string") {
    const child = await prisma.child.findFirst({ where: { id: childId, familyId } });
    if (!child) {
      return res.status(404).json({ error: "Child not found" });
    }
    const notes = await prisma.childCurriculumNote.findMany({
      where: { childId, subject },
      orderBy: { createdAt: "desc" },
      take: 5,
    });
    if (notes.length > 0) {
      curriculumContext =
        `\nהחומר הספציפי שהילד/ה לומד/ת השנה במקצוע זה (מספרי הלימוד שלו/ה בפועל):\n` +
        notes.map((n) => `- ${n.noteText}`).join("\n") +
        `\nהתאם את השאלות לחומר הזה ככל האפשר, ולא רק לרמת הכיתה הכללית.\n`;
    }
  }

  const gradeLabel = GRADE_LABELS[gradeLevel - 1];
  const subjectLabel = SUBJECT_LABELS[subject as Subject];
  const difficultyLabelHe = difficulty === "EASY" ? "קלה" : difficulty === "MEDIUM" ? "בינונית" : "קשה";

  const prompt = `אתה עוזר להכין שאלות תרגול לילדים ישראלים בבית ספר יסודי/חטיבת ביניים.

צור בדיוק ${requestedCount} שאלות רב-ברירה (multiple choice) חדשות במקצוע "${subjectLabel}", המתאימות לתלמיד בכיתה ${gradeLabel} ברמת קושי ${difficultyLabelHe}.
${curriculumContext}
כללים:
- כל השאלות, התשובות וההסברים בעברית תקנית וברורה לילד (חוץ משאלות אנגלית, שם אפשר תוכן באנגלית עם הנחיה בעברית).
- לכל שאלה בדיוק 4 אפשרויות תשובה, ורק אחת נכונה.
- לכל שאלה הוסף שדה explanation: הסבר קצר וברור שמלמד את הילד איך להגיע לתשובה הנכונה (לא רק "התשובה היא X").
- השאלות צריכות להיות מגוונות זו מזו (לא לחזור על אותו תרגיל עם מספרים שונים בלבד יותר מפעם אחת).
- תוכן מתאים לגיל, ללא אלימות/תוכן בעייתי.

החזר אך ורק מערך JSON תקין (ללא טקסט נוסף, ללא markdown), כאשר כל איבר במבנה:
{"questionText": string, "options": [string, string, string, string], "correctOptionIndex": number (0-3), "explanation": string}`;

  let responseText: string;
  try {
    const message = await client.messages.create({
      model: "claude-sonnet-5",
      max_tokens: 4096,
      messages: [{ role: "user", content: prompt }],
    });
    const textBlock = message.content.find((block) => block.type === "text");
    if (!textBlock || textBlock.type !== "text") {
      throw new Error("No text response from model");
    }
    responseText = textBlock.text;
  } catch (e) {
    console.error("AI question generation failed:", e);
    return res.status(502).json({ error: "יצירת השאלות נכשלה, נסו שוב" });
  }

  let drafts: DraftQuestionShape[];
  try {
    drafts = parseGeneratedQuestions(responseText);
  } catch (e) {
    console.error("Failed to parse AI-generated questions:", e, responseText);
    return res.status(502).json({ error: "התקבלה תשובה לא תקינה מה-AI, נסו שוב" });
  }

  const created = await prisma.question.createManyAndReturn({
    data: drafts.map((d) => ({
      subject,
      gradeLevel,
      difficulty: difficulty as Difficulty,
      questionText: d.questionText,
      options: d.options,
      correctOptionIndex: d.correctOptionIndex,
      explanation: d.explanation,
      source: QuestionSource.AI,
      approved: false,
      familyId,
    })),
  });

  res.status(201).json(created);
});

questionDraftsRouter.post("/manual", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { subject, gradeLevel, difficulty, questionText, options, correctOptionIndex, explanation } =
    req.body;

  if (!(ALLOWED_SUBJECTS as readonly string[]).includes(subject)) {
    return res.status(400).json({ error: "Unknown subject" });
  }
  if (typeof gradeLevel !== "number" || !Number.isInteger(gradeLevel) || gradeLevel < MIN_GRADE || gradeLevel > MAX_GRADE) {
    return res.status(400).json({ error: `gradeLevel must be an integer between ${MIN_GRADE} and ${MAX_GRADE}` });
  }
  if (typeof difficulty !== "string" || !VALID_DIFFICULTIES.includes(difficulty as Difficulty)) {
    return res.status(400).json({ error: "difficulty must be EASY, MEDIUM, or HARD" });
  }
  if (typeof questionText !== "string" || questionText.trim().length === 0) {
    return res.status(400).json({ error: "questionText is required" });
  }
  if (!Array.isArray(options) || options.length !== 4 || !options.every((o) => typeof o === "string" && o.trim().length > 0)) {
    return res.status(400).json({ error: "options must be exactly 4 non-empty strings" });
  }
  if (typeof correctOptionIndex !== "number" || !Number.isInteger(correctOptionIndex) || correctOptionIndex < 0 || correctOptionIndex > 3) {
    return res.status(400).json({ error: "correctOptionIndex must be an integer between 0 and 3" });
  }
  if (typeof explanation !== "string" || explanation.trim().length === 0) {
    return res.status(400).json({ error: "explanation is required" });
  }

  const created = await prisma.question.create({
    data: {
      subject,
      gradeLevel,
      difficulty: difficulty as Difficulty,
      questionText: questionText.trim(),
      options,
      correctOptionIndex,
      explanation: explanation.trim(),
      source: QuestionSource.MANUAL,
      approved: true,
      familyId,
    },
  });

  res.status(201).json(created);
});

questionDraftsRouter.patch("/:id", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { id } = req.params;
  const { approved, questionText, options, correctOptionIndex, explanation } = req.body;

  const existing = await prisma.question.findFirst({ where: { id, familyId } });
  if (!existing) {
    return res.status(404).json({ error: "Draft question not found" });
  }

  const data: {
    approved?: boolean;
    questionText?: string;
    options?: string[];
    correctOptionIndex?: number;
    explanation?: string;
  } = {};

  if (approved !== undefined) {
    if (typeof approved !== "boolean") {
      return res.status(400).json({ error: "approved must be a boolean" });
    }
    data.approved = approved;
  }
  if (questionText !== undefined) {
    if (typeof questionText !== "string" || questionText.trim().length === 0) {
      return res.status(400).json({ error: "questionText must be a non-empty string" });
    }
    data.questionText = questionText.trim();
  }
  if (options !== undefined) {
    if (!Array.isArray(options) || options.length !== 4 || !options.every((o) => typeof o === "string" && o.trim().length > 0)) {
      return res.status(400).json({ error: "options must be exactly 4 non-empty strings" });
    }
    data.options = options;
  }
  if (correctOptionIndex !== undefined) {
    if (typeof correctOptionIndex !== "number" || !Number.isInteger(correctOptionIndex) || correctOptionIndex < 0 || correctOptionIndex > 3) {
      return res.status(400).json({ error: "correctOptionIndex must be an integer between 0 and 3" });
    }
    data.correctOptionIndex = correctOptionIndex;
  }
  if (explanation !== undefined) {
    if (typeof explanation !== "string" || explanation.trim().length === 0) {
      return res.status(400).json({ error: "explanation must be a non-empty string" });
    }
    data.explanation = explanation.trim();
  }

  const updated = await prisma.question.update({ where: { id }, data });
  res.json(updated);
});

questionDraftsRouter.delete("/:id", async (req, res) => {
  const familyId = req.auth!.familyId;
  const { id } = req.params;

  const existing = await prisma.question.findFirst({ where: { id, familyId } });
  if (!existing) {
    return res.status(404).json({ error: "Draft question not found" });
  }

  await prisma.practiceAttempt.deleteMany({ where: { questionId: id } });
  await prisma.question.delete({ where: { id } });

  res.status(204).send();
});
