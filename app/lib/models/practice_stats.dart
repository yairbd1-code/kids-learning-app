class PracticeStats {
  final String subject;
  final int? currentGrade;
  final String? currentDifficulty;
  final int totalAnswered;
  final int totalCorrect;
  final int? correctPercent;

  PracticeStats({
    required this.subject,
    required this.currentGrade,
    required this.currentDifficulty,
    required this.totalAnswered,
    required this.totalCorrect,
    required this.correctPercent,
  });

  factory PracticeStats.fromJson(Map<String, dynamic> json) {
    return PracticeStats(
      subject: json['subject'] as String,
      currentGrade: json['currentGrade'] as int?,
      currentDifficulty: json['currentDifficulty'] as String?,
      totalAnswered: json['totalAnswered'] as int,
      totalCorrect: json['totalCorrect'] as int,
      correctPercent: json['correctPercent'] as int?,
    );
  }
}
