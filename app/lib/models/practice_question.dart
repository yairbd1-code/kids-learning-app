class PracticeQuestion {
  final String id;
  final String subject;
  final int gradeLevel;
  final String difficulty;
  final String questionText;
  final List<String> options;

  PracticeQuestion({
    required this.id,
    required this.subject,
    required this.gradeLevel,
    required this.difficulty,
    required this.questionText,
    required this.options,
  });

  factory PracticeQuestion.fromJson(Map<String, dynamic> json) {
    return PracticeQuestion(
      id: json['id'] as String,
      subject: json['subject'] as String,
      gradeLevel: json['gradeLevel'] as int,
      difficulty: json['difficulty'] as String,
      questionText: json['questionText'] as String,
      options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }
}

class PracticeAnswerResult {
  final bool correct;
  final int correctOptionIndex;
  final String explanation;
  final int pointsAwarded;
  final int newBalance;
  final int newGrade;
  final String newDifficulty;

  PracticeAnswerResult({
    required this.correct,
    required this.correctOptionIndex,
    required this.explanation,
    required this.pointsAwarded,
    required this.newBalance,
    required this.newGrade,
    required this.newDifficulty,
  });

  factory PracticeAnswerResult.fromJson(Map<String, dynamic> json) {
    return PracticeAnswerResult(
      correct: json['correct'] as bool,
      correctOptionIndex: json['correctOptionIndex'] as int,
      explanation: json['explanation'] as String,
      pointsAwarded: json['pointsAwarded'] as int,
      newBalance: json['newBalance'] as int,
      newGrade: json['newGrade'] as int,
      newDifficulty: json['newDifficulty'] as String,
    );
  }
}
