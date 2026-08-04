import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';

final notificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService()
      .client
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false);
  return response;
});

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, 'Notifications'),
            Expanded(
              child: notifAsync.when(
                data: (notifs) {
                  if (notifs.isEmpty) {
                    return Center(
                      child: Text(
                        'No notifications',
                        style: TextStyle(
                          fontSize: 17,
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: ClayTokens.clayDarkSurface,
                    ),
                    child: ListView.builder(
                      itemCount: notifs.length,
                      itemBuilder: (context, i) {
                        final n = notifs[i];
                        final isLast = i == notifs.length - 1;
                        return Column(
                          children: [
                            Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Icon(
                                    CupertinoIcons.bell,
                                    color: ClayTokens.clayPrimary,
                                    size: 24,
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (n['read'] == false) {
                                        await SupabaseClientService().client
                                            .from('notifications')
                                            .update({'read': true})
                                            .eq('id', n['id']);
                                        ref.invalidate(notificationsProvider);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            n['title'] ?? '',
                                            style: ClayTokens.titleLarge.copyWith(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w500,
                                              color: ClayTokens.clayDarkTextPrimary,
                                              letterSpacing: -0.41,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            n['message'] ?? '',
                                            style: ClayTokens.titleMedium.copyWith(
                                              fontSize: 15,
                                              color: ClayTokens.clayDarkTextSecondary,
                                              letterSpacing: -0.24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                                  child: CupertinoSwitch(
                                    value: n['read'] == true,
                                    onChanged: (value) async {
                                      if (!value) {
                                        await SupabaseClientService().client
                                            .from('notifications')
                                            .update({'read': true})
                                            .eq('id', n['id']);
                                        ref.invalidate(notificationsProvider);
                                      }
                                    },
                                    activeTrackColor: ClayTokens.clayAccent,
                                  ),
                                ),
                              ],
                            ),
                            if (!isLast)
                              const SizedBox(height: 0.5),
                          ],
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'Error: $e',
                    style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayPrimary,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: ClayTokens.titleLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
                letterSpacing: -0.41,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
