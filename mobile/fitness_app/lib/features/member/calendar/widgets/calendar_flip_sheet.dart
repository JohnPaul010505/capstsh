import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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
              child: Material(
                color: ClayTokens.clayDarkBase.withAlpha(245),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
                            const Text('syncing…', style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
                          ] else if (failed)
                            const Text("couldn't sync", style: TextStyle(fontSize: 10, color: Color(0xFFFF6B61))),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(_selectedDate),
                            icon: const Icon(Icons.check, size: 15, color: Color(0xFFD6A5FF)),
                            label: Text(
                              'Done · ${DateFormat('MMM d').format(_selectedDate)}',
                              style: const TextStyle(fontSize: 11, color: Color(0xFFD6A5FF)),
                            ),
                          ),
                          const SizedBox(width: 2),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(_selectedDate),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(120),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFF2A2A45)),
                              ),
                              child: const Icon(Icons.close, color: Color(0xFFB4B4D0), size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
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
          child: _GradientPillButton(
            label: 'View Workout',
            onPressed: onFlip,
          ),
        ),
      ],
    );
  }
}

/// Back face: the React-style card with title, divider, check-list rows and a
/// gradient button.
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
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 13, color: Color(0xFFD6A5FF)),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEEE, MMM d, yyyy').format(day),
              style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFF2F5F7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 1, color: const Color(0xFF2A2A45)),
        const SizedBox(height: 12),
        Expanded(
          child: workouts.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, size: 26, color: Color(0xFF636366)),
                      SizedBox(height: 8),
                      Text('No Workout in this Day',
                        style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: workouts.map((w) {
                      final name = w['exercise_name'] as String? ?? 'Exercise';
                      final sets = w['sets'] as int?;
                      final reps = w['reps'] as int?;
                      final weight = w['weight_kg'] as double?;
                      final hasVideo = w['proof_url'] != null;
                      final missing = !hasVideo && isToday;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: const Icon(Icons.check, size: 14, color: Color(0xFF0F0E16)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFF2F5F7),
                                  )),
                                  Text(
                                    [
                                      if (sets != null) '$sets sets',
                                      if (reps != null) '$reps reps',
                                      if (weight != null) '$weight kg',
                                    ].join(' · '),
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                                  ),
                                ],
                              ),
                            ),
                            if (hasVideo) ...[
                              GestureDetector(
                                onTap: () {
                                  final url = w['proof_url'] as String?;
                                  if (url != null) {
                                    showProofVideoDialog(context, url);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7C3AED).withAlpha(40),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF7C3AED).withAlpha(120)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_arrow, size: 12, color: Color(0xFFD6A5FF)),
                                      SizedBox(width: 2),
                                      Text('Video', style: TextStyle(
                                        fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFD6A5FF),
                                      )),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
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
                                child: const Text('MISSING VIDEO', style: TextStyle(
                                  fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFFF6B61),
                                )),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _GradientPillButton(
            label: 'Back to Calendar',
            onPressed: onFlip,
          ),
        ),
      ],
    );
  }
}

/// Reproduces the React `.button`: violet gradient pill with white glow, used
/// as the flip trigger.
class _GradientPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _GradientPillButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)],
        ),
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withAlpha(60),
            blurRadius: 20,
            spreadRadius: -6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(label, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white,
              )),
            ),
          ),
        ),
      ),
    );
  }
}