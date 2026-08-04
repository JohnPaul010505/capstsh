class Membership {
  final String id;
  final String memberId;
  final String planName;
  final double price;
  final String startDate;
  final String endDate;
  final String status;
  final DateTime createdAt;

  Membership({
    required this.id,
    required this.memberId,
    required this.planName,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory Membership.fromJson(Map<String, dynamic> json) => Membership(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    planName: json['plan_name'] as String,
    price: (json['price'] as num).toDouble(),
    startDate: json['start_date'] as String,
    endDate: json['end_date'] as String,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
