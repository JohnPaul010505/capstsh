import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  int? sessionElapsedSeconds;

  SessionExercise({
    required this.name,
    required this.category,
    required this.met,
  });

  bool get hasProof => proofUrl != null;
  bool get isDone => doneAt != null;

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'met': met,
    'startedAt': startedAt?.toIso8601String(),
    'proofRecordedAt': proofRecordedAt?.toIso8601String(),
    'proofUrl': proofUrl,
    'doneAt': doneAt?.toIso8601String(),
    'sessionElapsedSeconds': sessionElapsedSeconds,
  };

  factory SessionExercise.fromJson(Map<String, dynamic> json) {
    final exercise = SessionExercise(
      name: json['name'] as String,
      category: json['category'] as String,
      met: (json['met'] as num).toDouble(),
    );
    exercise.startedAt = json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null;
    exercise.proofRecordedAt = json['proofRecordedAt'] != null ? DateTime.parse(json['proofRecordedAt'] as String) : null;
    exercise.proofUrl = json['proofUrl'] as String?;
    exercise.doneAt = json['doneAt'] != null ? DateTime.parse(json['doneAt'] as String) : null;
    exercise.sessionElapsedSeconds = json['sessionElapsedSeconds'] as int?;
    return exercise;
  }
}

class CompletedSession {
  final String workoutName;
  final List<String> exerciseNames;
  final List<String> exerciseCategories;
  final List<int> exerciseCalories;
  final List<String?> exerciseProofUrls;
  final int totalCalories;
  final int elapsedSeconds;
  final DateTime completedAt;

