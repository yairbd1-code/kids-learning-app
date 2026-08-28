class Child {
  final String id;
  final String name;
  final int age;
  final String? grade;
  final int pointsBalance;
  final bool hasPin;

  Child({
    required this.id,
    required this.name,
    required this.age,
    required this.grade,
    required this.pointsBalance,
    required this.hasPin,
  });

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      name: json['name'] as String,
      age: json['age'] as int,
      grade: json['grade'] as String?,
      pointsBalance: json['pointsBalance'] as int,
      hasPin: json['hasPin'] as bool? ?? false,
    );
  }
}
