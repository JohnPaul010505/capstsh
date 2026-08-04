class TrainerFeedback {
  final String id;
  final String trainerId;
  final String memberId;
  final String content;
  final DateTime createdAt;

  TrainerFeedback({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.content,
    required this.createdAt,
  });

  factory TrainerFeedback.fromJson(Map<String, dynamic> json) => TrainerFeedback(
    id: json['id'] as String,
    trainerId: json['trainer_id'] as String,
    memberId: json['member_id'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'trainer_id': trainerId,
    'member_id': memberId,
    'content': content,
  };
}
