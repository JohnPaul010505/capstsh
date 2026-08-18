import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import 'package:shared/models/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final memberNotificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return ref.read(notificationServiceProvider).fetchNotifications(userId);
});

final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return ref.read(notificationServiceProvider).unreadCount(userId);
});

final memberUnreadCountStreamProvider = StreamProvider<int>((ref) {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  return ref.read(notificationServiceProvider).unreadCountStream(userId);
});