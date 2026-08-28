import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { Difficulty, PrismaClient, QuestionSource } from "@prisma/client";
import Anthropic from "@anthropic-ai/sdk";

// סקריפט הרחבת מאגר השאלות הגלובלי (family=null, approved=true) באמצעות AI.
// עובר על כל שילוב מקצוע/כיתה/רמת-קושי ומייצר שאלות עד למכסה שהוגדרה, בלי
// לחזור על שאלות שכבר קיימות. הרצה: npx tsx prisma/generateQuestions.ts
// [מקצועות מופרדים בפסיק] [יעד לכל תא]
// דוגמה: npx tsx prisma/generateQuestions.ts math 20

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

if (!process.env.ANTHROPIC_API_KEY) {
  throw new Error("חסר ANTHROPIC_API_KEY בקובץ backend/.env");
}
const anthropic = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

type Subject = "math" | "english" | "hebrew";
const ALL_SUBJECTS: Subject[] = ["math", "english", "hebrew"];
const GRADES = [1, 2, 3, 4, 5, 6, 7, 8];
const DIFFICULTIES: Difficulty[] = ["EASY", "MEDIUM", "HARD"];
const GRADE_LABELS = ["א", "ב", "ג", "ד", "ה", "ו", "ז", "ח"];
const SUBJECT_LABELS: Record<Subject, string> = {
  math: "חשבון",
  english: "אנגלית",
  hebrew: "עברית (לשון)",
};
const DIFFICULTY_LABELS: Record<Difficulty, string> = {
  EASY: "קלה",
  MEDIUM: "בינונית",
  HARD: "קשה",
};

const BATCH_SIZE = 10;
const MAX_EXISTING_IN_PROMPT = 15;
const DELAY_BETWEEN_CALLS_MS = 500;

interface DraftQuestionShape {
  questionText: string;
  options: string[];
  correctOptionIndex: number;
  explanation: string;
}

