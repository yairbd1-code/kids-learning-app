class QuestionDraft {
  final String id;
  final String subject;
  final int gradeLevel;
  final String difficulty;
  final String questionText;
  final List<String> options;
  final int correctOptionIndex;
  final String explanation;
  final bool approved;
  final String source;

  QuestionDraft({
    required this.id,
    required this.subject,
    required this.gradeLevel,
    required this.difficulty,
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
    required this.explanation,
    required this.approved,
    required this.source,
  });

  factory QuestionDraft.fromJson(Map<String, dynamic> json) {
    return QuestionDraft(
      id: json['id'] as String,
      subject: json['subject'] as String,
      gradeLevel: json['gradeLevel'] as int,
      difficulty: json['difficulty'] as String,
      questionText: json['questionText'] as String,
      options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      correctOptionIndex: json['correctOptionIndex'] as int,
      explanation: json['explanation'] as String,
      approved: json['approved'] as bool,
      source: json['source'] as String,
    );
  }
}
