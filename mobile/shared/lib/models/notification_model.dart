class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String? body;
  final String? senderName;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    this.body,
    this.senderName,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    title: json['title'] as String,
    body: json['body'] as String?,
    senderName: json['sender_name'] as String?,
    read: json['read'] as bool? ?? false,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'title': title,
    'body': body,
    'sender_name': senderName,
    'read': read,
  };

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? senderName,
    bool? read,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      senderName: senderName ?? this.senderName,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
