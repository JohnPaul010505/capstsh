import 'dart:convert';
import 'package:fitness_app/features/trainer/set_plan/data/plan_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_app/features/member/settings/pages/member_trainer_plan_list_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const member = '00000000-0000-4000-8000-000000000001';
  const trainer = '00000000-0000-4000-8000-000000000002';
  final tomorrow = DateTime.now()
      .add(const Duration(days: 1))
      .toIso8601String()
      .split('T')
      .first;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://plan-test.supabase.co',
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
              'id': member,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'test@example.invalid',
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else if (request.url.path.endsWith('/trainer_assignments')) {
          body = [
            {
              'trainer_id': trainer,
              'profiles': {'id': trainer, 'full_name': 'Coach'},
            },
          ];
        } else if (request.url.path.endsWith('/member_goal_plans')) {
          final filters = request.url.queryParametersAll['start_date'] ?? [];
          final excludesFuture = filters.any(
            (f) =>
                f.startsWith('lte.') && tomorrow.compareTo(f.substring(4)) > 0,
          );
          body = excludesFuture
              ? <Object>[]
              : [
                  {
                    'id': 'plan',
                    'trainer_id': trainer,
                    'is_displayed': false,
                    'start_date': tomorrow,
                    'end_date': tomorrow,
                  },
                ];
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
  test('assigned future plan is visible in the trainer list', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(
      memberTrainerPlansProvider,
      (_, __) {},
    );
    addTearDown(subscription.close);
    final rows = await container.read(memberTrainerPlansProvider.future);
    expect(rows.single['hasPlan'], isTrue);
    expect(rows.single['planId'], 'plan');
    expect(rows.single['scheduledStart'], tomorrow);
  });
  test('member detail can preview a scheduled plan', () async {
    final plan = await PlanRepository().getActivePlan(
      member,
      trainer,
      includeUpcoming: true,
    );
    expect(plan?['id'], 'plan');
  });
  test(
    'daily activity excludes scheduled plans until their start date',
    () async {
      expect(await PlanRepository().getActivePlan(member, trainer), isNull);
      expect(await PlanRepository().getDisplayedPlans(member), isEmpty);
    },
  );
}
