import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

/// Assigned members with latest stats, fetched in THREE parallel queries
/// (profiles + measurements + goals) instead of 2xN per-member round trips.
/// Keep-alive (not autoDispose): the indexed-stack shell keeps this page
/// alive, so revisits render cached rows instantly while the router listener
/// below refetches in the background.
final assignedMembersWithStatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final assignments = await client
      .from('trainer_assignments')
      .select('member_id')
      .eq('trainer_id', userId)
      .eq('status', 'active');

  final memberIds = (assignments as List).map((a) => a['member_id'] as String).toList();
  if (memberIds.isEmpty) return [];

  final results = await Future.wait([
    client
        .from('profiles')
        .select('id, full_name, avatar_url, code')
        .inFilter('id', memberIds),
    // Newest-first for all members at once; first row per member wins below.
    client
        .from('body_measurements')
        .select('member_id, weight_kg, height_cm')
        .inFilter('member_id', memberIds)
        .order('measured_at', ascending: false),
    client
        .from('goals')
        .select('member_id, title')
        .inFilter('member_id', memberIds)
        .eq('status', 'active'),
  ]);

  final profileList = (results[0] as List).cast<Map<String, dynamic>>();

  final measByMember = <String, Map<String, dynamic>>{};
  for (final m in (results[1] as List).cast<Map<String, dynamic>>()) {
    final mid = m['member_id'] as String?;
    if (mid != null) measByMember.putIfAbsent(mid, () => m);
  }

  final goalByMember = <String, String>{};
  for (final g in (results[2] as List).cast<Map<String, dynamic>>()) {
    final mid = g['member_id'] as String?;
    if (mid != null) goalByMember.putIfAbsent(mid, () => g['title'] as String? ?? '');
  }

  return profileList.map((p) {
    final mid = p['id'] as String;
    final meas = measByMember[mid];
    return {
      'id': mid,
      'full_name': p['full_name'] as String? ?? 'Unknown',
      'avatar_url': p['avatar_url'] as String?,
      'code': p['code'] as String?,
      'weight_kg': meas?['weight_kg'],
      'height_cm': meas?['height_cm'],
      'goal': goalByMember[mid],
    };
  }).toList();
});

class ProgressListPage extends ConsumerStatefulWidget {
  const ProgressListPage({super.key});

  @override
  ConsumerState<ProgressListPage> createState() => _ProgressListPageState();
}

class _ProgressListPageState extends ConsumerState<ProgressListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  // Refresh-on-return: the indexed-stack shell keeps this page alive, so a
  // router listener refetches while cached rows render instantly.
  GoRouter? _router;
  bool _wasMembers = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= GoRouter.of(context);
    _router!.routerDelegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    final isMembers =
        _router!.routerDelegate.currentConfiguration.uri.path == '/trainer/members';
    if (isMembers && !_wasMembers && mounted) {
      ref.invalidate(assignedMembersWithStatsProvider);
    }
    _wasMembers = isMembers;
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(assignedMembersWithStatsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Members'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                  style: ClayTokens.bodyLarge.copyWith(
                      color: ClayTokens.clayDarkTextPrimary, fontSize: 14),
                  cursorColor: ClayTokens.clayPrimary,
                  decoration: InputDecoration(
                    hintText: 'Search members',
                    hintStyle: ClayTokens.bodySmall.copyWith(
                        color: ClayTokens.clayDarkTextTertiary),
                    prefixIcon: Icon(Icons.search,
                        color: ClayTokens.clayDarkTextTertiary, size: 18),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(Icons.clear,
                                color: ClayTokens.clayDarkTextTertiary,
                                size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: ClayTokens.clayDarkSurface,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: ClayTokens.clayDarkBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: ClayTokens.clayPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.person_2, color: ClayTokens.clayDarkTextTertiary, size: 48),
                            const SizedBox(height: 12),
                            Text('No assigned members yet', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                          ],
                        ),
                      );
                    }
                     // Client-side search on name + member code (e.g. M002).
                     final q = _query;
                     final filtered = q.isEmpty
                         ? members
                         : members.where((m) {
                             final name =
                                 (m['full_name'] as String? ?? '')
                                     .toLowerCase();
                             final code =
                                 (m['code'] as String? ?? '').toLowerCase();
                             return name.contains(q) || code.contains(q);
                           }).toList();
                     if (filtered.isEmpty) {
                       return Center(
                         child: Text(
                           'No members match "${_searchController.text.trim()}"',
                           style: ClayTokens.bodySmall.copyWith(
                               fontSize: 13,
                               fontWeight: FontWeight.w400,
                               color: ClayTokens.clayDarkTextTertiary,
                               letterSpacing: -0.08),
                         ),
                       );
                     }
                     return ListView.builder(
                       key: ValueKey('members-$_query'),
                       padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                       itemCount: filtered.length,
                       itemBuilder: (_, i) {
                         final m = filtered[i];
                         final name = m['full_name'] as String? ?? 'Unknown';
                         final initials = name.split(' ').map((n) => n[0]).take(2).join();
                         final avatarUrl = m['avatar_url'] as String?;
                         final weight = m['weight_kg'];
                         final height = m['height_cm'];

                         return Semantics(
                           label: 'View $name progress',
                           child: GestureDetector(
                             onTap: () => context.push('/trainer/members/${m['id']}'),
                             child: Container(
                               padding: const EdgeInsets.all(12),
                               margin: const EdgeInsets.only(bottom: 8),
                               decoration: BoxDecoration(
                                 color: ClayTokens.clayDarkSurface,
                                 borderRadius: BorderRadius.circular(16),
                                 border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                               ),
                               child: Row(
                                 children: [
                                   ClayAvatar(
                                     imageUrl: avatarUrl,
                                     initials: initials,
                                     size: ClayAvatarSize.md,
                                   ),
                                   const SizedBox(width: 10),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(name, style: ClayTokens.titleLarge.copyWith(
                                           fontSize: 15, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.24)),
                                         if (weight != null || height != null)
                                           Text(
                                             '${weight != null ? '$weight kg' : ''}${weight != null && height != null ? '  ·  ' : ''}${height != null ? '$height cm' : ''}',
                                             style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextTertiary, letterSpacing: 0.06)),
                                       ],
                                     ),
                                   ),
                                 ],
                               ),
                             ),
                           ),
                         );
                       },
                     );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        SkeletonCard(),
                        SkeletonCard(),
                        SkeletonCard(),
                        SkeletonCard(),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildTrainerNavBar(String title) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
      ),
    ),
    child: Row(
      children: [
        const SizedBox(width: 32),
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