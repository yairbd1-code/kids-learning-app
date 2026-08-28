class Redemption {
  final String id;
  final String rewardName;
  final int pointsSpent;
  final String status;
  final DateTime createdAt;

  Redemption({
    required this.id,
    required this.rewardName,
    required this.pointsSpent,
    required this.status,
    required this.createdAt,
  });

  factory Redemption.fromJson(Map<String, dynamic> json) {
    return Redemption(
      id: json['id'] as String,
      rewardName: json['rewardName'] as String,
      pointsSpent: json['pointsSpent'] as int,
      status: json['status'] as String? ?? 'APPROVED',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
