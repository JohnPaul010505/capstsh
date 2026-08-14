import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/proof_video_viewer.dart';
import '../providers/month_entries_provider.dart';
import '../widgets/flip_card.dart';
import '../widgets/glow_card.dart';
import '../widgets/month_day_grid.dart';

/// Opens the calendar as a modal bottom sheet. Returns the picked day, or
/// [selected] if dismissed without a choice.
Future<DateTime> showCalendarFlipSheet(
  BuildContext context, {
  required DateTime selected,
  required DateTime today,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    builder: (_) => CalendarFlipSheet(selected: selected, today: today),
  ).then((value) => value ?? selected);
}

/// Flipping calendar matching the "Explosive Growth" card look: front is the
/// month grid, back is the day's workout list; a purple pill button flips it.
class CalendarFlipSheet extends ConsumerStatefulWidget {
  final DateTime selected;
  final DateTime today;

  const CalendarFlipSheet({super.key, required this.selected, required this.today});

  @override
  ConsumerState<CalendarFlipSheet> createState() => _CalendarFlipSheetState();
}

class _CalendarFlipSheetState extends ConsumerState<CalendarFlipSheet> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.selected.year, widget.selected.month, 1);
    _selectedDate = widget.selected;
  }

  void _shiftMonth(int delta) {
    setState(() {
      final month = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
      _visibleMonth = month;
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDate = day;
      _visibleMonth = DateTime(day.year, day.month, 1);
    });
  }

  List<Map<String, dynamic>> _workoutsFor(List<Map<String, dynamic>> workouts, DateTime day) {
    return workouts
        .where((w) {
          final t = DateTime.tryParse(w['logged_at'] as String? ?? '')?.toLocal();
          return t != null && t.year == day.year && t.month == day.month && t.day == day.day;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(monthEntriesProvider(_visibleMonth));
    final entries = entriesAsync.valueOrNull;
    final workouts =
        entries == null
            ? <Map<String, dynamic>>[]
            : (entries['workouts'] as List).cast<Map<String, dynamic>>();
    final meals =
        entries == null
            ? <Map<String, dynamic>>[]
            : (entries['meals'] as List).cast<Map<String, dynamic>>();
    final syncing = entriesAsync.isLoading;
    final failed = entriesAsync.hasError;
    final isToday = _selectedDate.year == widget.today.year &&
        _selectedDate.month == widget.today.month &&
        _selectedDate.day == widget.today.day;
    return Container(
      color: Colors.black38,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          height: 480,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: ClayTokens.clayDarkBase.withAlpha(200),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(18)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Row(
                        children: [
                          const Text('CALENDAR', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF2F2F7),
                          )),
                          const Spacer(),
                          if (syncing) ...[
                            const SizedBox(
                              width: 10, height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Color(0xFF8E8E93),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text('syncingâ€¦', style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                          ] else if (failed)
                            const Text("couldn't sync", style: TextStyle(fontSize: 10, color: Color(0xFFFF6B61))),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(_selectedDate),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withAlpha(20)),
                              ),
                              child: const Icon(Icons.close, color: Color(0xFFB4B4D0), size: 15),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
                        child: GlowCard(
                          borderRadius: 16,
                          borderWidth: 1.6,
                          child: FlipCard(
                            flipped: _flipped,
                            front: _FrontFace(
                              selected: _selectedDate,
                              today: widget.today,
                              visibleMonth: _visibleMonth,
                              workouts: workouts,
                              meals: meals,
                              onDayTap: _selectDay,
                              onShiftMonth: _shiftMonth,
                              onFlip: () => setState(() => _flipped = true),
                            ),
                            back: _BackFace(
                              day: _selectedDate,
                              isToday: isToday,
                              workouts: _workoutsFor(workouts, _selectedDate),
                              onFlip: () => setState(() => _flipped = false),
                            ),
                          ),
                        ),
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
  }
}

/// Front face: the month grid with a gradient pill button underneath.
class _FrontFace extends StatelessWidget {
  final DateTime selected;
  final DateTime today;
  final DateTime visibleMonth;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> meals;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<int> onShiftMonth;
  final VoidCallback onFlip;

  const _FrontFace({
    required this.selected,
    required this.today,
    required this.visibleMonth,
    required this.workouts,
    required this.meals,
    required this.onDayTap,
    required this.onShiftMonth,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MonthDayGrid(
            visibleMonth: visibleMonth,
            selected: selected,
            today: today,
            workouts: workouts,
            meals: meals,
            onDayTap: onDayTap,
            onShiftMonth: onShiftMonth,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _GlassPillButton(
            label: 'View Workout',
            onPressed: onFlip,
          ),
        ),
      ],
    );
  }
}

/// Back face: rich workout cards with glassmorphic styling.
class _BackFace extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final List<Map<String, dynamic>> workouts;
  final VoidCallback onFlip;

  const _BackFace({
    required this.day,
    required this.isToday,
    required this.workouts,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: Colors.white.withAlpha(15)),
        const SizedBox(height: 12),
        Expanded(
          child: workouts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withAlpha(12)),
                        ),
                        child: const Icon(Icons.fitness_center, size: 28, color: Color(0xFF636366)),
                      ),
                      const SizedBox(height: 12),
                      const Text('No workouts recorded',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
                      ),
                      const SizedBox(height: 4),
                      const Text('Complete a workout to see it here',
                        style: TextStyle(fontSize: 11, color: Color(0xFF636366)),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: _buildSessionGroups(context, workouts, isToday),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _GlassPillButton(
            label: 'Back to Calendar',
            onPressed: onFlip,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSessionGroups(BuildContext context, List<Map<String, dynamic>> workouts, bool isToday) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final w in workouts) {
      final name = w['workout_name'] as String? ?? 'Workout';
      groups.putIfAbsent(name, () => []).add(w);
    }

    final widgets = <Widget>[];
    var groupIndex = 0;
    final sortedEntries = groups.entries.toList()..sort((a, b) {
      final numA = int.tryParse(RegExp(r'S(\d+)').firstMatch(a.key)?.group(1) ?? '0') ?? 0;
      final numB = int.tryParse(RegExp(r'S(\d+)').firstMatch(b.key)?.group(1) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

    for (final entry in sortedEntries) {
      if (groupIndex > 0) {
        widgets.add(const SizedBox(height: 16));
      }
      final sessionName = entry.key == 'Workout S1' ? 'Workout' : entry.key;
      final exercises = entry.value;
      final totalDurationSeconds = exercises
          .map((e) => (e['duration_seconds'] as int?) ?? 0)
          .fold<int>(0, (sum, s) => sum + s);
      final totalDurationStr = totalDurationSeconds >= 60
          ? '${totalDurationSeconds ~/ 60}:${(totalDurationSeconds % 60).toString().padLeft(2, '0')} min'
          : '${totalDurationSeconds}s';
      final totalKcal = exercises
          .map((e) => (e['total_calories'] as int?) ?? 0)
          .fold<int>(0, (sum, k) => sum + k);

      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C3AED).withAlpha(30), Color(0xFF1C1C2E)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Color(0xFF7C3AED).withAlpha(50)),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)]),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sessionName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD6A5FF),
                  ),
                ),
              ),
              if (totalDurationSeconds > 0)
                Text(
                  totalDurationStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD6A5FF),
                  ),
                ),
              if (totalDurationSeconds > 0 && totalKcal > 0)
                const SizedBox(width: 8),
              if (totalKcal > 0)
                Text(
                  '$totalKcal kcal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9F0A),
                  ),
                ),
            ],
          ),
        ),
      );

      for (final w in exercises) {
        final name = w['exercise_name'] as String? ?? 'Exercise';
        final sets = w['sets'] as int?;
        final reps = w['reps'] as int?;
        final durationSeconds = w['duration_seconds'] as int?;
        final exerciseCalories = (w['exercise_calories'] as int?) ?? (w['total_calories'] as int?);
        final hasVideo = w['proof_url'] != null;
        final missing = !hasVideo && isToday;
        widgets.add(
          _WorkoutCard(
            name: name,
            sets: sets,
            reps: reps,
            durationSeconds: durationSeconds,
            calories: exerciseCalories,
            hasVideo: hasVideo,
            missing: missing,
            proofUrl: w['proof_url'] as String?,
          ),
        );
      }
      groupIndex++;
    }
    return widgets;
  }
}

