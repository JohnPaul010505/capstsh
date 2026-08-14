import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/workout_session_provider.dart';
import '../widgets/exercise_proof_button.dart';
import '../data/met_exercise_catalog.dart';
import '../../calendar/widgets/calendar_flip_sheet.dart';
import '../../calendar/providers/month_entries_provider.dart';
import '../../home/pages/home_page.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/proof_video_viewer.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';

/// Workout session flow (client-side, in-memory — nothing persisted yet):
///  1. Add exercises via the catalog autocomplete (must match one of the 140).
///  2. Start Session → continuous clock.
///  3. Per exercise: record video proof (Ready? → 3s countdown → 30s auto),
///     then tap Done to timestamp it.
///  4. Idle 30 min → frozen clock + "Are you still there?" 10s countdown.
///  5. All done → summary with durations + MET calories.
class WorkoutPage extends ConsumerStatefulWidget {
  const WorkoutPage({super.key});

  @override
  ConsumerState<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends ConsumerState<WorkoutPage> with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  String _query = '';
  bool _showPrevCards = false;
  bool _showCompletionMessage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  void _showPreviousCards() {
    if (!_showPrevCards) {
      setState(() {
        _showPrevCards = true;
        final session = ref.read(workoutSessionProvider);
        if (session.completedSessionCount >= 3) {
          _showCompletionMessage = true;
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App going to background — persist any in-progress exercises.
      ref.read(workoutSessionProvider.notifier).persistSession().then((_) {});
    }
  }

  List<MetExercise> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final result = <MetExercise>[];
    for (final category in metExerciseCatalog.values) {
      for (final e in category) {
        if (e.name.toLowerCase().startsWith(q)) result.add(e);
      }
    }
    return result.take(6).toList();
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    final s = end.difference(start).inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }

  void _invalidateProviders() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    ref.invalidate(monthEntriesProvider(monthStart));
    ref.invalidate(homeDataProvider);
  }

  void _showMinSessionsWarning() {
    final session = ref.read(workoutSessionProvider);
    final remaining = 3 - session.sessionCount;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClayTokens.clayDarkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Minimum 3 Sessions Required',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7)),
        ),
        content: Text(
          'You\'ve completed ${session.sessionCount} session${session.sessionCount == 1 ? '' : 's'} today. '
          'You need $remaining more session${remaining == 1 ? '' : 's'} to meet the daily minimum.',
          style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Continue Working Out', style: TextStyle(color: Color(0xFFD6A5FF))),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Leave Anyway', style: TextStyle(color: Color(0xFF636366))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionProvider);
    final notifier = ref.read(workoutSessionProvider.notifier);
    final isRunning = session.isRunning;
    final ended = session.sessionEnded;

    // Listen for persist results and show error snackbar.
    ref.listen(workoutSessionProvider, (prev, next) {
      if (next.lastPersistSuccess == false && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save workout. Please check your connection.'),
            backgroundColor: Color(0xFFFF453A),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (session.sessionCount < 3) {
          _showMinSessionsWarning();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: ClayTokens.clayDarkBase,
        body: AppGlowBackground(
          child: SafeArea(
            child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                physics: const ClampingScrollPhysics(),
                children: [
                  const SizedBox(height: 14),
                  _buildHeader(session),
                  const SizedBox(height: 8),
                  _buildClockCard(session, notifier),
                  const SizedBox(height: 8),
                  if (ended) ...[
                    if (_showPrevCards && session.completedSessions.length > 1) ...[
                      ..._buildPreviousSessionCards(session),
                      const SizedBox(height: 16),
                    ],
                    _buildSummary(session, notifier),
                  ]
                  else ...[
                    if (!isRunning) ...[
                      _buildAddForm(notifier),
                      const SizedBox(height: 8),
                    ],
                    _buildExerciseList(session, notifier),
                  ],
                  const SizedBox(height: 96),
                ],
              ),
              if (session.idleWarning) _buildIdleOverlay(session, notifier),
            ],
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildHeader(WorkoutSessionState session) {
    final isRunning = session.isRunning;
    final liveColor = isRunning ? const Color(0xFF30D158) : const Color(0xFF636366);
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'WORKOUT LOG',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: liveColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: liveColor.withAlpha(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedPulseDot(
                color: isRunning ? const Color(0xFF30D158) : const Color(0xFF8E8E93),
                size: 6,
              ),
              const SizedBox(width: 5),
              Text(
                isRunning ? 'Live' : session.sessionEnded ? 'Done' : 'Ready',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: liveColor),
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => showCalendarFlipSheet(
                context,
                selected: DateTime.now(),
                today: DateTime.now(),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  DateFormat('MMM d').format(DateTime.now()),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClockCard(WorkoutSessionState session, WorkoutSessionNotifier notifier) {
    final isRunning = session.isRunning;
    final canStart = !isRunning && !session.sessionEnded && session.exercises.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedPulseDot(
                color: isRunning ? const Color(0xFF64D2FF) : const Color(0xFF8E8E93),
                size: 6,
              ),
              const SizedBox(width: 6),
              Text(
                isRunning ? 'SESSION ACTIVE' : 'SESSION DURATION',
                style: TextStyle(
                  fontSize: 10,
                  color: isRunning ? const Color(0xFF64D2FF) : const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _format(session.elapsedSeconds),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: isRunning ? const Color(0xFF64D2FF) : const Color(0xFFFFFFFF),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isRunning
                ? 'Record proof then tap Done for each exercise'
                : session.exercises.isNotEmpty
                    ? 'Ready to start — ${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'}'
                    : 'Add an exercise to begin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isRunning ? const Color(0xFF64D2FF).withAlpha(150) : const Color(0xFF8E8E93),
            ),
          ),
          if (canStart) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC56BF0).withAlpha(60),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () => notifier.startSession(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  'Start Session',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Add form (autocomplete) ----------------

  Widget _buildAddForm(WorkoutSessionNotifier notifier) {
    final matches = _matches;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ADD EXERCISE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF8E8E93),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search 140 exercises…',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF7070A0), size: 18),
              filled: true,
              fillColor: ClayTokens.clayDarkSurfaceElevated,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFA78BFA)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
          ),
          if (_query.isNotEmpty && matches.isEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'No catalog match — pick one of the suggestions below.',
              style: TextStyle(fontSize: 11, color: Color(0xFFFF6B61)),
            ),
          ],
          if (matches.isNotEmpty) ...[
            const SizedBox(height: 8),
            Column(
              children: matches.map((e) {
                return PressableCard(
                  onTap: () {
                    notifier.addExercise(e.name);
                    _searchController.clear();
                    setState(() => _query = '');
                    FocusScope.of(context).unfocus();
                  },
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 6),
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBF5AF2).withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Color(0xFFD6A5FF), size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                            ),
                            Text(
                              '${e.category} · MET ${e.met}',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------- Exercise list ----------------

  Widget _buildExerciseList(WorkoutSessionState session, WorkoutSessionNotifier notifier) {
    if (session.exercises.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No exercises yet — search above to add one',
            style: TextStyle(color: Color(0xFF636366), fontSize: 12),
          ),
        ),
      );
    }

    final currentIndex = session.exercises.indexWhere((e) => !e.isDone);

    return Column(
      children: [
        ...session.exercises.asMap().entries.map(
          (entry) {
            final i = entry.key;
            final e = entry.value;
            final isCurrent = i == currentIndex;
            final isDone = e.isDone;
            return StaggeredFadeIn(
              index: i,
              child: _ExerciseCard(
                exercise: e,
                index: i,
                isCurrent: isCurrent,
                isDone: isDone,
                isRunning: session.isRunning,
                sessionStartedAt: session.startedAt,
                weightKg: session.weightKg,
                canStartProof: session.isRunning && isCurrent,
                onProofRecorded: (url) => notifier.markProofRecorded(i, url),
                onProofRemoved: () => notifier.removeProof(i),
                onDone: () => notifier.markDone(i),
                onRemove: () => notifier.removeExercise(i),
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------- Summary ----------------

  Widget _buildSummary(WorkoutSessionState session, WorkoutSessionNotifier notifier) {
    return StaggeredFadeIn(
      index: 99,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A45)),
          gradient: RadialGradient(
            center: const Alignment(0.9, -0.9),
            radius: 1.2,
            colors: [
              const Color(0xFF7C3AED).withAlpha(60),
              const Color(0xFF1C1C2E),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Workout Complete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SESSION DONE',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: ClayTokens.clayAccentLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (session.sessionCount <= 2)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations for Completing Workout',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 3),
            const Text(
              "Great job! Here's your session summary.",
              style: TextStyle(fontSize: 10, color: Color(0xFFB4B4D0)),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFF2A2A45)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD6A5FF)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Session Duration', style: TextStyle(
                        fontSize: 10, color: Color(0xFF8E8E93),
                      )),
                      Text(
                        _format(session.elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Calories', style: TextStyle(
                        fontSize: 10, color: Color(0xFF8E8E93),
                      )),
                      Text(
                        '${session.latestCalories} kcal',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFFF9F0A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...session.exercises.map((e) {
              final name = e.name;
              final duration = _formatDuration(e.startedAt, e.doneAt);
              final hasVideo = e.hasProof;
              final kcal = session.caloriesFor(e, session.weightKg);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasVideo
                                  ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)])
                                  : null,
                              color: hasVideo ? null : const Color(0xFF3A3A4A),
                            ),
                            child: Icon(
                              hasVideo ? Icons.check : Icons.close,
                              size: 12,
                              color: hasVideo ? Colors.white : const Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(name, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7),
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _summaryStat(icon: Icons.timer_outlined, value: duration, color: const Color(0xFFD6A5FF)),
                          const SizedBox(width: 12),
                          _summaryStat(icon: Icons.local_fire_department_outlined, value: '${kcal.round()} kcal', color: const Color(0xFFFF9F0A)),
                          const Spacer(),
                          if (hasVideo)
                            GestureDetector(
                              onTap: () => showProofVideoDialog(context, e.proofUrl!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7C3AED).withAlpha(50),
                                      const Color(0xFFC56BF0).withAlpha(30),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(100)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_circle_outline, size: 12, color: Color(0xFFD6A5FF)),
                                    SizedBox(width: 3),
                                    Text('View', style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFD6A5FF),
                                    )),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('No proof', style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFFF6B61),
                              )),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            if (session.completedSessions.length > 1 && !_showPrevCards)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: _showPreviousCards,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    session.completedSessions.length >= 3 ? 'View All Sessions' : 'View Workout S1',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            if (session.completedSessions.length > 1 && session.completedSessionCount < 3 && !_showPrevCards)
              const SizedBox(height: 8),
            if (session.completedSessionCount < 3)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                  child: TextButton(
                    onPressed: () {
                      _invalidateProviders();
                      notifier.restartSession();
                      setState(() {
                        _query = '';
                        _showPrevCards = false;
                      });
                    },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'New Session',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- Idle overlay ----------------

  Widget _buildIdleOverlay(WorkoutSessionState session, WorkoutSessionNotifier notifier) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(200),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2A45)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: ClayTokens.clayWarning.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.schedule, color: Color(0xFFFF9F0A), size: 26),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Are you still there?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No activity for 30 minutes. The session will restart in ${session.idleWarningSeconds}s.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB4B4D0)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PressableCard(
                          onTap: () => notifier.restartSession(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(12),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayError.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ClayTokens.clayError.withAlpha(100)),
                          ),
                          child: const Text(
                            'Restart',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF6B61)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PressableCard(
                          onTap: () => notifier.continueFromIdle(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(12),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayAccent.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ClayTokens.clayAccent.withAlpha(100)),
                          ),
                          child: const Text(
                            'Continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6EE7B7)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCongratsBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC56BF0).withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPreviousSessionCards(WorkoutSessionState session) {
    final previous = session.completedSessions.length > 1
        ? session.completedSessions.sublist(0, session.completedSessions.length - 1)
        : <CompletedSession>[];
    final widgets = <Widget>[];
    if (_showCompletionMessage) {
      widgets.add(_buildCongratsBanner('Congratulations for Completing all the Workouts'));
    }
    widgets.addAll(previous.map((s) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A45)),
          gradient: RadialGradient(
            center: Alignment(0.9, -0.9),
            radius: 1.2,
            colors: [
              Color(0xFF7C3AED).withAlpha(60),
              Color(0xFF1C1C2E),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Workout Complete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    s.workoutName,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: ClayTokens.clayAccentLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            const Text(
              'Great job! Here\'s your session summary.',
              style: TextStyle(fontSize: 10, color: Color(0xFFB4B4D0)),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFF2A2A45)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD6A5FF)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Session Duration', style: TextStyle(
                        fontSize: 10, color: Color(0xFF8E8E93),
                      )),
                      Text(
                        _format(s.elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Calories', style: TextStyle(
                        fontSize: 10, color: Color(0xFF8E8E93),
                      )),
                      Text(
                        '${s.totalCalories} kcal',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFFF9F0A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
             ...List.generate(s.exerciseNames.length, (i) {
               final name = s.exerciseNames[i];
               final kcal = i < s.exerciseCalories.length ? s.exerciseCalories[i] : null;
               final proofUrl = i < s.exerciseProofUrls.length ? s.exerciseProofUrls[i] : null;
               final hasVideo = proofUrl != null;
               return Padding(
                 padding: const EdgeInsets.only(bottom: 8),
                 child: Container(
                   padding: const EdgeInsets.all(10),
                   decoration: BoxDecoration(
                     color: Colors.white.withAlpha(6),
                     borderRadius: BorderRadius.circular(12),
                     border: Border.all(color: Colors.white.withAlpha(10)),
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Row(
                         children: [
                           Container(
                             width: 20, height: 20,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               gradient: hasVideo
                                   ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)])
                                   : null,
                               color: hasVideo ? null : const Color(0xFF3A3A4A),
                             ),
                             child: Icon(
                               hasVideo ? Icons.check : Icons.close,
                               size: 12,
                               color: hasVideo ? Colors.white : const Color(0xFF8E8E93),
                             ),
                           ),
                           const SizedBox(width: 8),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(name, style: const TextStyle(
                                   fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7),
                                 )),
                                 if (i < s.exerciseCategories.length && s.exerciseCategories[i].isNotEmpty)
                                   Text(s.exerciseCategories[i], style: const TextStyle(
                                     fontSize: 10, color: Color(0xFF8E8E93),
                                   )),
                               ],
                             ),
                           ),
                         ],
                       ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _summaryStat(icon: Icons.local_fire_department_outlined, value: '${kcal ?? 0} kcal', color: const Color(0xFFFF9F0A)),
                          const Spacer(),
                          if (hasVideo)
                            GestureDetector(
                              onTap: () => showProofVideoDialog(context, proofUrl),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7C3AED).withAlpha(50),
                                      const Color(0xFFC56BF0).withAlpha(30),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(100)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_circle_outline, size: 12, color: Color(0xFFD6A5FF)),
                                    SizedBox(width: 3),
                                    Text('View', style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFD6A5FF),
                                    )),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }).toList());
    return widgets;
  }

  Widget _summaryStat({required IconData icon, required String value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: color,
        )),
      ],
    );
  }
}

