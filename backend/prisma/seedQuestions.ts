import "dotenv/config";
import { PrismaPg } from "@prisma/adapter-pg";
import { Difficulty, PrismaClient } from "@prisma/client";

// תוכן זה נכתב תוך התייחסות למבנה הכללי (ברמת נושאים) של תכנית הלימודים של
// משרד החינוך בישראל לכל מקצוע ושכבת גיל, על בסיס מחקר רמת-על (לא מסמכי תכנית
// לימודים רשמיים מלאים). מדובר במאגר התחלתי (72 שאלות: 8 כיתות x 3 רמות x 3
// מקצועות) שנועד לתת כיסוי בסיסי לכל טווח הכיתות. כיסוי מלא ומדויק יותר לתכנית
// הרשמית מתוכנן להיבנות בעתיד באמצעות תכונת יצירת תוכן ב-AI (פיצ'ר פרימיום).

const adapter = new PrismaPg({ connectionString: process.env.DATABASE_URL });
const prisma = new PrismaClient({ adapter });

interface SeedQuestion {
  subject: "math" | "english" | "hebrew";
  gradeLevel: number;
  difficulty: Difficulty;
  questionText: string;
  options: string[];
  correctOptionIndex: number;
  explanation: string;
}

const math: SeedQuestion[] = [
  { subject: "math", gradeLevel: 1, difficulty: "EASY", questionText: "2 + 3 = ?", options: ["4", "5", "6", "7"], correctOptionIndex: 1, explanation: "סופרים 3 צעדים קדימה מ-2: 3, 4, 5. התשובה היא 5." },
  { subject: "math", gradeLevel: 1, difficulty: "MEDIUM", questionText: "7 + 2 = ?", options: ["8", "9", "10", "11"], correctOptionIndex: 1, explanation: "סופרים 2 צעדים קדימה מ-7: 8, 9. התשובה היא 9." },
  { subject: "math", gradeLevel: 1, difficulty: "HARD", questionText: "9 - 4 = ?", options: ["4", "5", "6", "3"], correctOptionIndex: 1, explanation: "מ-9 סופרים 4 אחורה: 8, 7, 6, 5. התשובה היא 5." },

  { subject: "math", gradeLevel: 2, difficulty: "EASY", questionText: "8 + 7 = ?", options: ["14", "15", "16", "13"], correctOptionIndex: 1, explanation: "8 + 7 = 8 + 2 + 5 = 10 + 5 = 15." },
  { subject: "math", gradeLevel: 2, difficulty: "MEDIUM", questionText: "42 - 15 = ?", options: ["27", "26", "28", "25"], correctOptionIndex: 0, explanation: "42 - 15: מפרקים ל-42 - 10 = 32, ואז 32 - 5 = 27." },
  { subject: "math", gradeLevel: 2, difficulty: "HARD", questionText: "4 × 3 = ?", options: ["9", "12", "15", "10"], correctOptionIndex: 1, explanation: "4 × 3 זה 4 פעמים 3, כלומר 3+3+3+3 = 12." },

  { subject: "math", gradeLevel: 3, difficulty: "EASY", questionText: "6 × 4 = ?", options: ["20", "24", "28", "22"], correctOptionIndex: 1, explanation: "6 × 4 זה 6 פעמים 4: 4+4+4+4+4+4 = 24." },
  { subject: "math", gradeLevel: 3, difficulty: "MEDIUM", questionText: "7 × 8 = ?", options: ["54", "56", "58", "64"], correctOptionIndex: 1, explanation: "לפי לוח הכפל: 7 × 8 = 56." },
  { subject: "math", gradeLevel: 3, difficulty: "HARD", questionText: "36 ÷ 4 = ?", options: ["8", "9", "10", "7"], correctOptionIndex: 1, explanation: "צריך למצוא מספר שכפול 4 נותן 36. 9 × 4 = 36, אז התשובה היא 9." },

  { subject: "math", gradeLevel: 4, difficulty: "EASY", questionText: "324 + 158 = ?", options: ["482", "472", "492", "480"], correctOptionIndex: 0, explanation: "324 + 158: מחברים יחידות (4+8=12), עשרות (2+5+1=8), מאות (3+1=4) -> 482." },
  { subject: "math", gradeLevel: 4, difficulty: "MEDIUM", questionText: "23 × 6 = ?", options: ["128", "138", "148", "136"], correctOptionIndex: 1, explanation: "23 × 6 = 20×6 + 3×6 = 120 + 18 = 138." },
  { subject: "math", gradeLevel: 4, difficulty: "HARD", questionText: "84 ÷ 7 = ?", options: ["11", "12", "13", "14"], correctOptionIndex: 1, explanation: "7 × 12 = 84, אז 84 ÷ 7 = 12." },

  { subject: "math", gradeLevel: 5, difficulty: "EASY", questionText: "1/5 + 2/5 = ?", options: ["3/5", "3/10", "2/5", "4/5"], correctOptionIndex: 0, explanation: "כשהמכנה שווה (5), מחברים רק את המונים: 1 + 2 = 3, אז התוצאה היא 3/5." },
  { subject: "math", gradeLevel: 5, difficulty: "MEDIUM", questionText: "3.5 + 2.7 = ?", options: ["6.2", "5.2", "6.8", "5.8"], correctOptionIndex: 0, explanation: "3.5 + 2.7: מחברים כמו מספרים שלמים (35+27=62) ומזיזים נקודה עשרונית אחת: 6.2." },
  { subject: "math", gradeLevel: 5, difficulty: "HARD", questionText: "20% מ-150 = ?", options: ["15", "30", "45", "20"], correctOptionIndex: 1, explanation: "20% = 20/100 = 0.2. 0.2 × 150 = 30." },

  { subject: "math", gradeLevel: 6, difficulty: "EASY", questionText: "ביחס 2:3, אם המספר הראשון הוא 8, מה השני?", options: ["10", "12", "14", "16"], correctOptionIndex: 1, explanation: "2:3 = 8:x, אז x = 8 × 3 ÷ 2 = 12." },
  { subject: "math", gradeLevel: 6, difficulty: "MEDIUM", questionText: "(-5) + 8 = ?", options: ["3", "-3", "13", "-13"], correctOptionIndex: 0, explanation: "מתחילים ב-(-5) ומוסיפים 8: מתקדמים 8 צעדים ימינה בציר המספרים, מגיעים ל-3." },
  { subject: "math", gradeLevel: 6, difficulty: "HARD", questionText: "3 + 2 × 4 = ?", options: ["20", "11", "10", "9"], correctOptionIndex: 1, explanation: "לפי סדר פעולות חשבון, מכפילים לפני שמחברים: 2×4=8, ואז 3+8=11." },

  { subject: "math", gradeLevel: 7, difficulty: "EASY", questionText: "x + 5 = 12, מה x?", options: ["6", "7", "8", "17"], correctOptionIndex: 1, explanation: "כדי לבודד את x, מחסירים 5 משני האגפים: x = 12 - 5 = 7." },
  { subject: "math", gradeLevel: 7, difficulty: "MEDIUM", questionText: "2x + 3 = 11, מה x?", options: ["3", "4", "5", "7"], correctOptionIndex: 1, explanation: "מחסירים 3 משני האגפים: 2x = 8. מחלקים ב-2: x = 4." },
  { subject: "math", gradeLevel: 7, difficulty: "HARD", questionText: "סכום הזוויות במשולש הוא 180 מעלות. שתי הזוויות הן 50 ו-60 מעלות. מה הזווית השלישית?", options: ["60", "70", "80", "90"], correctOptionIndex: 1, explanation: "180 - 50 - 60 = 70 מעלות." },

  { subject: "math", gradeLevel: 8, difficulty: "EASY", questionText: "2³ = ?", options: ["6", "8", "9", "16"], correctOptionIndex: 1, explanation: "2³ פירושו 2×2×2 = 8." },
  { subject: "math", gradeLevel: 8, difficulty: "MEDIUM", questionText: "√81 = ?", options: ["8", "9", "10", "7"], correctOptionIndex: 1, explanation: "השורש הריבועי של 81 הוא המספר שבריבועו נותן 81: 9×9=81." },
  { subject: "math", gradeLevel: 8, difficulty: "HARD", questionText: "במשולש ישר-זווית הניצבים הם 3 ו-4. מה אורך היתר?", options: ["5", "6", "7", "4"], correctOptionIndex: 0, explanation: "לפי משפט פיתגורס: 3² + 4² = 9 + 16 = 25, והשורש של 25 הוא 5." },
];

