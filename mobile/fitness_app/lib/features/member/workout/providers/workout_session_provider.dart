import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/workout_service.dart';
import 'package:shared/models/workout_log.dart';
import '../../../shared/services/interaction_monitor.dart';
import '../data/met_exercise_catalog.dart';

/// A single exercise added to the current session. Everything lives in memory
/// (Phase 2 is client-side only) — nothing is persisted to `workout_logs`.
class SessionExercise {
  final String name;
  final String category;
  final double met;
  DateTime? startedAt;
  DateTime? proofRecordedAt;
  String? proofUrl;
  DateTime? doneAt;

  SessionExercise({
    required this.name,
    required this.category,
    required this.met,
  });

  bool get hasProof => proofUrl != null;
  bool get isDone => doneAt != null;
}

class WorkoutSessionState {
  final List<SessionExercise> exercises;
  final bool isRunning;
  final int elapsedSeconds;
  final DateTime? startedAt;
  final DateTime? lastInteractionAt;
  final bool idleWarning;
  final int idleWarningSeconds;
  final bool sessionEnded;
  final double weightKg;
  final int? _latestCalories;
  final int sessionCount;
  final bool? lastPersistSuccess;

  const WorkoutSessionState({
    this.exercises = const [],
    this.isRunning = false,
    this.elapsedSeconds = 0,
    this.startedAt,
    this.lastInteractionAt,
    this.idleWarning = false,
    this.idleWarningSeconds = 0,
    this.sessionEnded = false,
    this.weightKg = 70,
    int? latestCalories,
    this.sessionCount = 0,
    this.lastPersistSuccess,
  // ignore: prefer_initializing_formals
  }) : _latestCalories = latestCalories;

  /// Total active session time, minus idle windows (tracked by the notifier).
  int get activeSeconds => elapsedSeconds;

  /// Calories from the last session summary (0 before a session completes).
  int get latestCalories => _latestCalories ?? 0;

  /// Calories for an individual exercise given the member's weight in kg.
  double caloriesFor(SessionExercise exercise, double weightKg) {
    final end = exercise.doneAt ?? DateTime.now();
    final start = exercise.startedAt ?? startedAt;
    final seconds = start == null ? 0 : end.difference(start).inSeconds;
    final hours = seconds / 3600.0;
    return exercise.met * weightKg * hours;
  }
}

/// Idle-detection constants for a workout session.
class SessionConfig {
  SessionConfig._();

  /// No interaction for this long before the session freezes.
  static const idleThreshold = Duration(minutes: 30);

  /// Countdown before an idle session is auto-restarted.
  static const idleGracePeriod = Duration(seconds: 10);
}

class WorkoutSessionNotifier extends StateNotifier<WorkoutSessionState> {
  Timer? _ticker;
  Timer? _idleGraceTimer;
  DateTime? _lastTick;

  /// Member's weight in kg, fetched from the latest body_measurement.
  double _weightKg = 70;

  WorkoutSessionNotifier() : super(const WorkoutSessionState()) {
    _loadWeight();
  }

  List<SessionExercise> get exercises => state.exercises;

  double get weightKg => _weightKg;

  double _caloriesFor(SessionExercise exercise) {
    final end = exercise.doneAt ?? DateTime.now();
    final start = exercise.startedAt;
    final seconds = start == null ? 0 : end.difference(start).inSeconds;
    final hours = seconds / 3600.0;
    return exercise.met * _weightKg * hours;
  }

  Future<void> _loadWeight() async {
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final res = await client
          .from('body_measurements')
          .select('weight_kg')
          .eq('member_id', userId)
          .order('measured_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final w = (res?['weight_kg'] as num?)?.toDouble();
      if (w != null && w > 0) {
        _weightKg = w;
        state = _copyWith(weightKg: w);
      }
    } catch (_) {
      // Keep the 70 kg default if the measurement can't be loaded.
    }
  }

  Future<bool> persistSession() async {
    final client = SupabaseClientService().client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || state.exercises.isEmpty) return false;

