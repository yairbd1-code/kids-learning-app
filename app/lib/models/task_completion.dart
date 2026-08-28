class TaskCompletion {
  final String id;
  final String taskName;
  final int pointsAwarded;
  final DateTime createdAt;

  TaskCompletion({
    required this.id,
    required this.taskName,
    required this.pointsAwarded,
    required this.createdAt,
  });

  factory TaskCompletion.fromJson(Map<String, dynamic> json) {
    return TaskCompletion(
      id: json['id'] as String,
      taskName: json['taskName'] as String,
      pointsAwarded: json['pointsAwarded'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
