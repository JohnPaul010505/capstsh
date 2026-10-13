import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/shared/utils/plan_day.dart';

/// The member's plan sheet must show the day the trainer scheduled for
/// TODAY: Day 1 runs on the plan's start_date, Day 2 once one calendar day
/// (24 h) has passed, and so on — it must never be stuck on Day 1.
void main() {
  group('activePlanDay — calendar-day walk from the start date', () {
    test('Day 1 on the start date itself', () {
      expect(
        activePlanDay(
          startDate: '2026-10-12',
          totalDays: 3,
          now: DateTime(2026, 10, 12, 9, 30),
        ),
        1,
      );
    });

    test('Day 1 still shows late on the start date', () {
      expect(
        activePlanDay(
          startDate: '2026-10-12',
          totalDays: 3,
          now: DateTime(2026, 10, 12, 23, 59),
        ),
        1,
      );
    });

    test('Day 2 once 24 hours (the next calendar day) has passed', () {
      expect(
        activePlanDay(
          startDate: '2026-10-12',
          totalDays: 3,
          now: DateTime(2026, 10, 13, 0, 0, 1),
        ),
        2,
      );
    });

    test('Day 3 two calendar days after the start date', () {
      expect(
        activePlanDay(
          startDate: '2026-10-12',
          totalDays: 3,
          now: DateTime(2026, 10, 14, 15, 45),
        ),
        3,
      );
    });

    test('DST change between days never skips or repeats a day', () {
      // US spring-forward: 2026-03-08. Local midnights are only 23 h apart,
      // so a local-time difference would floor to 1 and show Day 2 instead
      // of Day 3. Counting in UTC keeps the calendar-day walk exact.
      expect(
        activePlanDay(
          startDate: '2026-03-07',
          totalDays: 7,
          now: DateTime(2026, 3, 9, 12),
        ),
        3,
      );
    });

    test('a start date in the future stays on Day 1', () {
      expect(
        activePlanDay(
          startDate: '2026-10-20',
          totalDays: 3,
          now: DateTime(2026, 10, 12),
        ),
        1,
      );
    });

    test('past the last day clamps to the plan’s last day', () {
      expect(
        activePlanDay(
          startDate: '2026-10-12',
          totalDays: 3,
          now: DateTime(2026, 10, 30),
        ),
        3,
      );
    });

    test('missing or unparseable start date falls back to Day 1', () {
      expect(activePlanDay(startDate: null, totalDays: 3), 1);
      expect(activePlanDay(startDate: '', totalDays: 3), 1);
      expect(activePlanDay(startDate: 'soon', totalDays: 3), 1);
    });

    test('zero/negative totalDays still yields a valid day', () {
      expect(
        activePlanDay(startDate: '2026-10-12', totalDays: 0),
        1,
      );
    });
  });

  group('planDayCount — days the trainer actually built', () {
    test('highest day key in the per-day groups', () {
      expect(
        planDayCount([
          {'day': 1, 'exercises': []},
          {'day': 2, 'exercises': []},
          {'day': 3, 'exercises': []},
        ]),
        3,
      );
    });

    test('groups may be unordered', () {
      expect(
        planDayCount([
          {'day': 3},
          {'day': 1},
          {'day': 2},
        ]),
        3,
      );
    });

    test('caps at 7 to match the plan_day_completions constraint', () {
      expect(
        planDayCount([
          for (var d = 1; d <= 12; d++) {'day': d},
        ]),
        7,
      );
    });

    test('empty, null, or non-list plans count as a single day', () {
      expect(planDayCount(null), 1);
      expect(planDayCount(const []), 1);
      expect(planDayCount('not a list'), 1);
    });

    test('groups without a day key fall back to the group count', () {
      expect(planDayCount([{'exercises': []}, {'exercises': []}]), 2);
    });
  });
}
