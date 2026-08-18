import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_client.dart';
import '../models/notification_model.dart';

class NotificationService {
  final _client = SupabaseClientService().client;

  Future<List<AppNotification>> fetchNotifications(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'read': true})
        .eq('id', notificationId);
  }

  Future<int> unreadCount(String userId) async {
    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .eq('read', false);
    return (response as List).length;
  }
}
