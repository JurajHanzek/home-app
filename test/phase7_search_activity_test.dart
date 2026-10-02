import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/search/search_repository.dart';
import 'package:home_hub/features/search/search_screen.dart';
import 'package:home_hub/features/search/entity_details_screen.dart';
import 'package:home_hub/features/activity/activity_repository.dart';
import 'package:home_hub/features/tasks/data/task_repository.dart';
import 'package:home_hub/features/meals/data/meals_repository.dart';
import 'package:home_hub/features/meals/domain/meal.dart';
import 'package:home_hub/features/calendar/data/calendar_repository.dart';
import 'package:home_hub/features/expenses/data/expenses_repository.dart';
import 'package:home_hub/features/expenses/domain/expense.dart';
import 'phase7_dashboard_test.dart' show dashboardFixture;
import 'expense_model_test.dart' show expenseFixture, expenseData;

final results = [
  const EntityResult(
    id: 'Today task',
    type: EntityType.task,
    title: 'Task result',
    archived: true,
  ),
  const EntityResult(
    id: 'recipe',
    type: EntityType.recipe,
    title: 'Recipe result',
    archived: true,
  ),
  const EntityResult(
    id: 'Next dinner',
    type: EntityType.meal,
    title: 'Meal result',
    archived: true,
  ),
  const EntityResult(
    id: 'Today event',
    type: EntityType.event,
    title: 'Event result',
    archived: true,
  ),
  const EntityResult(
    id: 'expense-1',
    type: EntityType.expense,
    title: 'Expense result',
    archived: true,
  ),
];

class SearchFake extends SearchRepository {
  SearchFake(super.client);
  List<EntityResult> rows = results;
  bool fail = false;
  Completer<List<EntityResult>>? pending;
  @override
  Future<List<EntityResult>> find({
    String query = '',
    bool archive = false,
    int offset = 0,
  }) async {
    if (fail) throw Exception('offline');
    if (pending != null) return pending!.future;
    return rows;
  }
}

class UnusedClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TasksFake extends TaskRepository {
  TasksFake(SupabaseClient client) : super(client, 'user-a');
  @override
  Future<List<(String, String)>> images(String taskId) async => [];
}

class ExpensesFake extends ExpensesRepository {
  ExpensesFake(SupabaseClient client) : super(client, 'user-a');
  bool restored = false;
  ExpensesData get data => expenseData([expenseFixture(archived: !restored)]);
  @override
  Future<void> setArchived(ExpenseRecord expense, bool archived) async {
    restored = !archived;
  }
}