const english: SeedQuestion[] = [
  { subject: "english", gradeLevel: 1, difficulty: "EASY", questionText: "איזו מהמילים פירושה 'חתול'?", options: ["Cat", "Dog", "Sun", "Book"], correctOptionIndex: 0, explanation: "'Cat' באנגלית פירושו חתול." },
  { subject: "english", gradeLevel: 1, difficulty: "MEDIUM", questionText: "איך אומרים 'שלום' באנגלית (כברכה)?", options: ["Hello", "Goodbye", "Please", "Thanks"], correctOptionIndex: 0, explanation: "'Hello' היא הדרך הנפוצה לומר שלום באנגלית." },
  { subject: "english", gradeLevel: 1, difficulty: "HARD", questionText: "המספר 'three' באנגלית הוא:", options: ["2", "3", "4", "5"], correctOptionIndex: 1, explanation: "'Three' פירושו שלוש (3)." },

  { subject: "english", gradeLevel: 2, difficulty: "EASY", questionText: "השלימו: I ___ a student.", options: ["am", "is", "are", "be"], correctOptionIndex: 0, explanation: "עם 'I' (אני) משתמשים תמיד ב-'am'." },
  { subject: "english", gradeLevel: 2, difficulty: "MEDIUM", questionText: "מהו הצבע 'red' בעברית?", options: ["אדום", "כחול", "ירוק", "צהוב"], correctOptionIndex: 0, explanation: "'Red' פירושו אדום." },
  { subject: "english", gradeLevel: 2, difficulty: "HARD", questionText: "בחרו את המילה הנכונה: She ___ happy.", options: ["am", "is", "are", "be"], correctOptionIndex: 1, explanation: "עם 'she' (היא) משתמשים ב-'is'." },

  { subject: "english", gradeLevel: 3, difficulty: "EASY", questionText: "מהו הרבים (plural) של 'cat'?", options: ["cats", "cates", "cat", "catss"], correctOptionIndex: 0, explanation: "ברוב המילים באנגלית מוסיפים 's' ליצירת רבים: cat -> cats." },
  { subject: "english", gradeLevel: 3, difficulty: "MEDIUM", questionText: "בחרו את המשפט הנכון:", options: ["He go to school.", "He goes to school.", "He going to school.", "He gone to school."], correctOptionIndex: 1, explanation: "בגוף שלישי יחיד (he/she/it) בהווה פשוט מוסיפים 's' לפועל: goes." },
  { subject: "english", gradeLevel: 3, difficulty: "HARD", questionText: "מהי מילת הניגוד (antonym) ל-'big'?", options: ["large", "small", "tall", "wide"], correctOptionIndex: 1, explanation: "'Small' (קטן) הוא הניגוד של 'big' (גדול)." },

  { subject: "english", gradeLevel: 4, difficulty: "EASY", questionText: "השלימו: They ___ playing football now.", options: ["is", "am", "are", "be"], correctOptionIndex: 2, explanation: "עם 'they' (הם) משתמשים ב-'are'." },
  { subject: "english", gradeLevel: 4, difficulty: "MEDIUM", questionText: "מהו עבר (past tense) של הפועל 'go'?", options: ["goed", "went", "gone", "going"], correctOptionIndex: 1, explanation: "'go' הוא פועל לא רגיל, וצורת העבר שלו היא 'went'." },
  { subject: "english", gradeLevel: 4, difficulty: "HARD", questionText: "בחרו מילה נרדפת (synonym) ל-'happy':", options: ["sad", "glad", "angry", "tired"], correctOptionIndex: 1, explanation: "'Glad' פירושו שמח, בדיוק כמו 'happy'." },

  { subject: "english", gradeLevel: 5, difficulty: "EASY", questionText: "השלימו: There ___ many books on the table.", options: ["is", "are", "be", "am"], correctOptionIndex: 1, explanation: "'books' הוא רבים, ולכן משתמשים ב-'are'." },
  { subject: "english", gradeLevel: 5, difficulty: "MEDIUM", questionText: "מהו עבר (past tense) של 'eat'?", options: ["eated", "ate", "eaten", "eating"], correctOptionIndex: 1, explanation: "'eat' הוא פועל לא רגיל, וצורת העבר שלו היא 'ate'." },
  { subject: "english", gradeLevel: 5, difficulty: "HARD", questionText: "בחרו את המשפט בזמן עתיד (future tense):", options: ["She will visit her grandma.", "She visited her grandma.", "She visits her grandma.", "She is visiting her grandma."], correctOptionIndex: 0, explanation: "'will' + פועל בסיס מציין פעולה שתקרה בעתיד." },

  { subject: "english", gradeLevel: 6, difficulty: "EASY", questionText: "מהי צורת ההשוואה (comparative) של 'big'?", options: ["bigger", "biggest", "more big", "big"], correctOptionIndex: 0, explanation: "למילים קצרות מוסיפים 'er' להשוואה: big -> bigger." },
  { subject: "english", gradeLevel: 6, difficulty: "MEDIUM", questionText: "השלימו: This book is ___ than that one.", options: ["interesting", "more interesting", "interestinger", "most interesting"], correctOptionIndex: 1, explanation: "למילים ארוכות משתמשים ב-'more' להשוואה, לא ב-'er'." },
  { subject: "english", gradeLevel: 6, difficulty: "HARD", questionText: "בחרו את המילה המתאימה: If it rains, I ___ stay home.", options: ["will", "would", "am", "was"], correctOptionIndex: 0, explanation: "במשפט תנאי מהסוג הראשון (עתיד סביר) משתמשים ב-'will' בפסוקית התוצאה." },

  { subject: "english", gradeLevel: 7, difficulty: "EASY", questionText: "מהי המילה הנכונה: I have ___ apple.", options: ["a", "an", "the", "some"], correctOptionIndex: 1, explanation: "לפני מילה שמתחילה בתנועה (כמו apple) משתמשים ב-'an'." },
  { subject: "english", gradeLevel: 7, difficulty: "MEDIUM", questionText: "בחרו את המשפט בסביל (passive voice):", options: ["The cake was baked by her.", "She baked the cake.", "She bakes the cake.", "She is baking the cake."], correctOptionIndex: 0, explanation: "במשפט סביל הנושא הוא מי שסובל מהפעולה: 'The cake was baked' (העוגה נאפתה)." },
  { subject: "english", gradeLevel: 7, difficulty: "HARD", questionText: "מהי מילת הקישור המתאימה: I stayed home ___ it was raining.", options: ["because", "but", "so", "or"], correctOptionIndex: 0, explanation: "'because' מסביר את הסיבה - נשארתי בבית כי ירד גשם." },

  { subject: "english", gradeLevel: 8, difficulty: "EASY", questionText: "מהו הפירוש של 'although'?", options: ["אף על פי ש", "כי", "אבל", "אז"], correctOptionIndex: 0, explanation: "'Although' פירושו 'אף על פי ש' ומשמש לחיבור שתי טענות סותרות." },
  { subject: "english", gradeLevel: 8, difficulty: "MEDIUM", questionText: "בחרו את המשפט הנכון בזמן present perfect:", options: ["I have seen this movie before.", "I see this movie before.", "I saw this movie before.", "I am seeing this movie before."], correctOptionIndex: 0, explanation: "present perfect נבנה מ-have/has + פועל בצורת עבר שלישי (V3): have seen." },
  { subject: "english", gradeLevel: 8, difficulty: "HARD", questionText: "מהי המילה הנרדפת (synonym) ל-'enormous'?", options: ["tiny", "huge", "quiet", "fast"], correctOptionIndex: 1, explanation: "'Huge' (ענק) הוא מילה נרדפת ל-'enormous' (עצום)." },
];