    final service = WorkoutService();
    try {
      for (final e in state.exercises) {
        if (e.doneAt == null) continue;
        final log = WorkoutLog(
          id: '',
          memberId: userId,
          exerciseName: e.name,
          durationMinutes: e.doneAt!.difference(e.startedAt ?? state.startedAt ?? e.doneAt!).inMinutes,
          weightKg: _weightKg,
          proofUrl: e.proofUrl,
          proofType: e.hasProof ? 'video' : null,
          loggedAt: e.doneAt!.toUtc(),
        );
        await service.createWorkout(log);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adds a catalog-matched exercise to the current session.
  void addExercise(String name) {
    final category = metExerciseCatalog.entries
        .firstWhere((c) => c.value.any((e) => e.name == name),
            orElse: () => const MapEntry('', []))
        .key;
    if (category.isEmpty) return;
    final met = getMetValue(name);
    state = WorkoutSessionState(
      exercises: [...state.exercises, SessionExercise(name: name, category: category, met: met)],
      isRunning: state.isRunning,
      elapsedSeconds: state.elapsedSeconds,
      startedAt: state.startedAt,
      lastInteractionAt: _stampInteraction(),
      idleWarningSeconds: state.idleWarningSeconds,
      sessionEnded: state.sessionEnded,
      weightKg: _weightKg,
      latestCalories: state.latestCalories,
    );
  }

  void removeExercise(int index) {
    if (state.isRunning || state.sessionEnded) return;
    final list = [...state.exercises]..removeAt(index);
    state = WorkoutSessionState(
      exercises: list,
      isRunning: false,
      elapsedSeconds: 0,
      lastInteractionAt: _stampInteraction(),
      sessionEnded: false,
      weightKg: _weightKg,
    );
  }

  void startSession() {
    if (state.exercises.isEmpty || state.isRunning || state.sessionEnded) return;
    _lastTick = DateTime.now();
    final started = DateTime.now();
    state.exercises.first.startedAt ??= started;
    state = WorkoutSessionState(
      exercises: state.exercises,
      isRunning: true,
      elapsedSeconds: 0,
      startedAt: started,
      lastInteractionAt: _stampInteraction(),
      sessionEnded: false,
      weightKg: _weightKg,
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    InteractionMonitor.instance.ensureStarted();
  }

  /// Records that the current exercise has a saved proof video.
  void markProofRecorded(int index, String url) {
    if (index < 0 || index >= state.exercises.length) return;
    final e = state.exercises[index];
    e.proofUrl = url;
    e.proofRecordedAt = DateTime.now();
    _bump();
  }

  /// Removes the proof video for the exercise at [index].
  void removeProof(int index) {
    if (index < 0 || index >= state.exercises.length) return;
    final e = state.exercises[index];
    e.proofUrl = null;
    e.proofRecordedAt = null;
    _bump();
  }

  /// Marks the exercise at [index] as Done with a manual timestamp.
  void markDone(int index) {
    if (index < 0 || index >= state.exercises.length) return;
    final e = state.exercises[index];
    if (!e.hasProof) return;
    e.doneAt = DateTime.now();
    final next = index + 1;
    if (next < state.exercises.length) {
      state.exercises[next].startedAt ??= e.doneAt;
    } else {
      _finishSession();
    }
    _bump();
  }

  void _finishSession() {
    _ticker?.cancel();
    _ticker = null;
    _idleGraceTimer?.cancel();
    _idleGraceTimer = null;
    final totalCalories = state.exercises
        .map((e) => _caloriesFor(e))
        .fold<double>(0, (sum, c) => sum + c)
        .round();
    state = WorkoutSessionState(
      exercises: state.exercises,
      isRunning: false,
      elapsedSeconds: state.elapsedSeconds,
      startedAt: state.startedAt,
      lastInteractionAt: state.lastInteractionAt,
      idleWarning: false,
      idleWarningSeconds: 0,
      sessionEnded: true,
      weightKg: _weightKg,
      latestCalories: totalCalories,
      sessionCount: state.sessionCount,
    );
    // Auto-persist in background — fire and forget.
    persistSession().then((ok) {
      state = WorkoutSessionState(
        exercises: state.exercises,
        isRunning: false,
        elapsedSeconds: state.elapsedSeconds,
        startedAt: state.startedAt,
        lastInteractionAt: state.lastInteractionAt,
        idleWarning: false,
        idleWarningSeconds: 0,
        sessionEnded: true,
        weightKg: _weightKg,
        latestCalories: totalCalories,
        sessionCount: state.sessionCount,
        lastPersistSuccess: ok,
      );
    });
  }

  void _tick() {
    final now = DateTime.now();
    final lastInteraction = InteractionMonitor.instance.lastInteractionAt.value;
    final idleFor = now.difference(lastInteraction);

    // Start idle warning once the threshold is crossed.
    if (!state.idleWarning && idleFor >= SessionConfig.idleThreshold) {
      _startIdleGrace();
      state = _copyWith(idleWarning: true, idleWarningSeconds: SessionConfig.idleGracePeriod.inSeconds);
      return;
    }

    if (state.idleWarning) return;

    // Advance the clock only for active time (idle windows excluded).
    final base = _lastTick ?? state.startedAt ?? now;
    final delta = now.difference(base).inSeconds;
    _lastTick = now;
    state = _copyWith(
      elapsedSeconds: state.elapsedSeconds + delta,
      lastInteractionAt: lastInteraction,
    );
  }

  void _startIdleGrace() {
    _idleGraceTimer?.cancel();
    var secondsLeft = SessionConfig.idleGracePeriod.inSeconds;
    _idleGraceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        timer.cancel();
        _forceRestart();
        return;
      }
      state = _copyWith(idleWarningSeconds: secondsLeft);
    });
  }

