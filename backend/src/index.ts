import "dotenv/config";
import path from "path";
import express, { NextFunction, Request, Response } from "express";
import cors from "cors";
import { authRouter } from "./routes/auth";
import { childrenRouter } from "./routes/children";
import { transactionsRouter } from "./routes/transactions";
import { rewardsRouter } from "./routes/rewards";
import { redemptionsRouter } from "./routes/redemptions";
import { learningTasksRouter } from "./routes/learningTasks";
import { taskCompletionsRouter } from "./routes/taskCompletions";
import { practiceRouter } from "./routes/practice";
import { subjectProgressRouter } from "./routes/subjectProgress";
import { questionDraftsRouter } from "./routes/questionDrafts";
import { practiceStatsRouter } from "./routes/practiceStats";
import { curriculumNotesRouter } from "./routes/curriculumNotes";
import { childStoreRouter } from "./routes/childStore";
import { childProfileRouter } from "./routes/childProfile";
import { requireAuth, requireChildAuth } from "./auth/middleware";

const app = express();

app.use(cors());
// ברירת המחדל (100kb) קטנה מדי לתמונות base64 (חומרי לימוד, תמונת פרופיל
// לילד) - מגדילים גלובלית כדי שגם ה-parser הייעודי ב-curriculumNotes.ts
// (שרץ אחרי זה ולא היה נתפס בכלל תחת המגבלה המקורית) יקבל בפועל בקשות גדולות.
app.use(express.json({ limit: "10mb" }));

app.use("/auth", authRouter);
app.use("/children", requireAuth, childrenRouter);
app.use("/children/:childId/transactions", requireAuth, transactionsRouter);
app.use("/children/:childId/redemptions", requireAuth, redemptionsRouter);
app.use("/rewards", requireAuth, rewardsRouter);
app.use("/learning-tasks", requireAuth, learningTasksRouter);
app.use("/children/:childId/task-completions", requireAuth, taskCompletionsRouter);
app.use("/children/:childId/subject-progress", requireAuth, subjectProgressRouter);
app.use("/children/:childId/practice-stats", requireAuth, practiceStatsRouter);
app.use("/children/:childId/curriculum-notes", requireAuth, curriculumNotesRouter);
app.use("/question-drafts", requireAuth, questionDraftsRouter);
app.use("/practice", requireChildAuth, practiceRouter);
app.use("/store", requireChildAuth, childStoreRouter);
app.use("/me", requireChildAuth, childProfileRouter);

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

// אפליקציית ה-Flutter Web הבנויה (backend/public/, מיוצרת ידנית עם
// flutter build web --dart-define=API_BASE_URL=... ומועתקת לכאן) מוגשת
// מאותו שרת ומאותה כתובת - כך שלא צריך שירות Render נפרד למי שגולש לאתר.
const publicDir = path.join(__dirname, "..", "public");
app.use(express.static(publicDir));

// כל בקשת GET שלא תאמה נתיב API ידוע ולא קובץ סטטי קיים - מניחים שזה ניווט
// בתוך אפליקציית ה-Flutter (SPA) ומגישים לה את index.html. בדיקת התחילית
// שומרת על 404 בפורמט JSON אמיתי לבקשות API שגויות, במקום להסוות אותן.
const apiPathPrefixes = [
  "/auth",
  "/children",
  "/rewards",
  "/learning-tasks",
  "/question-drafts",
  "/practice",
  "/store",
  "/me",
  "/health",
];
app.get(/.*/, (req, res, next) => {
  if (req.method !== "GET") return next();
  if (apiPathPrefixes.some((prefix) => req.path.startsWith(prefix))) return next();
  res.sendFile(path.join(publicDir, "index.html"));
});

app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

// Catches errors from body-parser (malformed JSON), thrown route handlers,
// etc. so clients always get JSON back instead of Express's default HTML
// error page, which also leaks server file paths in its stack trace.
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  console.error(err);
  const status =
    (err as { status?: number; statusCode?: number })?.status ??
    (err as { statusCode?: number })?.statusCode ??
    500;

  if (status >= 500) {
    res.status(500).json({ error: "Internal server error" });
  } else {
    res.status(status).json({ error: "Invalid request" });
  }
});

const port = process.env.PORT ? Number(process.env.PORT) : 3000;

app.listen(port, () => {
  console.log(`Server listening on http://localhost:${port}`);
});