  const CompletedSession({
    required this.workoutName,
    required this.exerciseNames,
    this.exerciseCategories = const <String>[],
    this.exerciseCalories = const <int>[],
    this.exerciseProofUrls = const <String?>[],
    required this.totalCalories,
    required this.elapsedSeconds,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'workoutName': workoutName,
    'exerciseNames': exerciseNames,
    'exerciseCategories': exerciseCategories,
    'exerciseCalories': exerciseCalories,
    'exerciseProofUrls': exerciseProofUrls,
    'totalCalories': totalCalories,
    'elapsedSeconds': elapsedSeconds,
    'completedAt': completedAt.toIso8601String(),
  };

  factory CompletedSession.fromJson(Map<String, dynamic> json) {
    return CompletedSession(
      workoutName: json['workoutName'] as String,
      exerciseNames: List<String>.from(json['exerciseNames'] as List),
      exerciseCategories: List<String>.from(json['exerciseCategories'] as List? ?? const []),
      exerciseCalories: List<int>.from(json['exerciseCalories'] as List),
      exerciseProofUrls: List<String?>.from(json['exerciseProofUrls'] as List),
      totalCalories: json['totalCalories'] as int,
      elapsedSeconds: json['elapsedSeconds'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }
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
  final int completedSessionCount;
  final List<CompletedSession> completedSessions;
  final bool showPreviousCards;
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
    this.completedSessionCount = 0,
    this.completedSessions = const [],
    this.showPreviousCards = false,
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

  Map<String, dynamic> toJson() => {
    'exercises': exercises.map((e) => e.toJson()).toList(),
    'isRunning': isRunning,
    'elapsedSeconds': elapsedSeconds,
    'startedAt': startedAt?.toIso8601String(),
    'lastInteractionAt': lastInteractionAt?.toIso8601String(),
    'idleWarning': idleWarning,
    'idleWarningSeconds': idleWarningSeconds,
    'sessionEnded': sessionEnded,
    'weightKg': weightKg,
    'latestCalories': latestCalories,
    'sessionCount': sessionCount,
    'completedSessionCount': completedSessionCount,
    'completedSessions': completedSessions.map((s) => s.toJson()).toList(),
    'showPreviousCards': showPreviousCards,
    'lastPersistSuccess': lastPersistSuccess,
  };

  factory WorkoutSessionState.fromJson(Map<String, dynamic> json) {
    return WorkoutSessionState(
      exercises: (json['exercises'] as List?)?.map((e) => SessionExercise.fromJson(e as Map<String, dynamic>)).toList() ?? const [],
      isRunning: json['isRunning'] as bool? ?? false,
      elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      lastInteractionAt: json['lastInteractionAt'] != null ? DateTime.parse(json['lastInteractionAt'] as String) : null,
      idleWarning: json['idleWarning'] as bool? ?? false,
      idleWarningSeconds: json['idleWarningSeconds'] as int? ?? 0,
      sessionEnded: json['sessionEnded'] as bool? ?? false,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 70,
      latestCalories: json['latestCalories'] as int?,
      sessionCount: json['sessionCount'] as int? ?? 0,
      completedSessionCount: json['completedSessionCount'] as int? ?? 0,
      completedSessions: (json['completedSessions'] as List?)?.map((s) => CompletedSession.fromJson(s as Map<String, dynamic>)).toList() ?? const [],
      showPreviousCards: json['showPreviousCards'] as bool? ?? false,
      lastPersistSuccess: json['lastPersistSuccess'] as bool?,
    );
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
  SharedPreferences? _prefs;
  DateTime? _lastPersistAt;

  /// Member's weight in kg, fetched from the latest body_measurement.
  double _weightKg = 70;

  WorkoutSessionNotifier() : super(const WorkoutSessionState()) {
    _loadWeight();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final restored = await _tryRestoreState();
    if (!restored) {
      await _loadSessionHistory();
    }
  }

  Future<bool> _tryRestoreState() async {
    if (_prefs == null) return false;
    final raw = _prefs!.getString('workout_session_state');
    if (raw == null) return false;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final restored = WorkoutSessionState.fromJson(map);
      if (restored.sessionEnded &&
          restored.elapsedSeconds == 0 &&
          restored.latestCalories == 0 &&
          restored.exercises.isEmpty) {
        debugPrint('Discarding stale workout state (all zeros)');
        return false;
      }
      state = restored;
      return true;
    } catch (e) {
      debugPrint('Failed to restore workout state: $e');
      return false;
    }
  }

  Future<void> _persist() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      await _prefs!.setString('workout_session_state', jsonEncode(state.toJson()));
    } catch (e) {
      debugPrint('Failed to persist workout state: $e');
    }
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

  Future<void> _loadSessionHistory() async {
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
      final endOfDay = DateTime(now.year, now.month, now.day + 1).toUtc();

       final res = await client
           .from('workout_logs')
           .select('workout_name, exercise_name, total_calories, duration_seconds, logged_at')
           .eq('member_id', userId)
           .gte('logged_at', startOfDay.toIso8601String())
           .lt('logged_at', endOfDay.toIso8601String())
           .order('logged_at', ascending: true);

      final groups = <String, List<Map<String, dynamic>>>{};
      for (final row in res) {
        final name = row['workout_name'] as String? ?? 'Workout';
        groups.putIfAbsent(name, () => []).add(row);
      }

      final sessions = <CompletedSession>[];
      int maxSessionNum = 0;

      for (final entry in groups.entries) {
        final name = entry.key;
        final exercises = entry.value;
        final exerciseNames = exercises.map((e) => e['exercise_name'] as String? ?? '').toList();
        final exerciseCalories = List<int>.filled(exercises.length, 0);
        final exerciseProofUrls = List<String?>.filled(exercises.length, null);
        final totalCalories = exercises
            .map((e) => (e['total_calories'] as int?) ?? 0)
            .fold<int>(0, (sum, k) => sum + k);
        final elapsedSeconds = exercises
            .map((e) => (e['duration_seconds'] as int?) ?? 0)
            .fold<int>(0, (sum, k) => sum + k);

        sessions.add(CompletedSession(
          workoutName: name,
          exerciseNames: exerciseNames,
          exerciseCategories: exerciseNames.map((n) => getCategoryFor(n)).toList(),
          exerciseCalories: exerciseCalories,
          exerciseProofUrls: exerciseProofUrls,
          totalCalories: totalCalories,
          elapsedSeconds: elapsedSeconds,
          completedAt: DateTime.tryParse(exercises.last['logged_at'] as String? ?? '') ?? DateTime.now(),
        ));

        final match = RegExp(r'S(\d+)').firstMatch(name);
        if (match != null) {
          final num = int.tryParse(match.group(1) ?? '') ?? 0;
          if (num > maxSessionNum) maxSessionNum = num;
        }
      }

      if (sessions.isNotEmpty) {
        state = _copyWith(
          sessionCount: maxSessionNum,
          completedSessionCount: sessions.length,
          completedSessions: sessions,
          sessionEnded: true,
        );
      }
    } catch (e) {
      debugPrint('Failed to load session history: $e');
    }
  }

  Future<bool> persistSession() async {
    final client = SupabaseClientService().client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || state.exercises.isEmpty) return false;

    final service = WorkoutService();
    final workoutName = 'Workout S${state.sessionCount + 1}';
    final totalCalories = state.exercises
        .map((e) => _caloriesFor(e))
        .fold<double>(0, (sum, c) => sum + c)
        .round();
    try {
      for (final e in state.exercises) {
        if (e.doneAt == null) continue;
        final log = WorkoutLog(
          id: '',
          memberId: userId,
          exerciseName: e.name,
          workoutName: workoutName,
          durationMinutes: e.doneAt!.difference(e.startedAt ?? state.startedAt ?? e.doneAt!).inMinutes,
          durationSeconds: e.doneAt!.difference(e.startedAt ?? state.startedAt ?? e.doneAt!).inSeconds,
          weightKg: _weightKg,
          proofUrl: e.proofUrl,
          proofType: e.hasProof ? 'video' : null,
          loggedAt: e.doneAt!.toUtc(),
          totalCalories: totalCalories,
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
      sessionCount: state.sessionCount,
      completedSessionCount: state.completedSessionCount,
      completedSessions: state.completedSessions,
      showPreviousCards: state.showPreviousCards,
    );
    _persist();
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
      sessionCount: state.sessionCount,
      completedSessionCount: state.completedSessionCount,
      completedSessions: state.completedSessions,
      showPreviousCards: state.showPreviousCards,
    );
    _persist();
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
      sessionCount: state.sessionCount,
      completedSessionCount: state.completedSessionCount,
      completedSessions: state.completedSessions,
      showPreviousCards: state.showPreviousCards,
    );
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
InteractionMonitor.instance.ensureStarted();
   }

