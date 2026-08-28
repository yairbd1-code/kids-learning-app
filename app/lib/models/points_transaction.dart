class PointsTransaction {
  final String id;
  final int amount;
  final String reason;
  final DateTime createdAt;

  PointsTransaction({
    required this.id,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory PointsTransaction.fromJson(Map<String, dynamic> json) {
    return PointsTransaction(
      id: json['id'] as String,
      amount: json['amount'] as int,
      reason: json['reason'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
