import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_session_provider.dart';
import '../../calendar/widgets/calendar_flip_sheet.dart';
import '../../calendar/providers/month_entries_provider.dart';
import '../../home/pages/home_page.dart';
import '../workout_constants.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/proof_video_viewer.dart';
import '../widgets/workout_header.dart';
import '../widgets/workout_clock_card.dart';
import '../widgets/workout_add_form.dart';
import '../widgets/workout_exercise_list.dart';
import '../widgets/workout_idle_overlay.dart';
import '../widgets/workout_summary.dart';

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
    super.dispose();
  }

  void _showPreviousCards() {
    if (!_showPrevCards) {
      setState(() {
        _showPrevCards = true;
        final session = ref.read(workoutSessionProvider);
        if (session.completedSessionCount >= WorkoutConstants.minSessionsPerDay) {
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

  void _invalidateProviders() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    ref.invalidate(monthEntriesProvider((userId, monthStart)));
    ref.invalidate(homeDataProvider);
  }

  void _showMinSessionsWarning() {
    final session = ref.read(workoutSessionProvider);
    final remaining = WorkoutConstants.minSessionsPerDay - session.sessionCount;
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
      // Reactive invalidation: when a session completes and persists successfully,
      // refresh home and calendar data.
      if (prev?.sessionEnded == false && next.sessionEnded == true && next.lastPersistSuccess == true) {
        _invalidateProviders();
      }
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (session.sessionCount < WorkoutConstants.minSessionsPerDay) {
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
                    WorkoutHeader(
                      session: session,
                      onDateTap: () => showCalendarFlipSheet(
                        context,
                        selected: DateTime.now(),
                        today: DateTime.now(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    WorkoutClockCard(session: session, notifier: notifier),
                    const SizedBox(height: 8),
                    if (ended) ...[
                      if (_showPrevCards && session.completedSessions.length > 1) ...[
                        _PreviousSessionCards(
                          session: session,
                          showCompletionMessage: _showCompletionMessage,
                          onViewProof: (s) {
                            final url = s.exerciseProofUrls.firstWhere(
                              (u) => u != null && u.isNotEmpty,
                              orElse: () => '',
                            );
                            if (url != null && url.isNotEmpty) {
                              showProofVideoDialog(context, url);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      WorkoutSummary(
                        session: session,
                        notifier: notifier,
                        showPrevCards: _showPrevCards,
                        onShowPrevCards: _showPreviousCards,
                        onInvalidateProviders: _invalidateProviders,
                      ),
                    ]
                    else ...[
                      if (!isRunning) ...[
                        WorkoutAddForm(notifier: notifier),
                        const SizedBox(height: 8),
                      ],
                      WorkoutExerciseList(session: session, notifier: notifier),
                    ],
                    const SizedBox(height: 96),
                  ],
                ),
                if (session.idleWarning)
                  WorkoutIdleOverlay(session: session, notifier: notifier),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviousSessionCards extends StatelessWidget {
  final WorkoutSessionState session;
  final bool showCompletionMessage;
  final Function(CompletedSession) onViewProof;

  const _PreviousSessionCards({
    required this.session,
    required this.showCompletionMessage,
    required this.onViewProof,
  });

  @override
  Widget build(BuildContext context) {
    final previous = session.completedSessions.length > 1
        ? session.completedSessions.sublist(0, session.completedSessions.length - 1)
        : <CompletedSession>[];
    final widgets = <Widget>[];
    if (showCompletionMessage) {
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
                              onTap: () => onViewProof(s),
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
    return Column(children: widgets);
  }

  String _format(int seconds) {
    final m = seconds ~/ 60;
    final sec = seconds % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
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