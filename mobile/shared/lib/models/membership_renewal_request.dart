class MembershipRenewalRequest {
  final String id;
  final String memberId;
  final String? membershipId;
  final String planName;
  final int months;
  final String status;
  final String? note;

  /// Optional member-requested custom membership window (custom renewal).
  final DateTime? startDate;
  final DateTime? endDate;

  /// Amount the member says they were quoted when applying (optional;
  /// migration 0041 — null on rows written before it).
  final double? requestedPrice;

  /// Amount the admin actually collected on approval (migration 0041).
  /// Shown back to the member so the renewal receipt is honest.
  final double? approvedPrice;

  final DateTime requestedAt;
  final DateTime? decidedAt;

  MembershipRenewalRequest({
    required this.id,
    required this.memberId,
    this.membershipId,
    required this.planName,
    required this.months,
    required this.status,
    this.note,
    this.startDate,
    this.endDate,
    this.requestedPrice,
    this.approvedPrice,
    required this.requestedAt,
    this.decidedAt,
  });

  factory MembershipRenewalRequest.fromJson(Map<String, dynamic> json) =>
      MembershipRenewalRequest(
        id: json['id'] as String,
        memberId: json['member_id'] as String,
        membershipId: json['membership_id'] as String?,
        planName: json['plan_name'] as String? ?? 'Monthly',
        months: (json['months'] as num?)?.toInt() ?? 1,
        status: json['status'] as String? ?? 'pending',
        note: json['note'] as String?,
        startDate: DateTime.tryParse(json['start_date'] as String? ?? ''),
        endDate: DateTime.tryParse(json['end_date'] as String? ?? ''),
        requestedPrice: (json['requested_price'] as num?)?.toDouble(),
        approvedPrice: (json['approved_price'] as num?)?.toDouble(),
        requestedAt:
            DateTime.tryParse(json['requested_at'] as String? ?? '') ??
                DateTime.now(),
        decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
      );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';
}
