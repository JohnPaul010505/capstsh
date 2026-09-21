class TrainerFeedback {
  final String id;
  final String trainerId;
  final String memberId;
  final String content;
  final int? rating;
  final DateTime? ratedAt;
  final DateTime createdAt;

  TrainerFeedback({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.content,
    this.rating,
    this.ratedAt,
    required this.createdAt,
  });

  factory TrainerFeedback.fromJson(Map<String, dynamic> json) => TrainerFeedback(
    id: json['id'] as String,
    trainerId: json['trainer_id'] as String? ?? '',
    memberId: json['member_id'] as String,
    content: json['content'] as String? ?? '',
    rating: json['rating'] as int?,
    ratedAt: json['rated_at'] == null ? null : DateTime.parse(json['rated_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'trainer_id': trainerId,
    'member_id': memberId,
    'content': content,
  };
}
