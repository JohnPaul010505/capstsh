import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_app/app/design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fitness_app/features/member/feedback/pages/feedback_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://feedback-test.supabase.co',
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
              'id': 'member',
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': 'test@example.invalid',
              'created_at': '2026-01-01T00:00:00Z',
            },
          };
        } else if (request.url.path.endsWith('/trainer_assignments')) {
          final rows = [
            {
              'trainer_id': 'new',
              'profiles': {'full_name': 'New Coach'},
            },
            {
              'trainer_id': 'older',
              'profiles': {'full_name': 'Older Coach'},
            },
          ];
          body = request.url.queryParameters['limit'] == '1'
              ? rows.take(1).toList()
              : rows;
        } else if (request.url.path.endsWith('/trainer_feedback')) {
          final rows = [
            {
              'id': 'feedback',
              'trainer_id': 'older',
              'content': 'Good progress',
              'created_at': '2026-10-23T00:00:00Z',
              'trainer': {'full_name': 'Older Coach'},
            },
            {'id': 'former-feedback', 'trainer_id': 'former'},
          ];
          final filter = request.url.queryParameters['trainer_id'];
          body = filter == null
              ? rows
              : rows
                    .where((row) => filter == 'eq.${row['trainer_id']}')
                    .toList();
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
  testWidgets(
    'five feedback entries per page for all and individual trainers',
    (tester) async {
      ClayColors.setBrightness(Brightness.light);
      addTearDown(() => ClayColors.setBrightness(Brightness.dark));
      final router = GoRouter(
        initialLocation: '/member/feedback',
        routes: [
          GoRoute(
            path: '/member/feedback',
            builder: (_, __) => const FeedbackPage(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainerFeedbackProvider.overrideWith(
              (ref) async => List.generate(
                7,
                (index) => {
                  'id': 'row-$index',
                  'trainer_id': index < 6 ? 'older' : 'new',
                  'trainer': {
                    'full_name': index < 6 ? 'Older Coach' : 'New Coach',
                  },
                  'content': 'Message $index',
                  'created_at': '2026-10-23T00:00:00Z',
                },
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(CupertinoIcons.chevron_right),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.text('1–5 of 7'), findsOneWidget);
      expect(find.text('Message 4'), findsOneWidget);
      expect(find.text('Message 5'), findsNothing);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await tester.scrollUntilVisible(
        find.byIcon(CupertinoIcons.chevron_right),
        300,
      );
      await tester.tap(find.byIcon(CupertinoIcons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('6–7 of 7'), findsOneWidget);
      expect(find.text('Message 5'), findsOneWidget);
      expect(find.text('Message 0'), findsNothing);
      await tester.scrollUntilVisible(
        find.byIcon(CupertinoIcons.chevron_left),
        300,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(CupertinoIcons.chevron_left));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(CupertinoIcons.chevron_right),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.text('1–5 of 7'), findsOneWidget);
      tester
          .widget<ListView>(find.byType(ListView).first)
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feedback-trainer-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Older Coach').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(CupertinoIcons.chevron_right),
        300,
      );
      await tester.pumpAndSettle();
      expect(find.text('1–5 of 6'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byIcon(CupertinoIcons.chevron_right),
        300,
      );
      await tester.tap(find.byIcon(CupertinoIcons.chevron_right));
      await tester.pumpAndSettle();
      expect(find.text('6–6 of 6'), findsOneWidget);
      tester
          .widget<ListView>(find.byType(ListView).first)
          .controller!
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('feedback-trainer-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Coach').last);
      await tester.pumpAndSettle();
      expect(find.byIcon(CupertinoIcons.chevron_right), findsNothing);
      expect(find.text('Message 6'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('trainer dropdown filters feedback and can show all again', (
    tester,
  ) async {
    ClayColors.setBrightness(Brightness.light);
    addTearDown(() => ClayColors.setBrightness(Brightness.dark));
    final router = GoRouter(
      initialLocation: '/member/feedback',
      routes: [
        GoRoute(
          path: '/member/feedback',
          builder: (_, __) => const FeedbackPage(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Good progress'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feedback-trainer-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Coach').last);
    await tester.pumpAndSettle();
    expect(find.text('Good progress'), findsNothing);
    expect(find.text('No feedback from this trainer yet.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feedback-trainer-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Older Coach').last);
    await tester.pumpAndSettle();
    expect(find.text('Good progress'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('feedback-trainer-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All trainers').last);
    await tester.pumpAndSettle();
    expect(find.text('Good progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test(
    'feedback from another active trainer remains visible, former trainers excluded',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final sub = container.listen(trainerFeedbackProvider, (_, __) {});
      addTearDown(sub.close);
      final rows = await container.read(trainerFeedbackProvider.future);
      expect(rows.map((row) => row['id']), ['feedback']);
    },
  );
}
