import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/shared/utils/plan_meal_completion.dart';
import 'package:fitness_app/features/trainer/set_plan/data/plan_record_status.dart';

void main() {
  test('breakfast does not complete the same food at lunch or dinner', () {
    final logged = {planMealKey('Egg', 'Breakfast')};
    expect(
      planMealLogged({'name': 'egg', 'meal_type': 'breakfast'}, logged),
      isTrue,
    );
    for (final meal in ['lunch', 'dinner']) {
      expect(
        planMealLogged({'name': 'egg', 'meal_type': meal}, logged),
        isFalse,
      );
    }
  });
  test(
    'one-day plans remain active through their last day; pending requests stay active',
    () {
      final record = <String, dynamic>{
        'plan': {'status': 'active', 'end_date': '2026-10-23'},
        'completion_pct': 1.0,
        'fully_completed': false,
      };
      expect(
        trainerPlanIsHistory(
          record,
          hasPendingCancellation: false,
          now: DateTime(2026, 10, 23, 21),
        ),
        isFalse,
      );
      expect(
        trainerPlanIsHistory(
          record,
          hasPendingCancellation: false,
          now: DateTime(2026, 10, 24),
        ),
        isTrue,
      );
      expect(
        trainerPlanIsHistory(
          record,
          hasPendingCancellation: true,
          now: DateTime(2026, 10, 24),
        ),
        isFalse,
      );
      (record['plan'] as Map)['status'] = 'cancelled';
      expect(
        trainerPlanIsHistory(record, hasPendingCancellation: false),
        isTrue,
      );
    },
  );
}
