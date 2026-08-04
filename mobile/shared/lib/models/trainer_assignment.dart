class TrainerAssignment {
  final String id;
  final String trainerId;
  final String memberId;
  final DateTime assignedAt;
  final String status;

  TrainerAssignment({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.assignedAt,
    required this.status,
  });

  factory TrainerAssignment.fromJson(Map<String, dynamic> json) => TrainerAssignment(
    id: json['id'] as String,
    trainerId: json['trainer_id'] as String,
    memberId: json['member_id'] as String,
    assignedAt: DateTime.parse(json['assigned_at'] as String),
    status: json['status'] as String,
  );
}