void main() {
  SupabaseClient client({MockClient? httpClient, WidgetTester? tester}) {
    if (tester != null) return UnusedClient();
    final client = SupabaseClient(
      'https://example.test',
      'key',
      httpClient: httpClient,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    addTearDown(() async {
      if (tester == null) {
        await client.dispose();
      } else {
        await tester.runAsync(client.dispose);
      }
    });
    return client;
  }

  test(
    'search sends literal query and pagination to RLS RPC, never shopping',
    () async {
      final requests = <http.Request>[];
      final repo = SearchRepository(
        client(
          httpClient: MockClient((request) async {
            requests.add(request);
            return http.Response(
              jsonEncode([
                for (final item in results)
                  {
                    'entity_id': item.id,
                    'entity_type': item.type.name,
                    'title': item.title,
                    'archived': item.archived,
                  },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
      );
      expect(await repo.find(query: '   '), isEmpty);
      expect(requests, isEmpty);
      final found = await repo.find(query: '  ORCHID %_,  ', offset: 100);
      expect(found.map((e) => e.type), EntityType.values);
      expect(found.every((e) => e.archived), isTrue);
      expect(
        requests.single.url.path,
        '/rest/v1/rpc/search_household_entities',
      );
      expect(jsonDecode(requests.single.body), {
        'query_text': 'ORCHID %_,',
        'archived_only': false,
        'page_offset': 100,
      });
    },
  );
  test(
    'activity requests newest first with bounded results and safe navigation',
    () async {
      late Uri uri;
      final repo = ActivityRepository(
        client(
          httpClient: MockClient((request) async {
            uri = request.url;
            return http.Response(
              jsonEncode([
                for (final day in [3, 2])
                  {
                    'id': '$day',
                    'actor_user_id': 'user-a',
                    'profiles': {'display_name': 'Alice'},
                    'action': 'created',
                    'entity_type': 'task',
                    'entity_id': 'task',
                    'created_at': '2026-10-0${day}T12:00:00Z',
                  },
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        ),
      );
      final items = await repo.load();
      expect(
        uri.queryParameters['order'],
        'created_at.desc.nullslast,id.desc.nullslast',
      );
      expect(uri.queryParameters['limit'], '50');
      expect(items.first.createdAt.isAfter(items.last.createdAt), isTrue);
      expect(items.first.actor, 'Alice');
      expect(items.first.route, '/entity/task/task');
    },
  );

  Future<GoRouter> open(
    WidgetTester tester,
    SearchFake repo, {
    bool archive = false,
    ExpensesFake? expenseRepo,
  }) async {
    final data = dashboardFixture(DateTime.now());
    final recipes = MealsData(
      meals: data.meals.meals,
      recipes: [
        RecipeRecord(
          id: 'recipe',
          name: 'Soup recipe',
          instructions: 'Stir gently',
          ingredients: [],
          createdAt: DateTime(2026),
          archivedAt: DateTime(2026),
        ),
      ],
    );
    final router = GoRouter(
      initialLocation: archive ? '/archive' : '/search',
      routes: [
        GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
        GoRoute(
          path: '/archive',
          builder: (_, _) => const SearchScreen(archive: true),
        ),
        GoRoute(
          path: '/entity/:type/:id',
          builder: (_, state) => EntityDetailsScreen(
            type: EntityType.values.byName(state.pathParameters['type']!),
            id: state.pathParameters['id']!,
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          searchRepositoryProvider.overrideWithValue(repo),
          tasksProvider.overrideWith((ref) async => data.tasks),
          taskRepositoryProvider.overrideWithValue(TasksFake(repo.client)),
          mealsProvider.overrideWith((ref) async => recipes),
          mealsRepositoryProvider.overrideWithValue(
            MealsRepository(repo.client, 'user-a'),
          ),
          calendarProvider.overrideWith((ref) async => data.calendar),
          expensesProvider.overrideWith(
            (ref) async => expenseRepo?.data ?? data.expenses,
          ),
          if (expenseRepo != null)
            expensesRepositoryProvider.overrideWithValue(expenseRepo),
        ],
        child: MaterialApp.router(
          theme: AppTheme.forMode(HomeHubTheme.flower),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  for (final result in results) {
    testWidgets(
      'search opens existing ${result.type.name} details and returns with Back',
      (tester) async {
        final repo = SearchFake(client(tester: tester));
        final router = await open(tester, repo);
        expect(find.text('Task result'), findsNothing);
        await tester.enterText(find.byType(TextField), 'result');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text(result.title),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.text(result.title));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<EntityDetailsScreen>(find.byType(EntityDetailsScreen))
              .type,
          result.type,
        );
        expect(
          tester
              .widget<EntityDetailsScreen>(find.byType(EntityDetailsScreen))
              .id,
          result.id,
        );
        final expected = switch (result.type) {
          EntityType.task => 'Today task',
          EntityType.recipe => 'Soup recipe',
          EntityType.meal => 'Next dinner',
          EntityType.event => 'Today event',
          EntityType.expense => 'Market',
        };
        expect(find.text(expected), findsOneWidget);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(SearchScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Archive groups all domains and existing expense restore is used',
    (tester) async {
      final backend = client(tester: tester);
      final expense = ExpensesFake(backend);
      await open(
        tester,
        SearchFake(backend),
        archive: true,
        expenseRepo: expense,
      );
      for (final type in EntityType.values) {
        await tester.scrollUntilVisible(
          find.text(type.label),
          100,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text(type.label), findsOneWidget);
      }
      await tester.scrollUntilVisible(
        find.text('Expense result'),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Expense result'));
      await tester.pumpAndSettle();
      expect(find.text('Archived'), findsOneWidget);
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(expense.restored, isTrue);
      expect(find.text('Archived'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'search loading error retry no-results and cleared-query states',
    (tester) async {
      final repo = SearchFake(client(tester: tester))..fail = true;
      await open(tester, repo);
      await tester.enterText(find.byType(TextField), 'none');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      repo.fail = false;
      repo.pending = Completer();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repo.pending!.complete([]);
      await tester.pumpAndSettle();
      expect(find.text('No results found.'), findsOneWidget);
      repo.pending = null;
      repo.rows = [];
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      expect(
        find.text('Search active and archived household records.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('empty Archive is safe', (tester) async {
    await open(
      tester,
      SearchFake(client(tester: tester))..rows = [],
      archive: true,
    );
    expect(find.text('Nothing archived yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
