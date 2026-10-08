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
/// Stored as fractions of the screen so rotation/resolution never breaks it;
/// `fraction == null` means "default spot" (right:16, bottom:96).
class FloatingLogoPosition extends ChangeNotifier {
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

  Offset defaultFraction(Size screen) => Offset(
        (screen.width - _size - 16) / screen.width,
        (screen.height - _size - 96) / screen.height,
      );

  void beginDrag(Offset globalPoint, Size screen) {
    _dragStartPoint = globalPoint;
    _dragStartFraction = _fraction ?? defaultFraction(screen);
  }

  void dragTo(Offset globalPoint, Size screen) {
    final delta = globalPoint - _dragStartPoint;
    final maxX = (screen.width - _size - 8) / screen.width;
    final maxY = (screen.height - _size - 8) / screen.height;
    _fraction = Offset(
      (_dragStartFraction.dx + delta.dx / screen.width).clamp(0.0, maxX),
      (_dragStartFraction.dy + delta.dy / screen.height).clamp(0.0, maxY),
    );
    notifyListeners();
  }

  void beginScale() => _dragStartSize = _size;

  void scaleTo(double scale, Size screen) {
    final maxDim = screen.width < screen.height ? screen.width : screen.height;
    final cap = maxDim - 16 < 96 ? maxDim - 16 : 96.0;
    _size = (_dragStartSize * scale).clamp(44.0, cap);
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