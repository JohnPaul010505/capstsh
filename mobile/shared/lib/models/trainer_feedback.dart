class TrainerFeedback {
  final String id;
  final String trainerId;
  final String memberId;
  final String content;
  final int? rating;
  final DateTime? ratedAt;

  /// The member's own reply to this feedback. Single, not threaded: one comment
  /// per feedback row, written by the member the row is addressed to. Nullable
  /// because most feedback has not been answered yet.
  final String? memberComment;
  final DateTime? memberCommentedAt;

  final DateTime createdAt;

  TrainerFeedback({
    required this.id,
    required this.trainerId,
    required this.memberId,
    required this.content,
    this.rating,
    this.ratedAt,
    this.memberComment,
    this.memberCommentedAt,
    required this.createdAt,
  });

  factory TrainerFeedback.fromJson(Map<String, dynamic> json) => TrainerFeedback(
    id: json['id'] as String,
    trainerId: json['trainer_id'] as String? ?? '',
    memberId: json['member_id'] as String,
    content: json['content'] as String? ?? '',
    rating: json['rating'] as int?,
    ratedAt: json['rated_at'] == null ? null : DateTime.parse(json['rated_at'] as String),
    memberComment: json['member_comment'] as String?,
    memberCommentedAt: json['member_commented_at'] == null
        ? null
        : DateTime.parse(json['member_commented_at'] as String),
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  /// Insert payload only. `memberComment` is deliberately absent: a member can
  /// only ever ADD feedback and then comment on it, never set a comment in the
  /// same write, so including it here would send a column the insert policies
  /// do not speak to.
  Map<String, dynamic> toJson() => {
    'trainer_id': trainerId,
    'member_id': memberId,
    'content': content,
  };

  /// Whether this feedback has been answered by the member.
  bool get hasMemberComment =>
      memberComment != null && memberComment!.trim().isNotEmpty;
}