    void startNewSession() {
      if (state.sessionCount >= 3) return;
      _ticker?.cancel();
      _ticker = null;
      _idleGraceTimer?.cancel();
      _idleGraceTimer = null;
      _lastTick = null;
      state = WorkoutSessionState(
        exercises: const [],
        isRunning: false,
        elapsedSeconds: 0,
        startedAt: null,
        lastInteractionAt: _stampInteraction(),
        idleWarning: false,
        idleWarningSeconds: 0,
        sessionEnded: false,
        weightKg: _weightKg,
        latestCalories: 0,
        sessionCount: state.sessionCount + 1,
        completedSessionCount: state.completedSessionCount,
        completedSessions: state.completedSessions,
      showPreviousCards: false,
      lastPersistSuccess: null,
    );
    _persist();
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
    final completed = CompletedSession(
      workoutName: 'Workout S${state.sessionCount + 1}',
      exerciseNames: state.exercises.map((e) => e.name).toList(),
      exerciseCategories: state.exercises.map((e) => e.category).toList(),
      exerciseCalories: state.exercises.map((e) => _caloriesFor(e).round()).toList(),
      exerciseProofUrls: state.exercises.map((e) => e.proofUrl).toList(),
      totalCalories: totalCalories,
      elapsedSeconds: state.elapsedSeconds,
      completedAt: DateTime.now(),
    );
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
      completedSessionCount: state.completedSessionCount + 1,
      completedSessions: [...state.completedSessions, completed],
      showPreviousCards: state.showPreviousCards,
    );
    _persist();
    persistSession().then((ok) {
      state = _copyWith(lastPersistSuccess: ok);
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
    final now2 = DateTime.now();
    if (_lastPersistAt == null || now2.difference(_lastPersistAt!).inSeconds >= 10) {
      _lastPersistAt = now2;
      _persist();
    }
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
      _persist();
    });
  }

  /// Continue after idle: resume the session, excluding the idle window.
  void continueFromIdle() {
    if (!state.idleWarning) return;
    _idleGraceTimer?.cancel();
    _idleGraceTimer = null;
    _lastTick = DateTime.now();
    state = _copyWith(idleWarning: false, idleWarningSeconds: 0);
    _persist();
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
    persistSession().then((_) {});
    state = WorkoutSessionState(
      sessionCount: state.sessionCount + 1,
      completedSessionCount: state.completedSessionCount,
      completedSessions: state.completedSessions,
      showPreviousCards: state.showPreviousCards,
    );
    _persist();
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
    int? completedSessionCount,
    List<CompletedSession>? completedSessions,
    bool? showPreviousCards,
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
      completedSessionCount: completedSessionCount ?? state.completedSessionCount,
      completedSessions: completedSessions ?? state.completedSessions,
      showPreviousCards: showPreviousCards ?? state.showPreviousCards,
      lastPersistSuccess: lastPersistSuccess ?? state.lastPersistSuccess,
    );
  }

  void _bump() {
    state = _copyWith(lastInteractionAt: _stampInteraction());
    _persist();
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
