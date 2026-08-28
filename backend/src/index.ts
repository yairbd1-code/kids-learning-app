import "dotenv/config";
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
import { requireAuth, requireChildAuth } from "./auth/middleware";

const app = express();

app.use(cors());
app.use(express.json());

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

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
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
