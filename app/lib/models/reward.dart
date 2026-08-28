class Reward {
  final String id;
  final String name;
  final int costPoints;

  Reward({required this.id, required this.name, required this.costPoints});

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] as String,
      name: json['name'] as String,
      costPoints: json['costPoints'] as int,
    );
  }
}
