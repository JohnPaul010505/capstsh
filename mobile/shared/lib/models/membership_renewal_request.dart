class MembershipRenewalRequest {
  final String id;
  final String memberId;
  final String? membershipId;
  final String planName;
  final int months;
  final String status;
  final String? note;
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
        requestedAt:
            DateTime.tryParse(json['requested_at'] as String? ?? '') ??
                DateTime.now(),
        decidedAt: DateTime.tryParse(json['decided_at'] as String? ?? ''),
      );

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDeclined => status == 'declined';
}
