import 'package:fitness_app/app/design_tokens.dart';
import 'package:fitness_app/features/member/calendar/providers/month_entries_provider.dart';
import 'package:fitness_app/features/member/calendar/widgets/calendar_flip_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('calendar workout details use readable light mode colors', (
    tester,
  ) async {
    ClayColors.setBrightness(Brightness.light);
    addTearDown(() => ClayColors.setBrightness(Brightness.dark));
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = DateTime(2026, 10, 24);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthEntriesProvider(('member', DateTime(2026, 10))).overrideWith(
            (ref) async => {
              'workouts': <Map<String, dynamic>>[
                {
                  'exercise_name': 'Bench Press',
                  'logged_at': day.toIso8601String(),
                  'workout_name': 'Workout S1',
                  'duration_seconds': 41,
                  'total_calories': 5,
                },
              ],
              'meals': <Map<String, dynamic>>[],
            },
          ),
        ],
        child: MaterialApp(
          theme: ThemeData.light(),
          home: Scaffold(
            body: CalendarFlipSheet(
              selected: day,
              today: day,
              memberId: 'member',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Workout'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Bench Press')).style!.color,
      ClayTokens.clayTextPrimary,
    );
    final headers = tester.widgetList<Container>(find.byType(Container)).where((
      widget,
    ) {
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.gradient is LinearGradient &&
          (decoration.gradient! as LinearGradient).colors.contains(
            const Color(0xFF1C1C2E),
          );
    });
    expect(headers, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
