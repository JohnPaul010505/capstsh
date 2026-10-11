import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
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

  Stream<int> unreadCountStream(String userId) {
    final controller = StreamController<int>();
    
    // Emit initial count
    unreadCount(userId).then((count) => controller.add(count));

    final channel = _client.channel('notifications_$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        // Re-fetch count when a new notification arrives
        unreadCount(userId).then((count) => controller.add(count));
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        // Re-fetch count when a notification is updated (e.g., marked as read)
        unreadCount(userId).then((count) => controller.add(count));
      },
    );
    channel.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        // Re-fetch count when a notification is deleted
        unreadCount(userId).then((count) => controller.add(count));
      },
    );
    channel.subscribe();

    // Close controller when stream is cancelled
    controller.onCancel = () {
      _client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<void> createNotification({
    required String userId,
    required String title,
    String? body,
    String? senderName,
  }) async {
    var resolvedSenderName = senderName?.trim();
    final senderId = _client.auth.currentUser?.id;
    if ((resolvedSenderName == null || resolvedSenderName.isEmpty) &&
        senderId != null) {
      try {
        final profile = await _client
            .from('profiles')
            .select('full_name')
            .eq('id', senderId)
            .maybeSingle();
        resolvedSenderName = (profile?['full_name'] as String?)?.trim();
      } catch (_) {
        // Saving the notification must not depend on a profile lookup.
      }
    }

    await _client.from('notifications').insert({
      'user_id': userId,
      'title': title,
      'body': body,
      'read': false,
      if (resolvedSenderName != null && resolvedSenderName.isNotEmpty)
        'sender_name': resolvedSenderName,
    });
  }
}
