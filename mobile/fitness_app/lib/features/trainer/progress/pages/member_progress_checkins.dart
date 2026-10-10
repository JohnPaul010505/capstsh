import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../progress/widgets/member_tab_widgets.dart';
import '../../progress/providers/member_tab_providers.dart';

/// Check-ins tab of Member Progress: the member's `attendance` history in a
/// self-contained date window, 10 rows per page. Each row shows the date/time
/// and how they checked in (QR scan vs manual), colour-coded as a badge.
class CheckinsTab extends ConsumerStatefulWidget {
  final String id;
  const CheckinsTab({super.key, required this.id});

  @override
  ConsumerState<CheckinsTab> createState() => _CheckinsTabState();
}

class _CheckinsTabState extends ConsumerState<CheckinsTab> {
  static const _pageSize = 10;

  String _preset = 'month';
  late DateTime _start;
  late DateTime _end;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
  }

  void _applyPreset(String preset) {
    final w = presetWindow(preset, DateTime.now());
    setState(() {
      _preset = preset;
      _start = w.start;
      _end = w.end;
      _page = 0;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
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
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          ),
        ),
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
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    final dayEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    setState(() {
      _preset = 'custom';
      if (isStart) {
        _start = day;
        if (_end.isBefore(_start)) _end = dayEnd;
      } else {
        _end = dayEnd;
        if (_start.isAfter(_end)) _start = day;
      }
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = MemberRange(widget.id, ProgressRange(_start, _end));
    final rowsAsync = ref.watch(memberCheckinsProvider(key));

    return rowsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            SizedBox(height: 12),
            SkeletonCard(height: 70),
            SkeletonCard(height: 70),
            SkeletonCard(height: 70),
          ],
        ),
      ),
      error: (e, _) => MemberTabError(message: '$e'),
      data: _buildList,
    );
  }

  Widget _buildList(List<CheckinRow> rows) {
    final totalPages = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
    final safePage = _page.clamp(0, totalPages - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, rows.length);
    final slice = rows.isEmpty
        ? const <CheckinRow>[]
        : rows.sublist(start, end);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      physics: const ClampingScrollPhysics(),
      children: [
        MemberTabRangeBar(
          preset: _preset,
          start: _start,
          end: _end,
          onPreset: _applyPreset,
          onPickStart: () => _pickDate(isStart: true),
          onPickEnd: () => _pickDate(isStart: false),
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const MemberTabEmpty(
            icon: Icons.qr_code_scanner,
            message: 'No check-ins in this window',
          )
        else ...[
          if (rows.length > _pageSize)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${start + 1}–$end of ${rows.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ),
          ...slice.map((r) => _CheckinRowCard(row: r)),
          if (rows.length > _pageSize) ...[
            const SizedBox(height: 10),
            MemberTabPager(
              page: safePage,
              totalPages: totalPages,
              onPage: (p) => setState(() => _page = p),
            ),
          ],
        ],
      ],
    );
  }
}

class _CheckinRowCard extends StatelessWidget {
  final CheckinRow row;
  const _CheckinRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final method = (row.entryMethod ?? '').toLowerCase();
    final isQr = method == 'qr' || method == 'qr_scan';
    final isManual =
        method == 'manual' || method == 'trainer' || method == 'staff';
    final badgeLabel = isQr
        ? 'QR'
        : isManual
            ? 'Manual'
            : (row.entryMethod?.isNotEmpty == true
                ? row.entryMethod!
                : 'Check-in');
    final badgeColor = isQr
        ? const Color(0xFF0A84FF)
        : isManual
            ? const Color(0xFFFF9500)
            : ClayTokens.clayPrimaryLight;
    final badgeIcon = isQr ? Icons.qr_code_2 : Icons.edit_calendar_outlined;

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.login,
              size: 18,
              color: badgeColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMM d, y').format(row.checkInTime),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('h:mm a').format(row.checkInTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withAlpha(70)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(badgeIcon, size: 12, color: badgeColor),
                const SizedBox(width: 5),
                Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

