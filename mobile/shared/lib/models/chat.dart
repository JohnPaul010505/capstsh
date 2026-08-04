class ChatRoom {
  final String id;
  final String participantOne;
  final String participantTwo;
  final DateTime createdAt;

  ChatRoom({
    required this.id,
    required this.participantOne,
    required this.participantTwo,
    required this.createdAt,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) => ChatRoom(
    id: json['id'] as String,
    participantOne: json['participant_one'] as String,
    participantTwo: json['participant_two'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String,
    roomId: json['room_id'] as String,
    senderId: json['sender_id'] as String,
    content: json['content'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'room_id': roomId,
    'sender_id': senderId,
    'content': content,
  };
}
