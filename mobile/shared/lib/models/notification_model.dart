class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    body: json['body'] as String?,
    read: json['read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'title': title,
    'body': body,
    'read': read,
  };
}