/// Individual workout card with glassmorphic styling.
class _WorkoutCard extends StatelessWidget {
  final String name;
  final int? sets;
  final int? reps;
  final int? durationSeconds;
  final int? calories;
  final bool hasVideo;
  final bool missing;
  final String? proofUrl;

  const _WorkoutCard({
    required this.name,
    this.sets,
    this.reps,
    this.durationSeconds,
    this.calories,
    required this.hasVideo,
    required this.missing,
    this.proofUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  gradient: hasVideo
                      ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)])
                      : null,
                  color: hasVideo ? null : const Color(0xFF3A3A4A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasVideo ? Icons.check : Icons.fitness_center,
                  size: 14,
                  color: hasVideo ? Colors.white : const Color(0xFF8E8E93),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(name, style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7),
                )),
              ),
              if (durationSeconds != null)
                _DurationChip(seconds: durationSeconds!),
              if (durationSeconds != null && calories != null)
                const SizedBox(width: 6),
              if (calories != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F0A).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$calories kcal', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFFFF9F0A),
                  )),
                ),
              if (durationSeconds != null && calories == null)
                const SizedBox(width: 6),
              if (hasVideo)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('DONE', style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700, color: ClayTokens.clayAccentLight,
                  )),
                )
              else if (missing)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF453A).withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('NO PROOF', style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFFF6B61),
                  )),
                ),
            ],
          ),
          const SizedBox(height: 8),
           Row(
             children: [
               if (sets != null) _StatChip(label: '$sets', unit: 'sets'),
               if (sets != null && reps != null) const SizedBox(width: 6),
               if (reps != null) _StatChip(label: '$reps', unit: 'reps'),
             ],
           ),
          if (hasVideo) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                if (proofUrl != null) showProofVideoDialog(context, proofUrl!);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7C3AED).withAlpha(50),
                      const Color(0xFFC56BF0).withAlpha(30),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(100)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_circle_outline, size: 14, color: Color(0xFFD6A5FF)),
                    SizedBox(width: 4),
                    Text('Watch video proof', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFD6A5FF),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small stat chip for sets/reps/weight.
class _StatChip extends StatelessWidget {
  final String label;
  final String unit;

  const _StatChip({required this.label, required this.unit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7),
          )),
          const SizedBox(width: 3),
          Text(unit, style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF8E8E93),
          )),
        ],
      ),
    );
  }
}

/// Glassmorphic pill button Â· no Material/InkWell splash, just clean tap.

/// Duration chip formatted as minutes or minutes:seconds.
class _DurationChip extends StatelessWidget {
  final int seconds;

  const _DurationChip({required this.seconds});

  @override
  Widget build(BuildContext context) {
    final label = seconds < 60
        ? '${seconds}s'
        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} min';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withAlpha(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7),
          )),
        ],
      ),
    );
  }
  }
class _GlassPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GlassPillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)],
          ),
          borderRadius: BorderRadius.circular(9999),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withAlpha(50),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Center(
            child: Text(label, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
            )),
          ),
        ),
      ),
    );
  }
}