// זהה ל-parseGeneratedQuestions ב-questionDrafts.ts — אותה בדיקת תקינות.
function parseGeneratedQuestions(raw: string): DraftQuestionShape[] {
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

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function generateBatch(
  subject: Subject,
  gradeLevel: number,
  difficulty: Difficulty,
  count: number,
  avoidTexts: string[],
): Promise<DraftQuestionShape[]> {
  const gradeLabel = GRADE_LABELS[gradeLevel - 1];
  const subjectLabel = SUBJECT_LABELS[subject];
  const difficultyLabel = DIFFICULTY_LABELS[difficulty];

  const avoidSection =
    avoidTexts.length > 0
      ? `\n\nהשאלות הבאות כבר קיימות במאגר עבור אותו מקצוע/כיתה/רמה - אל תיצור שאלות זהות או דומות מדי להן (נושא/מספרים/ניסוח):\n${avoidTexts
          .map((t) => `- ${t}`)
          .join("\n")}`
      : "";

  const prompt = `אתה עוזר להכין שאלות תרגול לילדים ישראלים בבית ספר יסודי/חטיבת ביניים.

צור בדיוק ${count} שאלות רב-ברירה (multiple choice) חדשות במקצוע "${subjectLabel}", המתאימות לתלמיד בכיתה ${gradeLabel} ברמת קושי ${difficultyLabel}.

כללים:
- כל השאלות, התשובות וההסברים בעברית תקנית וברורה לילד (חוץ משאלות אנגלית, שם אפשר תוכן באנגלית עם הנחיה בעברית).
- לכל שאלה בדיוק 4 אפשרויות תשובה, ורק אחת נכונה.
- לכל שאלה הוסף שדה explanation: הסבר קצר וברור שמלמד את הילד איך להגיע לתשובה הנכונה (לא רק "התשובה היא X").
- השאלות צריכות להיות מגוונות זו מזו (נושאים/ניסוחים/מספרים שונים).
- תוכן מתאים לגיל, ללא אלימות/תוכן בעייתי.${avoidSection}

החזר אך ורק מערך JSON תקין (ללא טקסט נוסף, ללא markdown), כאשר כל איבר במבנה:
{"questionText": string, "options": [string, string, string, string], "correctOptionIndex": number (0-3), "explanation": string}`;

  const message = await anthropic.messages.create({
    model: "claude-sonnet-5",
    max_tokens: 8192,
    messages: [{ role: "user", content: prompt }],
  });
  const textBlock = message.content.find((block) => block.type === "text");
  if (!textBlock || textBlock.type !== "text") {
    throw new Error("No text response from model");
  }
  return parseGeneratedQuestions(textBlock.text);
}

async function fillCell(subject: Subject, gradeLevel: number, difficulty: Difficulty, targetCount: number) {
  const existing = await prisma.question.findMany({
    where: { subject, gradeLevel, difficulty, familyId: null },
    select: { questionText: true },
  });

  const label = `${SUBJECT_LABELS[subject]} / כיתה ${GRADE_LABELS[gradeLevel - 1]} / ${DIFFICULTY_LABELS[difficulty]}`;
  const needed = targetCount - existing.length;
  if (needed <= 0) {
    console.log(`[דילוג] ${label} — כבר יש ${existing.length} שאלות (יעד ${targetCount}).`);
    return { created: 0, failed: 0 };
  }

  console.log(`[מתחיל] ${label} — יש ${existing.length}, צריך עוד ${needed}.`);

  const knownTexts = existing.map((q) => q.questionText);
  let created = 0;
  let failedBatches = 0;

  while (created < needed) {
    const batchCount = Math.min(BATCH_SIZE, needed - created);
    const avoidTexts = knownTexts.slice(-MAX_EXISTING_IN_PROMPT);

    let drafts: DraftQuestionShape[] | null = null;
    for (let attempt = 1; attempt <= 2 && !drafts; attempt++) {
      try {
        drafts = await generateBatch(subject, gradeLevel, difficulty, batchCount, avoidTexts);
      } catch (e) {
        console.error(`  ניסיון ${attempt} נכשל עבור ${label}:`, e instanceof Error ? e.message : e);
        if (attempt === 2) {
          failedBatches++;
        } else {
          await sleep(1000);
        }
      }
    }
    if (!drafts) break; // אפשר להריץ את הסקריפט שוב כדי להשלים את מה שנכשל

    const rows = drafts.map((d) => ({
      subject,
      gradeLevel,
      difficulty,
      questionText: d.questionText,
      options: d.options,
      correctOptionIndex: d.correctOptionIndex,
      explanation: d.explanation,
      source: QuestionSource.AI,
      approved: true,
      familyId: null,
    }));
    await prisma.question.createMany({ data: rows });
    created += drafts.length;
    knownTexts.push(...drafts.map((d) => d.questionText));
    console.log(`  +${drafts.length} (סה"כ ${created}/${needed})`);
    await sleep(DELAY_BETWEEN_CALLS_MS);
  }

  return { created, failed: failedBatches };
}

async function main() {
  const subjectsArg = process.argv[2];
  const subjects: Subject[] = subjectsArg
    ? (subjectsArg.split(",").filter((s) => (ALL_SUBJECTS as string[]).includes(s)) as Subject[])
    : ["math"];
  const targetCount = process.argv[3] ? parseInt(process.argv[3], 10) : 20;

  if (subjects.length === 0) {
    throw new Error(`מקצוע/ות לא מוכרים: "${subjectsArg}". אפשרויות: ${ALL_SUBJECTS.join(", ")}`);
  }

  console.log(`מריץ יצירת שאלות: מקצועות=${subjects.join(",")}, יעד לכל תא=${targetCount}\n`);

  let totalCreated = 0;
  let totalFailed = 0;

  for (const subject of subjects) {
    for (const gradeLevel of GRADES) {
      for (const difficulty of DIFFICULTIES) {
        const { created, failed } = await fillCell(subject, gradeLevel, difficulty, targetCount);
        totalCreated += created;
        totalFailed += failed;
      }
    }
  }

  console.log(`\nסיום. נוצרו ${totalCreated} שאלות חדשות.`);
  if (totalFailed > 0) {
    console.log(`${totalFailed} קבוצות נכשלו אחרי 2 ניסיונות — אפשר להריץ שוב את הסקריפט כדי להשלים (הוא מדלג על תאים שכבר מלאים).`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