const hebrew: SeedQuestion[] = [
  { subject: "hebrew", gradeLevel: 1, difficulty: "EASY", questionText: "איזו אות באה אחרי האות 'א'?", options: ["ב", "ג", "ד", "ה"], correctOptionIndex: 0, explanation: "סדר האותיות בא\"ב הוא: א, ב, ג... אז אחרי א' באה ב'." },
  { subject: "hebrew", gradeLevel: 1, difficulty: "MEDIUM", questionText: "כמה אותיות יש במילה 'שלום'?", options: ["3", "4", "5", "6"], correctOptionIndex: 1, explanation: "המילה 'שלום' מורכבת מ-4 אותיות: ש-ל-ו-ם." },
  { subject: "hebrew", gradeLevel: 1, difficulty: "HARD", questionText: "השלימו: הכלב ___ בחצר.", options: ["רץ", "קורא", "שר", "לומד"], correctOptionIndex: 0, explanation: "המילה המתאימה לתיאור פעולה של כלב בחצר היא 'רץ'." },

  { subject: "hebrew", gradeLevel: 2, difficulty: "EASY", questionText: "מהי מילת ההפך למילה 'גדול'?", options: ["קטן", "יפה", "מהיר", "חכם"], correctOptionIndex: 0, explanation: "'קטן' הוא ההפך של 'גדול'." },
  { subject: "hebrew", gradeLevel: 2, difficulty: "MEDIUM", questionText: "איזו מהמילים הבאות היא 'פועל' (מתארת פעולה)?", options: ["קראה", "ספר", "שולחן", "כיתה"], correctOptionIndex: 0, explanation: "'קראה' מתארת פעולה שהילדה עשתה, ולכן היא פועל." },
  { subject: "hebrew", gradeLevel: 2, difficulty: "HARD", questionText: "מהי מילה נרדפת (בעלת משמעות דומה) למילה 'שמח'?", options: ["עצוב", "עליז", "כועס", "עייף"], correctOptionIndex: 1, explanation: "'עליז' משמעותו דומה ל'שמח'." },

  { subject: "hebrew", gradeLevel: 3, difficulty: "EASY", questionText: "מהו הרבים של המילה 'ילד'?", options: ["ילדים", "ילדות", "ילד", "ילדה"], correctOptionIndex: 0, explanation: "צורת הרבים של 'ילד' (זכר) היא 'ילדים'." },
  { subject: "hebrew", gradeLevel: 3, difficulty: "MEDIUM", questionText: "באיזה זמן נמצא הפועל 'הלכתי'?", options: ["עבר", "הווה", "עתיד", "ציווי"], correctOptionIndex: 0, explanation: "'הלכתי' מתאר פעולה שכבר קרתה, ולכן הוא בזמן עבר." },
  { subject: "hebrew", gradeLevel: 3, difficulty: "HARD", questionText: "מהי מילת ההפך למילה 'יום'?", options: ["לילה", "שמש", "בוקר", "ערב"], correctOptionIndex: 0, explanation: "'לילה' הוא ההפך של 'יום'." },

  { subject: "hebrew", gradeLevel: 4, difficulty: "EASY", questionText: "מהו שם התואר במשפט: 'הכלב הגדול נבח'?", options: ["הכלב", "הגדול", "נבח", "ה"], correctOptionIndex: 1, explanation: "'הגדול' מתאר את הכלב, ולכן הוא שם תואר." },
  { subject: "hebrew", gradeLevel: 4, difficulty: "MEDIUM", questionText: "באיזה זמן נמצא הפועל 'ילך'?", options: ["עתיד", "עבר", "הווה", "ציווי"], correctOptionIndex: 0, explanation: "'ילך' מתאר פעולה שעוד תקרה, ולכן הוא בזמן עתיד." },
  { subject: "hebrew", gradeLevel: 4, difficulty: "HARD", questionText: "השלימו: הילדים ___ בכדור בחצר.", options: ["משחקים", "קוראים", "ישנים", "אוכלים"], correctOptionIndex: 0, explanation: "המילה המתאימה לתיאור פעולה עם כדור היא 'משחקים'." },

  { subject: "hebrew", gradeLevel: 5, difficulty: "EASY", questionText: "מהו נושא המשפט: 'המורה כתבה על הלוח'?", options: ["המורה", "כתבה", "הלוח", "על"], correctOptionIndex: 0, explanation: "'המורה' היא מי שמבצעת את הפעולה, ולכן היא נושא המשפט." },
  { subject: "hebrew", gradeLevel: 5, difficulty: "MEDIUM", questionText: "מהי מילה נרדפת למילה 'יפה'?", options: ["מכוער", "נאה", "עצוב", "קטן"], correctOptionIndex: 1, explanation: "'נאה' משמעותו דומה ל'יפה'." },
  { subject: "hebrew", gradeLevel: 5, difficulty: "HARD", questionText: "מהו סוג המשפט: 'האם הגעת הביתה?'", options: ["משפט שאלה", "משפט חיווי", "משפט ציווי", "משפט קריאה"], correctOptionIndex: 0, explanation: "המשפט שואל שאלה ומסתיים בסימן שאלה, ולכן הוא משפט שאלה." },

  { subject: "hebrew", gradeLevel: 6, difficulty: "EASY", questionText: "מהו זמן הפועל 'קורא' במשפט 'הוא קורא ספר עכשיו'?", options: ["הווה", "עבר", "עתיד", "ציווי"], correctOptionIndex: 0, explanation: "המילה 'עכשיו' מרמזת שהפעולה קורית כעת, בזמן הווה." },
  { subject: "hebrew", gradeLevel: 6, difficulty: "MEDIUM", questionText: "מהי מילת הקישור המתאימה: 'רציתי לצאת, ___ ירד גשם'?", options: ["אבל", "וגם", "או", "כי"], correctOptionIndex: 0, explanation: "'אבל' מבטא ניגוד בין הרצון לצאת לבין הגשם שירד." },
  { subject: "hebrew", gradeLevel: 6, difficulty: "HARD", questionText: "מהו השורש של המילה 'התלבש'?", options: ["לבש", "תלבש", "בגד", "הת"], correctOptionIndex: 0, explanation: "המילה 'התלבש' נבנתה מהשורש ל.ב.ש, כמו במילה 'לבש'." },

  { subject: "hebrew", gradeLevel: 7, difficulty: "EASY", questionText: "מהו הבניין של הפועל 'התרחץ'?", options: ["התפעל", "פעל", "פיעל", "הפעיל"], correctOptionIndex: 0, explanation: "פעלים שמתחילים ב-'הת' שייכים בדרך כלל לבניין התפעל." },
  { subject: "hebrew", gradeLevel: 7, difficulty: "MEDIUM", questionText: "מהי מילת ההפך למילה 'התחלה'?", options: ["סוף", "אמצע", "המשך", "חלק"], correctOptionIndex: 0, explanation: "'סוף' הוא ההפך של 'התחלה'." },
  { subject: "hebrew", gradeLevel: 7, difficulty: "HARD", questionText: "באיזה בניין נמצא הפועל 'לימד'?", options: ["פיעל", "פעל", "הפעיל", "נפעל"], correctOptionIndex: 0, explanation: "'לימד' הוא בבניין פיעל, המבטא לרוב פעולה שגורמת לדבר-מה לקרות." },

  { subject: "hebrew", gradeLevel: 8, difficulty: "EASY", questionText: "מהי משמעות הביטוי 'אבד עליו הכלח'?", options: ["הפך ישן ולא רלוונטי", "נהיה חשוב מאוד", "קרה דבר טוב", "הגיע בזמן"], correctOptionIndex: 0, explanation: "הביטוי 'אבד עליו הכלח' מתאר דבר שהתיישן ואיבד את הרלוונטיות שלו." },
  { subject: "hebrew", gradeLevel: 8, difficulty: "MEDIUM", questionText: "מהי המילה הנרדפת ל'זריז'?", options: ["איטי", "מהיר", "עייף", "כבד"], correctOptionIndex: 1, explanation: "'מהיר' משמעותו דומה ל'זריז'." },
  { subject: "hebrew", gradeLevel: 8, difficulty: "HARD", questionText: "מהו סוג המשפט: 'לו הייתי עשיר, הייתי קונה בית גדול'?", options: ["משפט תנאי", "משפט שאלה", "משפט ציווי", "משפט קריאה"], correctOptionIndex: 0, explanation: "המשפט מתאר תנאי בטל (מצב לא אמיתי) ותוצאה שהייתה קורית אילו התנאי התקיים." },
];

const questions: SeedQuestion[] = [...math, ...english, ...hebrew];

async function main() {
  await prisma.question.createMany({ data: questions });
  console.log(`Seeded ${questions.length} questions.`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
