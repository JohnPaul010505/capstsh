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
    planName: json['plan_name'] as String? ?? 'Basic',
    price: (json['price'] as num?)?.toDouble() ?? 0,
    startDate: json['start_date'] as String? ?? '',
    endDate: json['end_date'] as String? ?? '',
    status: json['status'] as String? ?? 'active',
    createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
        DateTime.now(),
  );

  DateTime? get parsedEndDate => DateTime.tryParse(endDate);

  DateTime? get parsedStartDate => DateTime.tryParse(startDate);

  /// True when end_date is in the past (status in the DB may still be 'active';
  /// the admin panel treats end_date < today as expired too).
  bool get isExpired {
    final end = parsedEndDate;
    if (end == null) return false;
    final today = DateTime.now();
    final endOfDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return endOfDay.isBefore(today);
  }

  bool get isActive => status == 'active' && !isExpired;

  /// Whole days left until end_date (negative once expired).
  int? get daysRemaining {
    final end = parsedEndDate;
    if (end == null) return null;
    final today = DateTime.now();
    final endDay = DateTime(end.year, end.month, end.day);
    final todayDay = DateTime(today.year, today.month, today.day);
    return endDay.difference(todayDay).inDays;
  }
}

