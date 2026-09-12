import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
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