  /// Continue after idle: resume the session, excluding the idle window.
  void continueFromIdle() {
    if (!state.idleWarning) return;
    _idleGraceTimer?.cancel();
    _idleGraceTimer = null;
    _lastTick = DateTime.now();
    state = _copyWith(idleWarning: false, idleWarningSeconds: 0);
  }

  /// Confirm restart: wipe the whole session.
  void restartSession() {
    if (state.idleWarning) {
      _forceRestart();
      return;
    }
    _forceRestart();
  }

  void _forceRestart() {
    _ticker?.cancel();
    _ticker = null;
    _idleGraceTimer?.cancel();
    _idleGraceTimer = null;
    // Auto-persist any completed exercises before wiping state.
    persistSession().then((_) {});
    state = WorkoutSessionState(sessionCount: state.sessionCount + 1);
  }

  WorkoutSessionState _copyWith({
    int? elapsedSeconds,
    bool? isRunning,
    bool? idleWarning,
    int? idleWarningSeconds,
    DateTime? lastInteractionAt,
    bool? sessionEnded,
    double? weightKg,
    int? latestCalories,
    int? sessionCount,
    bool? lastPersistSuccess,
  }) {
    return WorkoutSessionState(
      exercises: state.exercises,
      isRunning: isRunning ?? state.isRunning,
      elapsedSeconds: elapsedSeconds ?? state.elapsedSeconds,
      startedAt: state.startedAt,
      lastInteractionAt: lastInteractionAt ?? state.lastInteractionAt,
      idleWarning: idleWarning ?? state.idleWarning,
      idleWarningSeconds: idleWarningSeconds ?? state.idleWarningSeconds,
      sessionEnded: sessionEnded ?? state.sessionEnded,
      weightKg: weightKg ?? state.weightKg,
      latestCalories: latestCalories ?? state.latestCalories,
      sessionCount: sessionCount ?? state.sessionCount,
      lastPersistSuccess: lastPersistSuccess ?? state.lastPersistSuccess,
    );
  }

  void _bump() {
    state = _copyWith(lastInteractionAt: _stampInteraction());
  }

  DateTime _stampInteraction() => InteractionMonitor.instance.lastInteractionAt.value = DateTime.now();

  @override
  void dispose() {
    _ticker?.cancel();
    _idleGraceTimer?.cancel();
    super.dispose();
  }
}

// App-lifetime provider: the session clock and exercise list must keep running
// when the user leaves the workout tab (go_router disposes the page). An
// autoDispose provider would cancel the clock and wipe the exercise list.
final workoutSessionProvider =
    StateNotifierProvider<WorkoutSessionNotifier, WorkoutSessionState>(
  (_) => WorkoutSessionNotifier(),
);
