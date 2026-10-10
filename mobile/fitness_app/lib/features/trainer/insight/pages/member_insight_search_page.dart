import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../progress/pages/progress_list_page.dart' show assignedMembersProvider;

/// Member Insight search: the dashboard's "find a member" entry. Search by
/// name or member code, tap a row â†’ MemberInsightPage (goal progress, risk,
/// check-ins, measurements). Rows reuse the slimmed assignedMembersProvider
/// (name + last check-in), so this screen costs zero extra queries once the
/// Members tab has loaded.
class MemberInsightSearchPage extends ConsumerStatefulWidget {
  const MemberInsightSearchPage({super.key});

  @override
  ConsumerState<MemberInsightSearchPage> createState() =>
      _MemberInsightSearchPageState();
}

class _MemberInsightSearchPageState
    extends ConsumerState<MemberInsightSearchPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFirstMatch(List<Map<String, dynamic>> members) {
    if (_query.isEmpty || members.isEmpty) return;
    final q = _query;
    final match = members.firstWhere(
      (m) {
        final name = (m['full_name'] as String? ?? '').toLowerCase();
        final code = (m['code'] as String? ?? '').toLowerCase();
        return name.contains(q) || code.contains(q);
      },
      orElse: () => const <String, dynamic>{},
    );
    final id = match['id'] as String?;
    if (id != null && mounted) context.push('/trainer/insight/$id');
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(assignedMembersProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInsightNavBar(context),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => membersAsync.whenData(_openFirstMatch),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    style: ClayTokens.bodyLarge.copyWith(
                      color: ClayTokens.clayDarkTextPrimary,
                      fontSize: 14,
                    ),
                    cursorColor: ClayTokens.clayPrimary,
                    decoration: InputDecoration(
                      hintText: 'Search members by name or code',
                      hintStyle: ClayTokens.bodySmall.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: ClayTokens.clayDarkTextTertiary,
                        size: 18,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: ClayTokens.clayDarkTextTertiary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withAlpha(24),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ClayTokens.clayPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: membersAsync.when(
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_2,
                              color: ClayTokens.clayDarkTextTertiary,
                              size: 34,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No assigned members yet',
                              style: ClayTokens.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: ClayTokens.clayDarkTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final q = _query;
                    final filtered = q.isEmpty
                        ? members
                        : members.where((m) {
                            final name =
                                (m['full_name'] as String? ?? '').toLowerCase();
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
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      key: ValueKey('insight-search-$_query'),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final name = m['full_name'] as String? ?? 'Unknown';
                        return Semantics(
                          label: 'Open $name insights',
                          child: _SearchResultRow(data: m),
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
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: ClayTokens.labelMedium.copyWith(
                        fontWeight: FontWeight.w400,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildInsightNavBar(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Icon(
              Icons.chevron_left,
              color: ClayTokens.clayDarkTextPrimary,
              size: 22,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Member Insight',
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

/// One search result: avatar, name, last check-in â€” opens the member's
/// insight screen.
class _SearchResultRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SearchResultRow({required this.data});

  String _lastCheckinLabel(DateTime? t) {
    if (t == null) return 'No check-ins yet';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Last check-in today';
    if (diff == 1) return 'Last check-in yesterday';
    if (diff < 7) return 'Last check-in $diff days ago';
    if (diff < 30) return 'Last check-in ${(diff / 7).floor()} wk ago';
    return 'Last check-in ${(diff / 30).floor()} mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final name = data['full_name'] as String? ?? 'Unknown';
    final initials = name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join();
    final lastCheckin = data['last_checkin'] as DateTime?;

    return PressableCard(
      onTap: () => context.push('/trainer/insight/${data['id']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: ClayTokens.clayPrimaryLight.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withAlpha(18)),
      child: Row(
        children: [
          ClayAvatar(
            imageUrl: data['avatar_url'] as String?,
            initials: initials,
            size: ClayAvatarSize.md,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 11,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _lastCheckinLabel(lastCheckin),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
