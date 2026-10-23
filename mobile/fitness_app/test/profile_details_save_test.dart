import 'dart:convert';

import 'package:fitness_app/features/shared/widgets/profile_details_card.dart';
import 'package:fitness_app/app/design_tokens.dart';
import 'package:fitness_app/app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const id = '00000000-0000-4000-8000-000000000001';
  late Map<String, dynamic> stored;
  final requests = <http.Request>[];
  var rejectSave = false;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://profile-test.supabase.co',
      publishableKey: 'test-key',
      debug: false,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: EmptyLocalStorage(),
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        Object body;
        if (request.url.path.contains('/auth/')) {
          body = {
            'access_token': 'test-token',
            'refresh_token': 'test-refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': {
              'id': id,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'test@example.invalid',
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else if (request.url.path.endsWith('/profiles')) {
          if (request.method == 'PATCH') {
            if (rejectSave) {
              return http.Response(
                jsonEncode({'message': 'Permission denied', 'code': '42501'}),
                403,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }
            stored.addAll(jsonDecode(request.body) as Map<String, dynamic>);
          }
          body =
              (request.headers['Accept'] ?? request.headers['accept'])
                      ?.contains('object') ==
                  true
              ? stored
              : [stored];
        } else {
          body = <Object>[];
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
    stored = {
      'id': id,
      'role': 'trainer',
      'code': 'TEST',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
      'full_name': 'Test Trainer',
      'email': 'test@example.invalid',
      'specialty': 'Strength',
      'available_days': 'Mon 09:00-12:00',
    };
    requests.clear();
    rejectSave = false;
  });

  Future<void> showDetails(WidgetTester tester, {bool trainer = true}) async {
    final brightness = trainer ? Brightness.dark : Brightness.light;
    ClayColors.setBrightness(brightness);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              child: PersonalDetails(
                userId: id,
                editable: true,
                trainer: trainer,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final trainer in [true, false]) {
    testWidgets(
      '${trainer ? 'trainer' : 'member'} saves directly and equal-sized actions stay readable',
      (tester) async {
        await showDetails(tester, trainer: trainer);
        await tester.ensureVisible(find.text('Edit details'));
        final editSize = tester.getSize(
          find.widgetWithText(FilledButton, 'Edit details'),
        );
        await tester.tap(find.text('Edit details'));
        await tester.pumpAndSettle();
        final name = find.byType(TextField).first;
        await tester.enterText(name, 'Updated Name');
        if (trainer) {
          expect(find.text('9:00 AM'), findsWidgets);
          expect(find.text('12:00 PM'), findsWidgets);
          final tuesday = find.widgetWithText(FilterChip, 'Tue');
          await tester.ensureVisible(tuesday);
          await tester.tap(tuesday);
          await tester.pumpAndSettle();
          final chip = tester.widget<FilterChip>(tuesday);
          expect((chip.label as Text).style!.color, Colors.white);
        }
        final container = ProviderScope.containerOf(
          tester.element(find.byType(PersonalDetails)),
        );
        final router = container.read(routerProvider);
        await tester.ensureVisible(find.text('Save details'));
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Save details')),
          editSize,
        );
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Cancel')),
          editSize,
        );
        await tester.tap(find.text('Save details'));
        await tester.pumpAndSettle();
        expect(identical(container.read(routerProvider), router), isTrue);
        expect(find.byType(PersonalDetails), findsOneWidget);
        expect(stored['full_name'], 'Updated Name');
        if (trainer) {
          expect(stored['available_days'], 'Mon 09:00-12:00,Tue 09:00-17:00');
        }
        expect(find.text('Details saved'), findsOneWidget);
        expect(
          requests.any(
            (r) =>
                r.method == 'PATCH' && r.url.host == 'profile-test.supabase.co',
          ),
          isTrue,
        );
        expect(
          requests.any((r) => r.url.path == '/api/trainer/profile'),
          isFalse,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        Supabase.instance.client.realtime.disconnect();
        await tester.pump(const Duration(seconds: 60));
      },
    );
  }
  testWidgets(
    'failed save retains the edited values and explains the failure',
    (tester) async {
      rejectSave = true;
      await showDetails(tester);
      await tester.ensureVisible(find.text('Edit details'));
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Keep My Draft');
      await tester.ensureVisible(find.text('Save details'));
      await tester.tap(find.text('Save details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not save details: Permission denied'),
        findsOneWidget,
      );
      expect(find.text('Keep My Draft'), findsOneWidget);
      expect(find.text('Save details'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      Supabase.instance.client.realtime.disconnect();
      await tester.pump(const Duration(seconds: 60));
    },
  );
}
