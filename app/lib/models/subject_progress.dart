class SubjectProgress {
  final String subject;
  final int currentGrade;
  final String currentDifficulty;

  SubjectProgress({
    required this.subject,
    required this.currentGrade,
    required this.currentDifficulty,
  });

  factory SubjectProgress.fromJson(Map<String, dynamic> json) {
    return SubjectProgress(
      subject: json['subject'] as String,
      currentGrade: json['currentGrade'] as int,
      currentDifficulty: json['currentDifficulty'] as String,
    );
  }
}
