import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import 'package:shared/models/notification_model.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Notifications for the signed-in member.
///
/// User-scoped: watches [activeUserIdProvider] so a trainer -> member account
/// switch on the same device disposes the previous user's rows.
final memberNotificationsProvider =
    FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final authUid = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }
  return ref.read(notificationServiceProvider).fetchNotifications(userId);
});

/// Unread notification count for the signed-in member (user-scoped, see above).
final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) async {
  final userId = ref.watch(activeUserIdProvider);
  final authUid = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }
  return ref.read(notificationServiceProvider).unreadCount(userId);
});

final memberUnreadCountStreamProvider =
    StreamProvider.autoDispose<int>((ref) {
  final userId = ref.watch(activeUserIdProvider);
  final authUid = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }
  return ref.read(notificationServiceProvider).unreadCountStream(userId);
});