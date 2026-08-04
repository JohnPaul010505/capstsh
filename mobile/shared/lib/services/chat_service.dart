import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat.dart';
import 'supabase_client.dart';

class ChatService {
  final SupabaseClient _client;

  ChatService() : _client = SupabaseClientService().client;

  Future<List<ChatRoom>> getRooms(String userId) async {
    final response = await _client
        .from('chat_rooms')
        .select()
        .or('participant_one.eq.$userId,participant_two.eq.$userId')
        .order('created_at', ascending: false);
    return (response as List).map((e) => ChatRoom.fromJson(e)).toList();
  }

  Future<List<ChatMessage>> getMessages(String roomId) async {
    final response = await _client
        .from('chat_messages')
        .select()
        .eq('room_id', roomId)
        .order('created_at', ascending: true);
    return (response as List).map((e) => ChatMessage.fromJson(e)).toList();
  }

  Future<ChatMessage> sendMessage(ChatMessage message) async {
    final response = await _client
        .from('chat_messages')
        .insert(message.toJson())
        .select()
        .single();
    return ChatMessage.fromJson(response);
  }

  RealtimeChannel subscribeToRoom(String roomId, void Function(Map<String, dynamic>) onMessage) {
    return _client
        .channel('room-$roomId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) => onMessage(payload.newRecord),
        )
        .subscribe();
  }
}
