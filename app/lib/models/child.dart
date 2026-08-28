class Child {
  final String id;
  final String name;
  final int age;
  final String? grade;
  final int pointsBalance;
  final bool hasPin;
  final List<String> disabledSubjects;
  final Map<String, int>? subjectWeights;

  Child({
    required this.id,
    required this.name,
    required this.age,
    required this.grade,
    required this.pointsBalance,
    required this.hasPin,
    required this.disabledSubjects,
    required this.subjectWeights,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    final rawWeights = json['subjectWeights'] as Map<String, dynamic>?;
    return Child(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      grade: json['grade'] as String?,
      pointsBalance: json['pointsBalance'] as int,
      hasPin: json['hasPin'] as bool? ?? false,
      disabledSubjects: (json['disabledSubjects'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      subjectWeights: rawWeights?.map((key, value) => MapEntry(key, value as int)),
    );
  }
}
