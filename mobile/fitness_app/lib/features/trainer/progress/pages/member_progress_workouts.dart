import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/proof_video_viewer.dart';
import '../../progress/widgets/member_tab_widgets.dart';
import '../../progress/providers/member_tab_providers.dart';

/// Workouts tab of Member Progress: the member's completed `workout_logs` in a
/// self-contained date window, 10 rows per page. Each row shows the exercise,
/// workout name, duration and calories; a play button opens the proof video
/// (when the member attached one).
class WorkoutsTab extends ConsumerStatefulWidget {
  final String id;
  const WorkoutsTab({super.key, required this.id});

  @override
  ConsumerState<WorkoutsTab> createState() => _WorkoutsTabState();
}

class _WorkoutsTabState extends ConsumerState<WorkoutsTab> {
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
          // Glass calendar: transparent surface so the glass gradient behind
          // it shows through — same liquid-glass system as the dashboard picker.
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
    final rowsAsync = ref.watch(memberWorkoutsProvider(key));

    return rowsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            SizedBox(height: 12),
            SkeletonCard(height: 90),
            SkeletonCard(height: 90),
            SkeletonCard(height: 90),
          ],
        ),
      ),
      error: (e, _) => MemberTabError(message: '$e'),
      data: _buildList,
    );
  }

  Widget _buildList(List<WorkoutRow> rows) {
    final totalPages = rows.isEmpty ? 1 : (rows.length / _pageSize).ceil();
    final safePage = _page.clamp(0, totalPages - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, rows.length);
    final slice = rows.isEmpty
        ? const <WorkoutRow>[]
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
            icon: Icons.fitness_center,
            message: 'No workouts logged in this window',
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
          ...slice.map((r) => _WorkoutRowCard(row: r)),
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

class _WorkoutRowCard extends StatelessWidget {
  final WorkoutRow row;
  const _WorkoutRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final hasWorkoutName = row.workoutName?.isNotEmpty == true;
    final title = hasWorkoutName ? row.workoutName! : row.exercise;
    final subtitle = hasWorkoutName
        ? row.exercise
        : DateFormat('EEE, MMM d · h:mm a').format(row.loggedAt);

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
              color: ClayTokens.clayPrimary.withAlpha(35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.fitness_center,
              size: 18,
              color: ClayTokens.clayPrimaryLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _MetaChip(
                      icon: Icons.timer_outlined,
                      label: row.durationLabel,
                    ),
                    if (row.calories != null) ...[
                      const SizedBox(width: 6),
                      _MetaChip(
                        icon: Icons.local_fire_department_outlined,
                        label: '${row.calories} kcal',
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (row.proofUrl != null && row.proofUrl!.isNotEmpty)
            GestureDetector(
              onTap: () => showProofVideoDialog(context, row.proofUrl!),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 22,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ClayTokens.clayDarkTextSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

