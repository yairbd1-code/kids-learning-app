class LearningTask {
  final String id;
  final String name;
  final String? description;
  final String? subject;
  final int? minAge;
  final int? maxAge;
  final int rewardPoints;

  LearningTask({
    required this.id,
    required this.name,
    required this.description,
    required this.subject,
    required this.minAge,
    required this.maxAge,
    required this.rewardPoints,
  });

  factory LearningTask.fromJson(Map<String, dynamic> json) {
    return LearningTask(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      subject: json['subject'] as String?,
      minAge: json['minAge'] as int?,
      maxAge: json['maxAge'] as int?,
      rewardPoints: json['rewardPoints'] as int,
    );
  }

  bool suitsAge(int age) {
    if (minAge != null && age < minAge!) return false;
    if (maxAge != null && age > maxAge!) return false;
    return true;
  }
}
