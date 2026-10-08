import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../trainer/set_plan/data/plan_repository.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository();
});

final hasActivePlanProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null) return false;

  final repo = PlanRepository();
  return await repo.memberHasActivePlan(userId);
});

final activePlanProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null) return null;

  final repo = PlanRepository();
  return await repo.getPlanByMember(userId);
});

final planDaysProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, planId) async {
  final repo = PlanRepository();
  return await repo.getPlanDays(planId);
});

final memberCompletionsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final repo = PlanRepository();
  return await repo.getMemberCompletions(memberId);
});

final trainerPlanRecordsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null) return [];

  final repo = PlanRepository();
  return await repo.getTrainerPlanRecords(userId);
});

final planCompletionDaysProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, planId) async {
  final userId = SupabaseClientService().client.auth.currentUser?.id;
  if (userId == null) return [];

  final repo = PlanRepository();
  return await repo.getPlanCompletionDays(planId, userId);
});

class PlanOverlayController extends ChangeNotifier {
  bool isOpen = false;
  int currentDay = 1;
  String? selectedPlanId;
  final Set<String> _completedExercises = <String>{};

  bool get isExpanded => isOpen;

  void openForWorkout(String memberId, String startDate) {
    isOpen = true;
    currentDay = _dayNumberFrom(startDate);
    notifyListeners();
  }

  void openForFood(String memberId, String startDate) {
    isOpen = true;
    currentDay = _dayNumberFrom(startDate);
    notifyListeners();
  }

  int _dayNumberFrom(String startDate) {
    try {
      final start = DateTime.parse(startDate);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(start).inDays;
      return (diff + 1).clamp(1, 7);
    } on FormatException {
      return currentDay;
    }
  }

  void close() {
    isOpen = false;
    notifyListeners();
  }

  void nextDay() {
    if (currentDay < 7) {
      currentDay++;
      notifyListeners();
    }
  }

  void previousDay() {
    if (currentDay > 1) {
      currentDay--;
      notifyListeners();
    }
  }

  void setDay(int day) {
    currentDay = day;
    notifyListeners();
  }

  void toggleExercise(String name) {
    if (_completedExercises.contains(name)) {
      _completedExercises.remove(name);
    } else {
      _completedExercises.add(name);
    }
    notifyListeners();
  }

  bool isExerciseCompleted(String name) {
    return _completedExercises.contains(name);
  }

  Set<String> get completedExercises => Set.unmodifiable(_completedExercises);
}

final planOverlayControllerProvider = ChangeNotifierProvider<PlanOverlayController>((ref) {
  return PlanOverlayController();
});

/// Fraction-based position + size of the member's floating plan logo.
/// Stored as fractions of the **body box** (the area the page owns, i.e. the
/// screen minus the bottom nav bar) so rotation/resolution never breaks it.
/// `fraction == null` means "default spot" (bottom-right corner).
class FloatingLogoPosition extends ChangeNotifier {
  /// Kept clear of every screen edge so the logo is never half-clipped, and
  /// so a drag can always be grabbed again.
  static const double _margin = 12;

  Offset? _fraction;
  double _size = 52;
  bool _loaded = false;

  Offset? get fraction => _fraction;
  double get size => _size;

  Offset _dragStartPoint = Offset.zero;
  Offset _dragStartFraction = Offset.zero;
  double _dragStartSize = 52;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _size = (prefs.getDouble('plan_logo_size') ?? 52).clamp(44.0, 96.0);
      final x = prefs.getDouble('plan_logo_x');
      final y = prefs.getDouble('plan_logo_y');
      if (x != null && y != null) _fraction = Offset(x, y);
      notifyListeners();
    } catch (_) {
      // Defaults are fine when prefs are unavailable.
    }
  }

  Offset defaultFraction(Size bounds) => Offset(
        (bounds.width - _size - _margin) / bounds.width,
        (bounds.height - _size - _margin) / bounds.height,
      );

  /// Largest legal fraction on each axis for [bounds]. Dividing by the axis
  /// length keeps the result a true fraction of that axis.
  Offset _maxFraction(Size bounds) {
    final usableW = (bounds.width - _size - _margin).clamp(0.0, bounds.width);
    final usableH = (bounds.height - _size - _margin).clamp(0.0, bounds.height);
    return Offset(usableW / bounds.width, usableH / bounds.height);
  }

  /// The fraction actually used to place the logo: always inside [bounds], so
  /// a position persisted by an older build (which clamped against the whole
  /// screen) can never render underneath the nav bar.
  Offset clampedFraction(Size bounds) {
    final f = _fraction ?? defaultFraction(bounds);
    final max = _maxFraction(bounds);
    return Offset(f.dx.clamp(0.0, max.dx), f.dy.clamp(0.0, max.dy));
  }

  void beginDrag(Offset globalPoint, Size bounds) {
    _dragStartPoint = globalPoint;
    _dragStartFraction = clampedFraction(bounds);
  }

  void dragTo(Offset globalPoint, Size bounds) {
    final delta = globalPoint - _dragStartPoint;
    final max = _maxFraction(bounds);
    _fraction = Offset(
      (_dragStartFraction.dx + delta.dx / bounds.width).clamp(0.0, max.dx),
      (_dragStartFraction.dy + delta.dy / bounds.height).clamp(0.0, max.dy),
    );
    notifyListeners();
  }

  /// Rule the member asked for: a logo parked in the middle of the screen
  /// snaps back to whichever side edge is nearer, so it never sits on top of
  /// the page content. The vertical position is kept (and re-clamped).
  void snapToSide(Size bounds) {
    final f = clampedFraction(bounds);
    final centrePx = f.dx * bounds.width + _size / 2;
    final middle = bounds.width / 2;
    // Only snap when the logo really is in the central band; a logo already
    // resting against an edge stays exactly where the member put it.
    if ((centrePx - middle).abs() < bounds.width * 0.25) {
      final toLeft = centrePx < middle;
      final x = toLeft ? _margin : (bounds.width - _size - _margin);
      final max = _maxFraction(bounds);
      _fraction = Offset(x / bounds.width, f.dy.clamp(0.0, max.dy));
      notifyListeners();
    }
  }

  void beginScale() => _dragStartSize = _size;

  /// Test-only hook: simulates a position persisted by an older build.
  @visibleForTesting
  void debugSetFraction(Offset fraction) => _fraction = fraction;

  void scaleTo(double scale, Size bounds) {
    final maxDim = bounds.width < bounds.height ? bounds.width : bounds.height;
    final cap = maxDim - 16 < 96 ? maxDim - 16 : 96.0;
    _size = (_dragStartSize * scale).clamp(44.0, cap);
    // A bigger logo must not push itself past an edge — re-clamp to match.
    _fraction = clampedFraction(bounds);
    notifyListeners();
  }

  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('plan_logo_size', _size);
      final f = _fraction;
      if (f != null) {
        await prefs.setDouble('plan_logo_x', f.dx);
        await prefs.setDouble('plan_logo_y', f.dy);
      }
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final floatingLogoPositionProvider =
    ChangeNotifierProvider<FloatingLogoPosition>((ref) {
  final position = FloatingLogoPosition();
  position.load();
  return position;
});