// ---------------- Exercise card ----------------

class _ExerciseCard extends StatelessWidget {
  final SessionExercise exercise;
  final int index;
  final bool isCurrent;
  final bool isDone;
  final bool isRunning;
  final DateTime? sessionStartedAt;
  final double weightKg;
  final bool canStartProof;
  final ValueChanged<String> onProofRecorded;
  final VoidCallback onProofRemoved;
  final VoidCallback onDone;
  final VoidCallback onRemove;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.isCurrent,
    required this.isDone,
    required this.isRunning,
    required this.sessionStartedAt,
    required this.weightKg,
    required this.canStartProof,
    required this.onProofRecorded,
    required this.onProofRemoved,
    required this.onDone,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise.name;
    final hasVideo = exercise.hasProof;
    final duration = exercise.isDone
        ? _fmt(exercise.doneAt!.difference(exercise.startedAt ?? sessionStartedAt ?? exercise.doneAt!).inSeconds)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF1C1C2E) : ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? const Color(0xFFA78BFA).withAlpha(80) : const Color(0xFF2A2A45),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? ClayTokens.clayAccent.withAlpha(25)
                        : isCurrent
                            ? const Color(0xFFBF5AF2).withAlpha(25)
                            : const Color(0xFF636366).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDone ? Icons.check : isCurrent ? Icons.play_arrow : Icons.schedule,
                    color: isDone
                        ? ClayTokens.clayAccent
                        : isCurrent
                            ? const Color(0xFFD6A5FF)
                            : const Color(0xFF8E8E93),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                      ),
                      Text(
                        '${exercise.category} · MET ${exercise.met}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ),
                if (isDone) ...[
                  Text(
                    duration ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD6A5FF)),
                  ),
                ],
              ],
            ),
            if (canStartProof) ...[
              const SizedBox(height: 8),
              ExerciseProofTile(
                videoUrl: exercise.proofUrl,
                onRecorded: onProofRecorded,
                onRemoved: onProofRemoved,
                 onDone: onDone,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: hasVideo ? onDone : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    disabledForegroundColor: Colors.white.withAlpha(120),
                  ),
                  child: Text(
                    hasVideo ? 'Done — Timestamp Now' : 'Record proof to unlock Done',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else if (!isDone && !isRunning) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Remove',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFF6B61)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }
}
