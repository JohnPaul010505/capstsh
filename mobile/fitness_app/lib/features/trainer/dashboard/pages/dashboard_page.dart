import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/notification_popup.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';

// ---------------------------------------------------------------------------
// Shared glass surface — same liquid-glass recipe as the trainer nav bar
// ---------------------------------------------------------------------------
//
// Backdrop blur + white/purple translucent gradient + light rim + purple glow,
// identical to TrainerNavBar's bar body (via [GlassPanel]). Every card, chart
// card, KPI tile and range chip across the three dashboard screens goes through
// this class so the whole dashboard reads as one liquid-glass system.

class _NeumorphicSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double rx;

  const _NeumorphicSurface({
    required this.child,
    this.padding,
    this.rx = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: BorderRadius.circular(rx),
      child: child,
    );
  }
}

/// Neumorphic KPI card: small icon tile (solid brand purple + white glyph —
/// the same treatment on all twelve dashboard KPI cards) + big value + tiny
/// sub-caption.
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;

  const _KpiCard({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final subText = sub;
    return _NeumorphicSurface(
      rx: 14,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: ClayTokens.clayDarkTextPrimary,
                )),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: ClayTokens.clayDarkTextTertiary,
                )),
                if (subText != null) ...[
                  const SizedBox(height: 1),
                  Text(subText, style: TextStyle(
                    fontSize: 9.5,
                    color: ClayTokens.clayDarkTextSecondary,
                  )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable chart/card shell with a header strip: solid brand icon + title
/// on the left, an action tag or badge on the right, then a hairline. Below it,
/// either the chart/feed child or an empty state (doc icon + two-line guidance).
class _CardShell extends StatelessWidget {
  final String title;
  final Widget? headerRight;
  final Widget? chartOrChild;
  final String? emptyMessage;
  final String? emptyHint;

  const _CardShell({
    required this.title,
    this.headerRight,
    this.chartOrChild,
    this.emptyMessage,
    this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    return _NeumorphicSurface(
      rx: 18,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- header strip ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
              border: const Border(
                bottom: BorderSide(color: Color(0x207C3AED)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    CupertinoIcons.chart_bar_fill,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title, style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                    letterSpacing: -0.2,
                  )),
                ),
                if (headerRight != null) headerRight!,
              ],
            ),
          ),
          const SizedBox(height: 10),
          // --- body ---
          if (chartOrChild != null)
            chartOrChild!
          else
            _emptyState(
              message: emptyMessage ?? 'No data yet.',
              hint: emptyHint,
            ),
        ],
      ),
    );
  }

  Widget _emptyState({required String message, String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      // Stretch so the block spans the card and centres inside it, instead of
      // shrink-wrapping and hugging the left edge (both Activity Feed cards
      // show this state when the selected range has no records).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0x1D7C3AED),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.doc_text,
                color: ClayTokens.clayPrimaryLight,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small pill badge. Default = outline style (tinted bg + colored text),
/// the admin `Badge` treatment. [solid] flips it to a whole-color chip with
/// white text, used by the activity feed's TYPE column.
class _InlineBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;
  final bool solid;

  const _InlineBadge({
    required this.label,
    required this.color,
    this.small = false,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(
        color: solid ? color : color.withAlpha(30),
        borderRadius: BorderRadius.circular(small ? 6 : 8),
        border: solid ? null : Border.all(color: color.withAlpha(120)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: small ? 9 : 10.5,
        fontWeight: FontWeight.w700,
        color: solid ? Colors.white : color,
        letterSpacing: 0.3,
      )),
    );
  }
}

/// Arranges KPI cards into rows of two so four cards read as a 2x2 grid on
/// phone widths without each cell becoming unreadably narrow.
class _KpiGrid extends StatelessWidget {
  final List<_KpiCard> cards;

  const _KpiGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cards[i]),
              const SizedBox(width: 8),
              if (i + 1 < cards.length) Expanded(child: cards[i + 1]),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Tiny uppercase column header for the table-style feeds. Cell widths match
/// the fixed cells inside the feed rows: a width of 0 means the column
/// stretches, and the trailing fixed column is right-aligned.
class _TableHead extends StatelessWidget {
  final List<(String, double)> columns;

  const _TableHead({required this.columns});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: ClayTokens.clayDarkTextTertiary,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: [
          for (final (i, col) in columns.indexed) ...[
            if (i > 0) const SizedBox(width: 10),
            if (col.$2 <= 0)
              Expanded(child: Text(col.$1, style: style))
            else
              SizedBox(
                width: col.$2,
                child: Text(
                  col.$1,
                  textAlign: i == columns.length - 1
                      ? TextAlign.right
                      : TextAlign.left,
                  style: style,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Models


// ---------------------------------------------------------------------------

class TrainerMember {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? gender;
  final DateTime? createdAt;

  const TrainerMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.gender,
    this.createdAt,
  });
}

/// Immutable family key: a closed [start, end] window in local time.
class CheckinRange {
  final DateTime start;
  final DateTime end;

  const CheckinRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is CheckinRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class CheckinEntry {
  final String memberId;
  final String name;
  final String? avatarUrl;
  final DateTime time;
  final String? entryMethod;

  const CheckinEntry({
    required this.memberId,
    required this.name,
    this.avatarUrl,
    required this.time,
    this.entryMethod,
  });
}

class ChartBucket {
  final String label;
  final int count;

  const ChartBucket(this.label, this.count);
}

class CheckinData {
  final int total;
  final int uniqueMembers;
  final int todayCount;
  final List<CheckinEntry> feed;
  final List<ChartBucket> buckets;

  const CheckinData({
    required this.total,
    required this.uniqueMembers,
    required this.todayCount,
    required this.feed,
    required this.buckets,
  });

  static const CheckinData empty = CheckinData(
    total: 0,
    uniqueMembers: 0,
    todayCount: 0,
    feed: [],
    buckets: [],
  );
}

class MemberOverviewData {
  final int total;
  final int male;
  final int female;
  final int unspecified;
  final int active;
  final int inactive;

  const MemberOverviewData({
    required this.total,
    required this.male,
    required this.female,
    required this.unspecified,
    required this.active,
    required this.inactive,
  });

  static const MemberOverviewData empty = MemberOverviewData(
    total: 0,
    male: 0,
    female: 0,
    unspecified: 0,
    active: 0,
    inactive: 0,
  );
}

class ActivityEntry {
  /// One of: workout, comment, rating, food.
  final String type;
  final String memberId;
  final String memberName;
  final String? avatarUrl;
  final String description;
  final DateTime time;

  const ActivityEntry({
    required this.type,
    required this.memberId,
    required this.memberName,
    this.avatarUrl,
    required this.description,
    required this.time,
  });
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// The trainer's active assigned members with the profile fields the three
/// dashboard screens share (name, avatar, gender). Fetched once and reused by
/// every screen so each view costs a fixed, small number of round trips.
final trainerMembersProvider = FutureProvider<List<TrainerMember>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final assignments = await client
      .from('trainer_assignments')
      .select('member_id')
      .eq('trainer_id', userId)
      .eq('status', 'active');

  final memberIds = (assignments as List)
      .map((a) => a['member_id'] as String)
      .toList();
  if (memberIds.isEmpty) return const <TrainerMember>[];

  final profiles = await client
      .from('profiles')
      .select('id, full_name, avatar_url, gender, created_at')
      .inFilter('id', memberIds);

  return (profiles as List).cast<Map<String, dynamic>>().map((p) {
    return TrainerMember(
      id: p['id'] as String,
      name: p['full_name'] as String? ?? 'Unknown',
      avatarUrl: p['avatar_url'] as String?,
      gender: p['gender'] as String?,
      createdAt: DateTime.tryParse(p['created_at'] as String? ?? ''),
    );
  }).toList();
});

/// Daily Check-ins screen: check-in totals + activity trend buckets + the
/// chronological activity feed for the selected window.
final trainerCheckinsProvider =
    FutureProvider.family<CheckinData, CheckinRange>((ref, range) async {
  final members = await ref.watch(trainerMembersProvider.future);
  if (members.isEmpty) return CheckinData.empty;

  final ids = members.map((m) => m.id).toList();
  final byId = {for (final m in members) m.id: m};

  final client = SupabaseClientService().client;
  final rows = await client
      .from('attendance')
      .select('member_id, check_in_time, entry_method')
      .inFilter('member_id', ids)
      .gte('check_in_time', range.start.toUtc().toIso8601String())
      .lte('check_in_time', range.end.toUtc().toIso8601String())
      .order('check_in_time', ascending: false)
      .limit(2000);

  final list = (rows as List).cast<Map<String, dynamic>>();
  final times = <DateTime>[];
  final feed = <CheckinEntry>[];
  for (final r in list) {
    final parsed = DateTime.tryParse(r['check_in_time'] as String? ?? '');
    if (parsed == null) continue;
    final local = parsed.toLocal();
    times.add(local);
    if (feed.length < 60) {
      final member = byId[r['member_id'] as String];
      feed.add(
        CheckinEntry(
          memberId: r['member_id'] as String,
          name: member?.name ?? 'Unknown',
          avatarUrl: member?.avatarUrl,
          time: local,
          entryMethod: r['entry_method'] as String?,
        ),
      );
    }
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  return CheckinData(
    total: list.length,
    uniqueMembers:
        list.map((r) => r['member_id'] as String).toSet().length,
    todayCount: times.where((t) => !t.isBefore(todayStart)).length,
    feed: feed,
    buckets: _bucketize(times, range.start, range.end),
  );
});

/// Member Overview screen: gender split + active/inactive split. A member is
/// "active" when they checked in within the last 30 days.
final trainerMemberOverviewProvider = FutureProvider<MemberOverviewData>((
  ref,
) async {
  final members = await ref.watch(trainerMembersProvider.future);
  if (members.isEmpty) return MemberOverviewData.empty;

  final client = SupabaseClientService().client;
  final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
  final rows = await client
      .from('attendance')
      .select('member_id')
      .inFilter('member_id', members.map((m) => m.id).toList())
      .gte('check_in_time', thirtyDaysAgo.toIso8601String());

  final activeIds = <String>{
    for (final r in (rows as List).cast<Map<String, dynamic>>())
      r['member_id'] as String,
  };

  var male = 0;
  var female = 0;
  var unspecified = 0;
  for (final m in members) {
    final g = (m.gender ?? '').trim().toLowerCase();
    if (g == 'male') {
      male++;
    } else if (g == 'female') {
      female++;
    } else {
      unspecified++;
    }
  }
  final active = members.where((m) => activeIds.contains(m.id)).length;

  return MemberOverviewData(
    total: members.length,
    male: male,
    female: female,
    unspecified: unspecified,
    active: active,
    inactive: members.length - active,
  );
});

/// Recent Activity screen: a merged, newest-first feed of the trainer's
/// members' workouts, feedback comments, star ratings, and food logs, scoped
/// to the selected date window.
final trainerRecentActivityProvider =
    FutureProvider.family<List<ActivityEntry>, CheckinRange>((ref, range) async {
  final members = await ref.watch(trainerMembersProvider.future);
  if (members.isEmpty) return const <ActivityEntry>[];

  final ids = members.map((m) => m.id).toList();
  final byId = {for (final m in members) m.id: m};
  final client = SupabaseClientService().client;
  final startIso = range.start.toUtc().toIso8601String();
  final endIso = range.end.toUtc().toIso8601String();

  final results = await Future.wait([
    client
        .from('workout_logs')
        .select('member_id, exercise_name, logged_at')
        .inFilter('member_id', ids)
        .gte('logged_at', startIso)
        .lte('logged_at', endIso)
        .order('logged_at', ascending: false)
        .limit(200),
    client
        .from('trainer_feedback')
        .select(
          'member_id, rating, member_comment, member_commented_at, created_at',
        )
        .inFilter('member_id', ids)
        .gte('created_at', startIso)
        .lte('created_at', endIso)
        .order('created_at', ascending: false)
        .limit(200),
    client
        .from('meal_logs')
        .select('member_id, meal_type, food_name, meal_time')
        .inFilter('member_id', ids)
        .gte('meal_time', startIso)
        .lte('meal_time', endIso)
        .order('meal_time', ascending: false)
        .limit(200),
  ]);

  final entries = <ActivityEntry>[];

  for (final r in (results[0] as List).cast<Map<String, dynamic>>()) {
    final t = DateTime.tryParse(r['logged_at'] as String? ?? '');
    if (t == null) continue;
    final m = byId[r['member_id'] as String];
    final exercise = (r['exercise_name'] as String? ?? 'a workout').trim();
    entries.add(
      ActivityEntry(
        type: 'workout',
        memberId: r['member_id'] as String,
        memberName: m?.name ?? 'Unknown',
        avatarUrl: m?.avatarUrl,
        description: 'Completed $exercise',
        time: t.toLocal(),
      ),
    );
  }

  for (final r in (results[1] as List).cast<Map<String, dynamic>>()) {
    final mid = r['member_id'] as String;
    final m = byId[mid];
    final comment = (r['member_comment'] as String? ?? '').trim();
    final rating = (r['rating'] as num?)?.toInt();
    final at =
        DateTime.tryParse(r['member_commented_at'] as String? ?? '') ??
        DateTime.tryParse(r['created_at'] as String? ?? '');
    if (at == null) continue;
    final time = at.toLocal();
    if (comment.isNotEmpty) {
      entries.add(
        ActivityEntry(
          type: 'comment',
          memberId: mid,
          memberName: m?.name ?? 'Unknown',
          avatarUrl: m?.avatarUrl,
          description: 'Commented: "$comment"',
          time: time,
        ),
      );
    }
    if (rating != null) {
      entries.add(
        ActivityEntry(
          type: 'rating',
          memberId: mid,
          memberName: m?.name ?? 'Unknown',
          avatarUrl: m?.avatarUrl,
          description:
              'Rated your feedback $rating star${rating == 1 ? '' : 's'}',
          time: time,
        ),
      );
    }
  }

  for (final r in (results[2] as List).cast<Map<String, dynamic>>()) {
    final t = DateTime.tryParse(r['meal_time'] as String? ?? '');
    if (t == null) continue;
    final m = byId[r['member_id'] as String];
    final meal = (r['meal_type'] as String? ?? '').trim();
    final food = (r['food_name'] as String? ?? 'a meal').trim();
    entries.add(
      ActivityEntry(
        type: 'food',
        memberId: r['member_id'] as String,
        memberName: m?.name ?? 'Unknown',
        avatarUrl: m?.avatarUrl,
        description: 'Logged $food${meal.isEmpty ? '' : ' ($meal)'}',
        time: t.toLocal(),
      ),
    );
  }

  entries.sort((a, b) => b.time.compareTo(a.time));
  return entries.take(120).toList();
});

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Buckets check-in timestamps for the trend chart. A single day is split into
/// six 4-hour slots; anything up to ~2 months is bucketed per day; longer
/// windows (all time) fall back to months.
List<ChartBucket> _bucketize(
  List<DateTime> times,
  DateTime start,
  DateTime end,
) {
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day);
  final spanDays = endDay.difference(startDay).inDays + 1;

  if (spanDays <= 1) {
    const labels = ['12a', '4a', '8a', '12p', '4p', '8p'];
    final counts = List.filled(6, 0);
    for (final t in times) {
      counts[(t.hour ~/ 4).clamp(0, 5)]++;
    }
    return List.generate(6, (i) => ChartBucket(labels[i], counts[i]));
  }

  if (spanDays <= 62) {
    final counts = <String, int>{};
    for (final t in times) {
      final key = '${t.year}-${t.month}-${t.day}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final fmt = DateFormat('M/d');
    return List.generate(spanDays, (i) {
      final d = startDay.add(Duration(days: i));
      return ChartBucket(
        fmt.format(d),
        counts['${d.year}-${d.month}-${d.day}'] ?? 0,
      );
    });
  }

  final counts = <String, int>{};
  for (final t in times) {
    final key = '${t.year}-${t.month}';
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final fmt = DateFormat('MMM');
  final buckets = <ChartBucket>[];
  var cursor = DateTime(start.year, start.month);
  final endMonth = DateTime(end.year, end.month);
  while (!cursor.isAfter(endMonth)) {
    buckets.add(
      ChartBucket(
        fmt.format(cursor),
        counts['${cursor.year}-${cursor.month}'] ?? 0,
      ),
    );
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return buckets;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
      .toUpperCase();
}

String _timeAgo(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(t);
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _tab = 0;
  bool _isNotificationOpen = false;
  final _bellKey = GlobalKey();
  final _burgerKey = GlobalKey();
  bool _isMenuOpen = false;
  OverlayEntry? _menuOverlay;

  // Screen 1 (Daily Check-ins) has its own window...
  String _rangePreset = 'last7';
  late DateTime _rangeStart;
  late DateTime _rangeEnd;

  // ...and Screen 3 (Recent Activity) keeps a separate one, defaulting to the
  // full history so "recent activity" is never silently narrowed on open.
  String _activityPreset = 'all';
  late DateTime _activityStart;
  late DateTime _activityEnd;

  // Refresh-on-return: the indexed-stack shell keeps this page alive, so a
  // router listener refetches while cached data renders instantly.
  GoRouter? _router;
  bool _wasDashboard = true;

  @override
  void initState() {
    super.initState();
    _applyPreset('last7', notify: false);
    _applyPreset('all', notify: false, screen: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= GoRouter.of(context);
    _router!.routerDelegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    final isDashboard =
        _router!.routerDelegate.currentConfiguration.uri.path ==
        '/trainer/dashboard';
    if (isDashboard && !_wasDashboard && mounted) {
      ref.invalidate(trainerMembersProvider);
      ref.invalidate(trainerCheckinsProvider);
      ref.invalidate(trainerMemberOverviewProvider);
      ref.invalidate(trainerRecentActivityProvider);
    }
    _wasDashboard = isDashboard;
  }

  @override
  void dispose() {
    _menuOverlay?.remove();
    _menuOverlay = null;
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _toggleNotifications() {
    setState(() => _isNotificationOpen = !_isNotificationOpen);
  }

  void _closeNotifications() {
    setState(() => _isNotificationOpen = false);
  }

  /// [screen] 0 = Daily Check-ins, 1 = Recent Activity. The two screens keep
  /// independent windows so changing one never moves the other.
  void _applyPreset(String preset, {bool notify = true, int screen = 0}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    DateTime start;
    switch (preset) {
      case 'today':
        start = today;
        break;
      case 'month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'all':
        start = DateTime(2023, 1, 1);
        break;
      case 'last7':
      default:
        start = today.subtract(const Duration(days: 6));
        break;
    }
    void apply() {
      if (screen == 1) {
        _activityPreset = preset;
        _activityStart = start;
        _activityEnd = end;
      } else {
        _rangePreset = preset;
        _rangeStart = start;
        _rangeEnd = end;
      }
    }

    if (notify) {
      setState(apply);
    } else {
      apply();
    }
  }

  Future<void> _pickDate({required bool isStart, int screen = 0}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (screen == 1 ? _activityStart : _rangeStart)
          : (screen == 1 ? _activityEnd : _rangeEnd),
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: ClayTokens.clayPrimary,
            onPrimary: Colors.white,
            surface: ClayTokens.clayDarkSurfaceElevated,
            onSurface: ClayTokens.clayDarkTextPrimary,
          ),
          // Glass calendar: transparent surface so the notification-glass
          // gradient behind it shows through — same liquid-glass system as
          // the popups. Slightly higher alphas than the popup card because a
          // calendar needs the contrast to stay readable.
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          ),
        ),
        // The dialog's internal Align expands to whatever bounded box it is
        // given, which stretched our gradient wrapper edge-to-edge. Letting it
        // shrink-wrap (UnconstrainedBox) restores the normal dialog size; the
        // gradient card hugs it and Center re-centers the whole panel.
        child: Center(
          child: UnconstrainedBox(
            // Clip rather than paint outside the screen on very narrow devices
            // (the dialog's natural width is 360 + insets).
            clipBehavior: Clip.hardEdge,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF14142A).withAlpha(175),
                        const Color(0xFF221A4A).withAlpha(145),
                        const Color(0xFF14142A).withAlpha(185),
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withAlpha(38)),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    final dayEnd = DateTime(
      picked.year,
      picked.month,
      picked.day,
      23,
      59,
      59,
      999,
    );
    setState(() {
      if (screen == 1) {
        _activityPreset = 'custom';
        if (isStart) {
          _activityStart = day;
          if (_activityEnd.isBefore(_activityStart)) _activityEnd = dayEnd;
        } else {
          _activityEnd = dayEnd;
          if (_activityStart.isAfter(_activityEnd)) _activityStart = day;
        }
      } else {
        _rangePreset = 'custom';
        if (isStart) {
          _rangeStart = day;
          if (_rangeEnd.isBefore(_rangeStart)) _rangeEnd = dayEnd;
        } else {
          _rangeEnd = dayEnd;
          if (_rangeStart.isAfter(_rangeEnd)) _rangeStart = day;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: ClayTokens.clayDarkBorder,
                      width: 0.5,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Logo sits flush against the left edge, then the
                    // trainer's name with the greeting beneath it.
                    // Lowered ~2px so it reads optically with the name.
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Image.asset(
                        'assets/logo.png',
                        width: 34,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Consumer(
                      builder: (context, ref, _) {
                        final authAsync = ref.watch(authProvider);
                        return authAsync.when(
                          data: (profile) {
                            final fullName = profile?.fullName ?? 'Trainer';
                            final name = fullName.split(' ').first;
                            final isDay = DateTime.now().hour < 12;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: ClayTokens.titleLarge.copyWith(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: ClayTokens.clayDarkTextPrimary,
                                    letterSpacing: -0.41,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Row(
                                  children: [
                                    Icon(
                                      isDay ? Icons.wb_sunny : Icons.nights_stay,
                                      size: 16,
                                      color: ClayTokens.clayDarkTextTertiary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      greeting,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: ClayTokens.clayDarkTextTertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonBox(
                                width: 80,
                                height: 20,
                                borderRadius: 4,
                              ),
                              const SizedBox(height: 2),
                              const SkeletonBox(
                                width: 60,
                                height: 12,
                                borderRadius: 4,
                              ),
                            ],
                          ),
                          error: (_, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trainer', style: ClayTokens.titleLarge),
                              Text(greeting, style: ClayTokens.bodySmall),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    NotificationBell(
                      key: _bellKey,
                      isMember: false,
                      onTap: _toggleNotifications,
                      isActive: _isNotificationOpen,
                    ),
                    const SizedBox(width: 4),
                    _buildBurger(),
                  ],
                ),
              ),
              NotificationPopup(
                isOpen: _isNotificationOpen,
                isMember: false,
                onClose: _closeNotifications,
                bellKey: _bellKey,
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBurger() {
    return GestureDetector(
      key: _burgerKey,
      onTap: _isMenuOpen ? _closeBurgerMenu : _openBurgerMenu,
      behavior: HitTestBehavior.opaque,
      // Same treatment as NotificationBell: tint the icon when active —
      // never a filled purple box behind it.
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          Icons.menu,
          color: _isMenuOpen
              ? ClayTokens.clayPrimary
              : ClayTokens.clayDarkTextPrimary,
          size: 22,
        ),
      ),
    );
  }

  void _openBurgerMenu() {
    if (_menuOverlay != null) return;
    final box = _burgerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    final position = box.localToGlobal(Offset.zero);
    final size = box.size;
    setState(() => _isMenuOpen = true);
    _menuOverlay = OverlayEntry(
      builder: (_) => _BurgerMenuOverlay(
        position: position,
        size: size,
        selected: _tab,
        onPick: (value) {
          _closeBurgerMenu();
          setState(() => _tab = value);
        },
        onClose: _closeBurgerMenu,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menuOverlay != null) {
        Overlay.of(context).insert(_menuOverlay!);
      }
    });
  }

  void _closeBurgerMenu() {
    _menuOverlay?.remove();
    _menuOverlay = null;
    if (mounted && _isMenuOpen) setState(() => _isMenuOpen = false);
  }

  Widget _buildBody() {
    switch (_tab) {
      case 1:
        return const _MemberOverviewView();
      case 2:
        return _RecentActivityView(
          preset: _activityPreset,
          start: _activityStart,
          end: _activityEnd,
          onPreset: (preset) => _applyPreset(preset, screen: 1),
          onPickStart: () => _pickDate(isStart: true, screen: 1),
          onPickEnd: () => _pickDate(isStart: false, screen: 1),
        );
      case 0:
      default:
        return _DailyCheckinsView(
          preset: _rangePreset,
          start: _rangeStart,
          end: _rangeEnd,
          onPreset: _applyPreset,
          onPickStart: () => _pickDate(isStart: true),
          onPickEnd: () => _pickDate(isStart: false),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Feed pagination footer — record range + Prev/Next page controls (glass chips)
// ---------------------------------------------------------------------------

class _PagerFooter extends StatelessWidget {
  final int start;
  final int shown;
  final int total;
  final int page;
  final int pageCount;
  final ValueChanged<int> onPage;

  const _PagerFooter({
    required this.start,
    required this.shown,
    required this.total,
    required this.page,
    required this.pageCount,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 10.5,
      color: ClayTokens.clayDarkTextTertiary,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            pageCount > 1
                ? 'Showing $start\u2013${start + shown - 1} of $total'
                : '$total record${total == 1 ? '' : 's'}',
            style: style,
          ),
          if (pageCount > 1)
            Row(
              children: [
                _PagerBtn(
                  label: '\u2039 Prev',
                  enabled: page > 0,
                  onTap: () => onPage(page - 1),
                ),
                const SizedBox(width: 6),
                _PagerBtn(
                  label: 'Next \u203A',
                  enabled: page < pageCount - 1,
                  onTap: () => onPage(page + 1),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PagerBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PagerBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: enabled
              ? ClayTokens.clayPrimary
              : Colors.white.withAlpha(6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: enabled
                ? Colors.white
                : ClayTokens.clayDarkTextTertiary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Burger menu overlay — glass panel with a pointer triangle to the burger
// icon, mirroring NotificationPopup's arrow treatment.
// ---------------------------------------------------------------------------

class _MenuArrowPainter extends CustomPainter {
  final Color color;
  _MenuArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MenuArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _BurgerMenuOverlay extends StatelessWidget {
  final Offset position;
  final Size size;
  final int selected;
  final ValueChanged<int> onPick;
  final VoidCallback onClose;

  const _BurgerMenuOverlay({
    required this.position,
    required this.size,
    required this.selected,
    required this.onPick,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    const arrowWidth = 16.0;
    const arrowHeight = 8.0;
    const panelWidth = 210.0;
    final screenWidth = MediaQuery.of(context).size.width;

    final panelLeft =
        (position.dx + size.width / 2 - panelWidth / 2)
            .clamp(8.0, screenWidth - panelWidth - 8.0);
    final burgerCenterX = position.dx + size.width / 2;
    final arrowLeft = (burgerCenterX - arrowWidth / 2)
        .clamp(panelLeft + 12, panelLeft + panelWidth - arrowWidth - 12);
    final panelTop = position.dy + size.height + 6;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: panelTop,
          left: arrowLeft,
          child: CustomPaint(
            size: const Size(arrowWidth, arrowHeight),
            painter: _MenuArrowPainter(Colors.white.withAlpha(36)),
          ),
        ),
        Positioned(
          top: panelTop + arrowHeight,
          left: panelLeft,
          width: panelWidth,
          child: Material(
            color: Colors.transparent,
            // Same liquid-glass recipe as NotificationPopup's card: blurred
            // live backdrop + navy→indigo gradient, white rim, dual glow.
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(105),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: ClayTokens.clayPrimary.withAlpha(36),
                    blurRadius: 44,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF14142A).withAlpha(150),
                          const Color(0xFF221A4A).withAlpha(120),
                          const Color(0xFF14142A).withAlpha(160),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(38)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _menuRow(0, 'Daily Check-ins'),
                        _menuRow(1, 'Member Overview'),
                        _menuRow(2, 'Recent Activity'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuRow(int value, String title) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onPick(value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? ClayTokens.clayPrimary.withAlpha(60)
                    : Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${value + 1}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? ClayTokens.clayPrimaryLight
                      : ClayTokens.clayDarkTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? ClayTokens.clayDarkTextPrimary
                    : ClayTokens.clayDarkTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 1 — Daily Check-ins
// ---------------------------------------------------------------------------

class _DailyCheckinsView extends ConsumerStatefulWidget {
  final String preset;
  final DateTime start;
  final DateTime end;
  final void Function(String preset) onPreset;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _DailyCheckinsView({
    required this.preset,
    required this.start,
    required this.end,
    required this.onPreset,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  ConsumerState<_DailyCheckinsView> createState() =>
      _DailyCheckinsViewState();
}

class _DailyCheckinsViewState extends ConsumerState<_DailyCheckinsView> {
  static const _pageSize = 8;
  int _page = 0;

  @override
  void didUpdateWidget(covariant _DailyCheckinsView old) {
    super.didUpdateWidget(old);
    if (old.start != widget.start || old.end != widget.end) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      trainerCheckinsProvider(CheckinRange(widget.start, widget.end)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
      physics: const ClampingScrollPhysics(),
      children: [
        const SizedBox(height: 14),
        const _ScreenTitle(
          title: 'Daily Check-ins',
          subtitle: 'Every member visit in the selected window.',
        ),
        const SizedBox(height: 12),
        _RangeBar(
          preset: widget.preset,
          start: widget.start,
          end: widget.end,
          onPreset: widget.onPreset,
          onPickStart: widget.onPickStart,
          onPickEnd: widget.onPickEnd,
        ),
        const SizedBox(height: 14),
        async.when(
          data: (data) {
            final spanDays = widget.end
                    .difference(
                      DateTime(
                        widget.start.year,
                        widget.start.month,
                        widget.start.day,
                      ),
                    )
                    .inDays +
                1;
            final avg = data.total / (spanDays <= 0 ? 1 : spanDays);
            final pageCount = data.feed.isEmpty
                ? 1
                : ((data.feed.length + _pageSize - 1) ~/ _pageSize);
            final page = _page.clamp(0, pageCount - 1);
            final startIndex = page * _pageSize;
            final visible =
                data.feed.skip(startIndex).take(_pageSize).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggeredFadeIn(
                  index: 1,
                  child: _KpiGrid(
                    cards: [
                      _KpiCard(
                        label: 'CHECK-INS',
                        value: '${data.total}',
                        icon: Icons.how_to_reg,
                      ),
                      _KpiCard(
                        label: 'MEMBERS SEEN',
                        value: '${data.uniqueMembers}',
                        icon: Icons.groups,
                      ),
                      _KpiCard(
                        label: 'TODAY',
                        value: '${data.todayCount}',
                        icon: Icons.today,
                      ),
                      _KpiCard(
                        label: 'AVG / DAY',
                        value: avg.toStringAsFixed(1),
                        sub: 'over $spanDays day${spanDays == 1 ? '' : 's'}',
                        icon: Icons.speed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredFadeIn(
                  index: 2,
                  child: _TrendCard(
                    title: 'Activity Trend',
                    countLabel:
                        '${data.total} check-in${data.total == 1 ? '' : 's'}',
                    buckets: data.buckets,
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredFadeIn(
                  index: 3,
                  child: _CardShell(
                    title: 'Activity Feed',
                    headerRight: Text(
                      data.feed.isEmpty
                          ? 'No records'
                          : '${data.feed.length} records',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                    emptyMessage: 'No check-ins in this window.',
                    emptyHint: 'Try widening the date range above.',
                    chartOrChild: data.feed.isEmpty
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _TableHead(
                                columns: [
                                  ('DATE', 62),
                                  ('TIME', 56),
                                  ('MEMBER', 0),
                                  ('METHOD', 66),
                                ],
                              ),
                              const SizedBox(height: 4),
                              for (final e in visible)
                                _CheckinFeedTile(entry: e),
                              _PagerFooter(
                                start: startIndex + 1,
                                shown: visible.length,
                                total: data.feed.length,
                                page: page,
                                pageCount: pageCount,
                                onPage: (p) => setState(() => _page = p),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
          loading: () => const _LoadingColumn(
            blocks: [200, 130, 130],
          ),
          error: (e, _) => _ErrorCard(error: e),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RangeBar extends StatelessWidget {
  final String preset;
  final DateTime start;
  final DateTime end;
  final void Function(String preset) onPreset;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _RangeBar({
    required this.preset,
    required this.start,
    required this.end,
    required this.onPreset,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return _NeumorphicSurface(
      rx: 16,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateField(
                label: 'Start date',
                date: start,
                onTap: onPickStart,
              ),
              const SizedBox(width: 8),
              _DateField(
                label: 'End date',
                date: end,
                onTap: onPickEnd,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PresetChip(
                label: 'Today',
                value: 'today',
                selected: preset == 'today',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'Last 7 days',
                value: 'last7',
                selected: preset == 'last7',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'This month',
                value: 'month',
                selected: preset == 'month',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'All time',
                value: 'all',
                selected: preset == 'all',
                onTap: onPreset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 13,
                color: ClayTokens.clayDarkTextTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      DateFormat('MMM d, y').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String preset) onTap;

  const _PresetChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ClayTokens.clayPrimary
              : Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : ClayTokens.clayDarkTextSecondary,
          ),
        ),
      ),
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String title;
  final String countLabel;
  final List<ChartBucket> buckets;

  const _TrendCard({
    required this.title,
    required this.countLabel,
    required this.buckets,
  });

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: title,
      headerRight: Text(
        countLabel,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ClayTokens.clayPrimaryLight,
        ),
      ),
      emptyMessage: buckets.isEmpty ? 'No data in this window.' : null,
      emptyHint: buckets.isEmpty ? 'Try a wider date range.' : null,
      chartOrChild: buckets.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _TrendChart(buckets: buckets),
            ),
    );
  }
}

/// Smallest human-friendly tick (1, 2, 5, 10, 20, 25, 50, 100…) ≥ raw, so the
/// y-axis never shows ugly values like 23/46 or duplicate 1/1/1 labels.
int _trendNiceStep(int raw) {
  const steps = [
    1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500,
    5000, 10000, 20000, 25000, 50000, 100000,
  ];
  for (final s in steps) {
    if (s >= raw) return s;
  }
  return raw;
}

class _TrendChart extends StatelessWidget {
  final List<ChartBucket> buckets;

  const _TrendChart({required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxCount = buckets.fold<int>(0, (p, b) => b.count > p ? b.count : p);
    final rawMaxY = (maxCount == 0 ? 1 : maxCount).toDouble() * 1.3;
    final leftInterval = _trendNiceStep((rawMaxY / 3).ceil());
    final maxY = (rawMaxY / leftInterval).ceilToDouble() * leftInterval;
    final perBar = buckets.length > 20 ? 16.0 : 26.0;
    final barWidth = (perBar - 8).clamp(4.0, 16.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (buckets.length * perBar).clamp(constraints.maxWidth, 6000.0);
        return SizedBox(
          height: 180,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: width,
              child: BarChart(
                BarChartData(
                  minY: 0,
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipRoundedRadius: 10,
                      // No chip behind the value: the count is drawn as plain
                      // text, and a bucket of 0 returns null so fl_chart draws
                      // nothing at all (empty bar = no number).
                      getTooltipColor: (_) => Colors.transparent,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final count = buckets[group.x].count;
                        if (count == 0) return null;
                        return BarTooltipItem(
                          '$count',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: leftInterval.toDouble(),
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: ClayTokens.clayDarkBorder.withAlpha(80),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    // Y-axis numbers are gone: every bar carries its own
                    // value, so the left gutter was pure wasted width.
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= buckets.length) {
                            return const SizedBox.shrink();
                          }
                          final step = buckets.length <= 14
                              ? 1
                              : (buckets.length ~/ 8) + 1;
                          if (i % step != 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              buckets[i].label,
                              style: TextStyle(
                                fontSize: 11,
                                color: ClayTokens.clayDarkTextTertiary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(
                    buckets.length,
                    (i) => BarChartGroupData(
                      x: i,
                      // Value labels for every bucket, including long ranges
                      // like All time; fl_chart skips null items, so zero
                      // buckets stay blank.
                      showingTooltipIndicators: const [0],
                      barRods: [
                        BarChartRodData(
                          toY: buckets[i].count.toDouble(),
                          width: barWidth,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              ClayTokens.clayPrimaryLight,
                              ClayTokens.clayPrimary,
                            ],
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CheckinFeedTile extends StatelessWidget {
  final CheckinEntry entry;

  const _CheckinFeedTile({required this.entry});

  Color get _methodColor {
    switch (entry.entryMethod) {
      case 'manual':
        return const Color(0xFFFF9F0A);
      case 'qr':
        return const Color(0xFF30D158);
      default:
        return ClayTokens.clayDarkTextTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final method = entry.entryMethod == 'manual'
        ? 'MANUAL'
        : entry.entryMethod == 'qr'
        ? 'QR'
        : '-';
    return PressableCard(
      onTap: () => context.push('/trainer/members/${entry.memberId}'),
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      color: const Color(0x0A7C3AED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x147C3AED)),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Text(
              DateFormat('MMM d').format(entry.time),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 56,
            child: Text(
              DateFormat('h:mm a').format(entry.time),
              style: TextStyle(
                fontSize: 11.5,
                color: ClayTokens.clayDarkTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                ClayAvatar(
                  size: ClayAvatarSize.sm,
                  imageUrl: entry.avatarUrl,
                  initials: _initials(entry.name),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 66,
            child: Align(
              alignment: Alignment.centerRight,
              child: _InlineBadge(
                label: method,
                color: _methodColor,
                small: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 2 — Member Overview
// ---------------------------------------------------------------------------

class _MemberOverviewView extends ConsumerWidget {
  const _MemberOverviewView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trainerMemberOverviewProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
      physics: const ClampingScrollPhysics(),
      children: [
        const SizedBox(height: 14),
        const _ScreenTitle(
          title: 'Member Overview',
          subtitle: 'How your members split by gender and activity.',
        ),
        const SizedBox(height: 14),
        async.when(
          data: (data) {
            final members = ref
                .watch(trainerMembersProvider)
                .asData
                ?.value;
            final joined = members ?? const <TrainerMember>[];
            final cutoff = DateTime.now().subtract(
              const Duration(days: 30),
            );
            final newCount = joined
                .where(
                  (m) =>
                      m.createdAt != null &&
                      m.createdAt!.isAfter(cutoff),
                )
                .length;
            return Column(
              children: [
                StaggeredFadeIn(
                  index: 1,
                  child: _KpiGrid(
                    cards: [
                      _KpiCard(
                        label: 'TOTAL MEMBERS',
                        value: '${data.total}',
                        icon: Icons.people_alt,
                      ),
                      _KpiCard(
                        label: 'ACTIVE',
                        value: '${data.active}',
                        sub: 'checked in last 30 days',
                        icon: Icons.directions_run,
                      ),
                      _KpiCard(
                        label: 'INACTIVE',
                        value: '${data.inactive}',
                        sub: 'no visit in 30 days',
                        icon: Icons.person_off,
                      ),
                      _KpiCard(
                        label: 'NEW',
                        value: '$newCount',
                        sub: 'joined last 30 days',
                        icon: Icons.person_add,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredFadeIn(index: 2, child: _DistributionCard(data: data)),
              ],
            );
          },
          loading: () => const _LoadingColumn(blocks: [200, 240]),
          error: (e, _) => _ErrorCard(error: e),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final MemberOverviewData data;

  const _DistributionCard({required this.data});

  // Admin's SLICE_COLORS (TrendCharts.tsx): violet male, lilac female,
  // green active, rose inactive. Rose rather than amber for Inactive so the
  // two inner arcs separate at any size; lilac keeps both gender arcs in the
  // same violet family the admin card uses.
  static const _maleColor = Color(0xFF7C3AED);
  static const _femaleColor = Color(0xFFC084FC);
  static const _activeColor = Color(0xFF22C55E);
  static const _inactiveColor = Color(0xFFF43F5E);

  @override
  Widget build(BuildContext context) {
    // Female first: the admin card lists Gender as Female, Male — its slice
    // order comes from its { Female, Male, Other } count object.
    final genderSections = <PieChartSectionData>[
      if (data.female > 0)
        PieChartSectionData(
          value: data.female.toDouble(),
          color: _femaleColor,
          radius: 22,
          showTitle: false,
        ),
      if (data.male > 0)
        PieChartSectionData(
          value: data.male.toDouble(),
          color: _maleColor,
          radius: 22,
          showTitle: false,
        ),
      // "Unspecified" is deliberately NOT a slice: an empty value is not a
      // group. It is reported as a quiet "N not recorded" aside on the Gender
      // label below, exactly like the admin card.
    ];
    // Active before Inactive (admin order); zero counts are dropped from the
    // ring so an empty slice never paints a stray arc.
    final statusSections = <PieChartSectionData>[
      if (data.active > 0)
        PieChartSectionData(
          value: data.active.toDouble(),
          color: _activeColor,
          radius: 15,
          showTitle: false,
        ),
      if (data.inactive > 0)
        PieChartSectionData(
          value: data.inactive.toDouble(),
          color: _inactiveColor,
          radius: 15,
          showTitle: false,
        ),
    ];

    return _CardShell(
      title: 'Member Distribution',
      headerRight: Text(
        '${data.total} total',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: ClayTokens.clayDarkTextTertiary,
        ),
      ),
      chartOrChild: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        // Admin layout: donut on the LEFT, both breakdown groups stacked on
        // the RIGHT, vertically centred against the ring.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
              width: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // OUTER ring = gender, mirroring the admin radii (70%→100%):
                  // the wider of the two bands, so it reads first.
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 53,
                      startDegreeOffset: -90,
                      sections: genderSections.isEmpty
                          ? [
                              PieChartSectionData(
                                value: 1,
                                color: ClayTokens.clayDarkBorder,
                                radius: 22,
                                showTitle: false,
                              ),
                            ]
                          : genderSections,
                    ),
                  ),
                  // INNER ring = activity status (42%→62%), nested inside with
                  // a visible gap so the two wholes never read as one ring.
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 32,
                      startDegreeOffset: -90,
                      sections: statusSections.isEmpty
                          ? [
                              PieChartSectionData(
                                value: 1,
                                color: ClayTokens.clayDarkBorder,
                                radius: 15,
                                showTitle: false,
                              ),
                            ]
                          : statusSections,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${data.total > 0 ? ((data.active / data.total) * 100).round() : 0}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: ClayTokens.clayDarkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _BreakdownGroup(
                    title: 'Gender',
                    aside: data.unspecified > 0
                        ? '${data.unspecified} not recorded'
                        : null,
                    items: [
                      if (data.female > 0)
                        ('Female', data.female, _femaleColor),
                      if (data.male > 0) ('Male', data.male, _maleColor),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _BreakdownGroup(
                    title: 'Activity Status',
                    items: [
                      if (data.active > 0)
                        ('Active', data.active, _activeColor),
                      if (data.inactive > 0)
                        ('Inactive', data.inactive, _inactiveColor),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One breakdown group of the admin's Member Distribution card: an uppercase
/// label (with an optional quiet aside like "3 not recorded"), one row per
/// slice — dot, name, count, share — and a single stacked proportion bar
/// closing the group. The bar carries the split as one whole, so "half and
/// half" reads at a glance instead of row-by-row.
class _BreakdownGroup extends StatelessWidget {
  final String title;
  final String? aside;
  final List<(String, int, Color)> items;

  const _BreakdownGroup({required this.title, this.aside, required this.items});

  @override
  Widget build(BuildContext context) {
    final sum = items.fold<int>(0, (p, e) => p + e.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ),
            if (aside != null)
              Text(
                aside!,
                style: TextStyle(
                  fontSize: 9.5,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        for (final e in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: e.$3,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.$1,
                    style: TextStyle(
                      fontSize: 12,
                      color: ClayTokens.clayDarkTextSecondary,
                    ),
                  ),
                ),
                Text(
                  '${e.$2}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${sum > 0 ? (e.$2 * 100 / sum).round() : 0}%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 11,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        // The stacked proportion bar: every slice of THIS group as one line.
        if (sum > 0 && items.isNotEmpty)
          Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  flex: items[i].$2,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: items[i].$3,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}



// ---------------------------------------------------------------------------
// Screen 3 — Recent Activity
// ---------------------------------------------------------------------------

class _RecentActivityView extends ConsumerStatefulWidget {
  final String preset;
  final DateTime start;
  final DateTime end;
  final void Function(String preset) onPreset;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _RecentActivityView({
    required this.preset,
    required this.start,
    required this.end,
    required this.onPreset,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  ConsumerState<_RecentActivityView> createState() =>
      _RecentActivityViewState();
}

class _RecentActivityViewState extends ConsumerState<_RecentActivityView> {
  static const _pageSize = 8;
  int _page = 0;

  @override
  void didUpdateWidget(covariant _RecentActivityView old) {
    super.didUpdateWidget(old);
    if (old.start != widget.start || old.end != widget.end) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      trainerRecentActivityProvider(CheckinRange(widget.start, widget.end)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 110),
      physics: const ClampingScrollPhysics(),
      children: [
        const SizedBox(height: 14),
        const _ScreenTitle(
          title: 'Recent Activity',
          subtitle: 'Workouts, comments, ratings and food logs.',
        ),
        const SizedBox(height: 12),
        _RangeBar(
          preset: widget.preset,
          start: widget.start,
          end: widget.end,
          onPreset: widget.onPreset,
          onPickStart: widget.onPickStart,
          onPickEnd: widget.onPickEnd,
        ),
        const SizedBox(height: 14),
        async.when(
          data: (entries) {
            final pageCount = entries.isEmpty
                ? 1
                : ((entries.length + _pageSize - 1) ~/ _pageSize);
            final page = _page.clamp(0, pageCount - 1);
            final startIndex = page * _pageSize;
            final visible = entries.skip(startIndex).take(_pageSize).toList();
            final workouts = entries
                .where((e) => e.type == 'workout')
                .length;
            final feedback = entries
                .where((e) => e.type == 'comment' || e.type == 'rating')
                .length;
            final meals = entries.where((e) => e.type == 'food').length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StaggeredFadeIn(
                  index: 1,
                  child: _KpiGrid(
                    cards: [
                      _KpiCard(
                        label: 'ACTIVITIES',
                        value: '${entries.length}',
                        icon: Icons.bolt,
                      ),
                      _KpiCard(
                        label: 'WORKOUTS',
                        value: '$workouts',
                        icon: Icons.fitness_center,
                      ),
                      _KpiCard(
                        label: 'FEEDBACK',
                        value: '$feedback',
                        icon: Icons.rate_review,
                      ),
                      _KpiCard(
                        label: 'MEALS',
                        value: '$meals',
                        icon: Icons.restaurant,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredFadeIn(
                  index: 2,
                  child: _TrendCard(
                    title: 'Activity Trend',
                    countLabel:
                        '${entries.length} ${entries.length == 1 ? 'activity' : 'activities'}',
                    buckets: _bucketize(
                      entries.map((e) => e.time).toList(),
                      widget.start,
                      widget.end,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                StaggeredFadeIn(
                  index: 3,
                  child: _CardShell(
                    title: 'Activity Feed',
                    headerRight: Text(
                      entries.isEmpty
                          ? 'No records'
                          : '${entries.length} activities',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                    emptyMessage: 'No member activity in this window.',
                    emptyHint: 'Try widening the date range above.',
                    chartOrChild: entries.isEmpty
                        ? null
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const _TableHead(
                                columns: [
                                  ('TYPE', 64),
                                  ('MEMBER / DETAILS', 0),
                                  ('WHEN', 52),
                                ],
                              ),
                              const SizedBox(height: 4),
                              for (final e in visible)
                                _ActivityTile(entry: e),
                              _PagerFooter(
                                start: startIndex + 1,
                                shown: visible.length,
                                total: entries.length,
                                page: page,
                                pageCount: pageCount,
                                onPage: (p) => setState(() => _page = p),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
          loading: () => const _LoadingColumn(
            blocks: [200, 130, 130],
          ),
          error: (e, _) => _ErrorCard(error: e),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final ActivityEntry entry;

  const _ActivityTile({required this.entry});

  (String, Color) get _typeMeta {
    // Solid chips with white text. The tones are the 700-level shades of the
    // same hues used elsewhere (green/amber/blue) so white text stays
    // legible at 9px — the brighter tints only reach ~2:1 contrast.
    switch (entry.type) {
      case 'workout':
        return ('WORKOUT', ClayTokens.clayPrimary);
      case 'comment':
        return ('COMMENT', const Color(0xFF1D4ED8));
      case 'rating':
        return ('RATING', const Color(0xFFB45309));
      case 'food':
        return ('FOOD', const Color(0xFF15803D));
      default:
        return (entry.type.toUpperCase(), ClayTokens.clayPrimaryLight);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color) = _typeMeta;
    return PressableCard(
      onTap: () => context.push('/trainer/members/${entry.memberId}'),
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      color: const Color(0x0A7C3AED),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0x147C3AED)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: _InlineBadge(label: label, color: color, small: true, solid: true),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.memberName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: ClayTokens.clayDarkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 52,
            child: Text(
              _timeAgo(entry.time),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10.5,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

class _ScreenTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ScreenTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: ClayTokens.titleLarge.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: ClayTokens.clayDarkTextPrimary,
            letterSpacing: -0.41,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: ClayTokens.clayDarkTextTertiary,
          ),
        ),
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final Object error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Error: $error',
        style: ClayTokens.labelMedium.copyWith(
          fontWeight: FontWeight.w400,
          color: ClayTokens.clayDarkTextTertiary,
        ),
      ),
    );
  }
}

class _LoadingColumn extends StatelessWidget {
  final List<double> blocks;

  const _LoadingColumn({required this.blocks});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final h in blocks) ...[
          const SizedBox(height: 10),
          SkeletonBox(height: h),
        ],
      ],
    );
  }
}
