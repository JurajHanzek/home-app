import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../tasks/data/task_repository.dart';
import '../tasks/domain/task.dart';
import '../meals/data/meals_repository.dart';
import '../meals/domain/meal.dart';
import '../shopping/data/shopping_repository.dart';
import '../shopping/domain/shopping.dart';
import '../calendar/data/calendar_repository.dart';
import '../calendar/domain/calendar_event.dart';
import '../expenses/data/expenses_repository.dart';
import '../expenses/domain/expense.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((
  ref,
) async {
  // Watch before awaiting so all existing, shared providers load concurrently.
  final tasks = ref.watch(tasksProvider.future);
  final meals = ref.watch(mealsProvider.future);
  final shopping = ref.watch(shoppingProvider.future);
  final calendar = ref.watch(calendarProvider.future);
  final expenses = ref.watch(expensesProvider.future);
  final results = await Future.wait<Object>([
    tasks,
    meals,
    shopping,
    calendar,
    expenses,
  ]).timeout(const Duration(seconds: 25));
  return DashboardData(
    tasks: results[0] as TaskBoardData,
    meals: results[1] as MealsData,
    shopping: results[2] as ShoppingData,
    calendar: results[3] as CalendarData,
    expenses: results[4] as ExpensesData,
  );
});

class DashboardData {
  const DashboardData({
    required this.tasks,
    required this.meals,
    required this.shopping,
    required this.calendar,
    required this.expenses,
  });
  final TaskBoardData tasks;
  final MealsData meals;
  final ShoppingData shopping;
  final CalendarData calendar;
  final ExpensesData expenses;

  Iterable<TaskRecord> get activeTasks => tasks.tasks.where(
    (task) =>
        task.archivedAt == null &&
        (task.status == TaskStatus.toDo ||
            task.status == TaskStatus.inProgress),
  );
  List<TaskRecord> dueToday(DateTime now) => activeTasks.where((task) {
    final due = task.dueAt?.toLocal();
    return due != null &&
        due.year == now.year &&
        due.month == now.month &&
        due.day == now.day;
  }).toList()..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  List<TaskRecord> overdue(DateTime now) =>
      activeTasks
          .where(
            (task) =>
                task.dueAt != null &&
                task.dueAt!.toLocal().isBefore(
                  DateTime(now.year, now.month, now.day),
                ),
          )
          .toList()
        ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  List<CalendarEvent> todayEvents(DateTime now) =>
      calendarEventsForDay(calendar.events, now);
  List<MealShoppingGroup> nextMeals(DateTime now) => ShoppingData(
    meals: meals.meals,
    generalItems: const [],
  ).nextMealGroups(now: now);
  int missingIngredients(DateTime now) => nextMeals(
    now,
  ).fold(0, (total, group) => total + group.missingItems.length);
  int get generalNeeded => shopping.generalItems
      .where((item) => !item.isArchived && !item.isDone)
      .length;
  int countStatus(TaskStatus status) =>
      activeTasks.where((task) => task.status == status).length;
}
