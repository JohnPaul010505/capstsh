import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_app/app/design_tokens.dart';
import 'package:fitness_app/features/member/membership/widgets/renewal_request_sheet.dart';
import 'package:fitness_app/features/trainer/set_plan/data/plan_repository.dart';
import 'package:fitness_app/features/trainer/set_plan/pages/create_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var status = 'active';
  var complete = false;
  final today = DateTime.now().toIso8601String().split('T').first;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://flow-test.supabase.co',
      publishableKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        Object body = <Object>[];
        if (request.url.path.contains('/auth/')) {
          body = {
            'access_token': 'test-token',
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': 'trainer',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'test@example.invalid',
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else if (request.url.path.endsWith('/trainer_assignments')) {
          body = [
            {'member_id': 'member'},
          ];
        } else if (request.url.path.endsWith('/profiles')) {
          body = [
            {'id': 'member', 'full_name': 'Test Member'},
          ];
        } else if (request.url.path.endsWith('/member_goal_plans')) {
          body = [
            {
              'id': 'plan',
              'member_id': 'member',
              'status': status,
              'start_date': today,
              'end_date': today,
              'food_plan': [
                {
                  'day': 1,
                  'foods': [
                    {'name': 'egg', 'meal_type': 'breakfast'},
                  ],
                },
              ],
              'exercise_plan': [
                {
                  'day': 1,
                  'exercises': [
                    {'name': 'Bench Press'},
                  ],
                },
              ],
            },
          ];
        } else if (request.url.path.endsWith('/plan_day_completions')) {
          body = complete
              ? [
                  {
                    'day_number': 1,
                    'completed_foods': ['breakfast::egg'],
                    'completed_exercises': ['Bench Press'],
                  },
                ]
              : [];
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'test@example.invalid',
      password: 'test',
    );
  });
  tearDownAll(() => Supabase.instance.dispose());
  setUp(() {
    status = 'active';
    complete = false;
    ClayColors.setBrightness(Brightness.light);
  });
  tearDown(() => ClayColors.setBrightness(Brightness.dark));
  test('only unfinished active plans block creating a new plan', () async {
    final repo = PlanRepository();
    expect(
      await repo.getMembersWithUnfinishedPlans('trainer'),
      contains('member'),
    );
    complete = true;
    expect(await repo.getMembersWithUnfinishedPlans('trainer'), isEmpty);
    complete = false;
    status = 'cancelled';
    expect(await repo.getMembersWithUnfinishedPlans('trainer'), isEmpty);
  });
  testWidgets('active plan hides inputs and replacement bypass', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreatePlanScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('already has an active plan'), findsOneWidget);
    expect(find.text('I understand, continue'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('START DATE'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('membership application sheet uses a light surface', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RenewalRequestSheet(currentPlanName: 'Monthly')),
      ),
    );
    await tester.pumpAndSettle();
    final gradients = tester
        .widgetList<Container>(find.byType(Container))
        .map((widget) => widget.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>();
    expect(gradients, isNotEmpty);
    expect(
      gradients.every(
        (gradient) =>
            gradient.colors.every((color) => color.computeLuminance() > 0.5),
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
