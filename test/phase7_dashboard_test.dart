import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/home/dashboard_data.dart';
import 'package:home_hub/features/home/home_screen.dart';
import 'package:home_hub/features/activity/activity_repository.dart';
import 'package:home_hub/features/tasks/data/task_repository.dart';
import 'package:home_hub/features/tasks/domain/task.dart';
import 'package:home_hub/features/meals/domain/meal.dart';
import 'package:home_hub/features/calendar/domain/calendar_event.dart';
import 'package:home_hub/features/shopping/domain/shopping.dart';
import 'expense_model_test.dart' show expenseFixture, expenseData;

TaskRecord dashboardTask(
  String id,
  DateTime due, {
  String status = 'to_do',
  bool archived = false,
}) => TaskRecord.fromJson({
  'id': id,
  'title': id,
  'description': 'Find description',
  'status': status,
  'priority': 'normal',
  'created_by': 'user-a',
  'updated_at': due.toIso8601String(),
  'due_at': due.toIso8601String(),
  'archived_at': archived ? due.toIso8601String() : null,
});
CalendarEvent dashboardEvent(
  String id,
  DateTime start, {
  DateTime? end,
  bool archived = false,
}) => CalendarEvent.fromJson({
  'id': id,
  'title': id,
  'starts_at': start.toIso8601String(),
  'ends_at': (end ?? start.add(const Duration(hours: 1))).toIso8601String(),
  'created_by': 'user-a',
  'updated_at': start.toIso8601String(),
  'archived_at': archived ? start.toIso8601String() : null,
});
MealRecord dashboardMeal(
  String id,
  DateTime date, {
  bool archived = false,
  bool timed = true,
}) => MealRecord(
  id: id,
  name: id,
  plannedAt: date,
  mealTime: timed ? '18:00' : null,
  servings: 2,
  notes: '',
  archivedAt: archived ? date : null,
  ingredients: [
    IngredientRecord(id: '$id-a', label: 'Rice'),
    IngredientRecord(id: '$id-b', label: 'Rice'),
    IngredientRecord(id: '$id-c', label: 'Salt', have: true),
  ],
);
DashboardData dashboardFixture(DateTime now, {bool empty = false}) {
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  return DashboardData(
    tasks: TaskBoardData(
      tasks: empty
          ? []
          : [
              dashboardTask('Today task', today),
              dashboardTask(
                'Overdue task',
                today.subtract(const Duration(days: 1)),
              ),
              dashboardTask('Done task', today, status: 'done'),
              dashboardTask('Archived task', today, status: 'archived'),
              dashboardTask('Timestamp archived', today, archived: true),
              dashboardTask('Working task', today, status: 'in_progress'),
            ],
      categories: [],
      people: [],
      templates: [],
    ),
    meals: MealsData(
      recipes: [],
      meals: empty
          ? []
          : [
              dashboardMeal('Later', tomorrow.add(const Duration(days: 1))),
              dashboardMeal('Next dinner', tomorrow),
              dashboardMeal('Old', today.subtract(const Duration(days: 1))),
              dashboardMeal('Archived meal', today, archived: true),
            ],
    ),
    calendar: CalendarData(
      events: empty
          ? []
          : [
              dashboardEvent(
                'Today event',
                today.add(const Duration(hours: 10)),
              ),
              dashboardEvent(
                'Spanning event',
                today.subtract(const Duration(hours: 2)),
                end: today.add(const Duration(hours: 2)),
              ),
              dashboardEvent('Archived event', today, archived: true),
              dashboardEvent('Tomorrow event', tomorrow),
            ],
      people: [],
    ),
    shopping: ShoppingData(
      meals: [],
      generalItems: empty
          ? []
          : [
              GeneralShoppingItem(
                id: 'a',
                label: 'Milk',
                isDone: false,
                createdBy: 'user-a',
                createdAt: today,
              ),
              GeneralShoppingItem(
                id: 'b',
                label: 'Milk',
                isDone: true,
                createdBy: 'user-a',
                createdAt: today,
              ),
              GeneralShoppingItem(
                id: 'c',
                label: 'Milk',
                isDone: false,
                createdBy: 'user-a',
                createdAt: today,
                archivedAt: today,
              ),
            ],
    ),
    expenses: expenseData(
      empty
          ? []
          : [
              expenseFixture(date: today, cents: 1234),
              expenseFixture(date: today, archived: true, cents: 9999),
              expenseFixture(
                date: DateTime(now.year, now.month - 1),
                cents: 444,
              ),
            ],
    ),
  );
}

void main() {
  final now = DateTime(2026, 10, 3, 12);
  final data = dashboardFixture(now);
  test('Today includes current and spanning events in chronological order', () {
    expect(data.todayEvents(now).map((e) => e.id), [
      'Spanning event',
      'Today event',
    ]);
  });
  test(
    'Today includes due active tasks and excludes done and both archive forms',
    () {
      expect(data.dueToday(now).map((e) => e.id), [
        'Today task',
        'Working task',
      ]);
    },
  );
  test('Attention includes only overdue active tasks', () {
    expect(data.overdue(now).map((e) => e.id), ['Overdue task']);
  });
  test('next meal is earliest active upcoming, not past or archived', () {
    expect(data.nextMeals(now).first.meal.id, 'Next dinner');
    expect(data.nextMeals(now).first.missingItems.length, 2);
  });
  test('shopping counts duplicate missing rows across next two meals', () {
    expect(data.missingIngredients(now), 4);
    expect(data.generalNeeded, 1);
  });
  test(
    'expense month total excludes archived and other months and uses payer',
    () {
      expect(data.expenses.currentMonthTotalCents(now), 1234);
      expect(data.expenses.payerTotals(now), {'user-b': 1234});
    },
  );
  test('task summary includes active To Do and In Progress only', () {
    expect(data.countStatus(TaskStatus.toDo), 2);
    expect(data.countStatus(TaskStatus.inProgress), 1);
  });
  test('next meal handles timed passed meals and undated-time meals today', () {
    final shopping = ShoppingData(
      meals: [
        dashboardMeal('passed', DateTime(2026, 10, 3, 9)),
        dashboardMeal('no time', DateTime(2026, 10, 3), timed: false),
      ],
      generalItems: [],
    );
    expect(shopping.nextMealGroups(now: now).single.meal.id, 'no time');
  });
  for (final mode in HomeHubTheme.values) {
    for (final size in AppFontSize.values) {
      testWidgets('Home scrolls safely in ${mode.name} / ${size.name}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardProvider.overrideWith(
                (ref) async => dashboardFixture(DateTime.now()),
              ),
              activityProvider.overrideWith((ref) async => []),
            ],
            child: MaterialApp(
              theme: AppTheme.forMode(mode),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(size.scale)),
                child: child!,
              ),
              home: const Scaffold(body: HomeScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Today event'), findsOneWidget);
        expect(find.text('Today task'), findsOneWidget);
        expect(find.text('Done task'), findsNothing);
        for (var i = 0; i < 6; i++) {
          await tester.drag(find.byType(ListView).first, const Offset(0, -400));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(find.text('Recent activity'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  testWidgets('empty Home remains compact and safe', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dashboardProvider.overrideWith(
            (ref) async => dashboardFixture(DateTime.now(), empty: true),
          ),
          activityProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          theme: AppTheme.forMode(HomeHubTheme.dark),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('A little breathing room. Nothing due today.'),
      findsOneWidget,
    );
    expect(find.text('Attention'), findsNothing);
    expect(find.text('No upcoming meal planned.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
