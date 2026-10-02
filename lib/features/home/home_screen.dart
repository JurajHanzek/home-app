import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../tasks/data/task_repository.dart';
import '../tasks/domain/task.dart';
import '../meals/data/meals_repository.dart';
import '../shopping/data/shopping_repository.dart';
import '../calendar/data/calendar_repository.dart';
import '../expenses/data/expenses_repository.dart';
import '../expenses/domain/expense.dart';
import '../activity/activity_repository.dart';
import '../activity/activity_screen.dart';
import 'dashboard_data.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  Timer? _clock;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    ref.invalidate(tasksProvider);
    ref.invalidate(mealsProvider);
    ref.invalidate(shoppingProvider);
    ref.invalidate(calendarProvider);
    ref.invalidate(expensesProvider);
    ref.invalidate(activityProvider);
    try {
      await ref.read(dashboardProvider.future);
    } catch (_) {
      /* Retry UI owns error. */
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _refresh,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Text(
          'What matters right now?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            OutlinedButton.icon(
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/archive'),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('Archive'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ref
            .watch(dashboardProvider)
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (_, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Home could not be loaded. Check your connection and household setup.',
                  ),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                  TextButton(
                    onPressed: () => context.push('/expenses'),
                    child: const Text('Expenses'),
                  ),
                ],
              ),
              data: _dashboard,
            ),
        _section('Recent activity', [
          const ActivityList(compact: true),
          TextButton(
            onPressed: () => context.push('/activity'),
            child: const Text('View activity'),
          ),
        ]),
      ],
    ),
  );

  Widget _dashboard(DashboardData data) {
    final now = DateTime.now();
    final events = data.todayEvents(now), due = data.dueToday(now);
    final overdue = data.overdue(now);
    final next = data.nextMeals(now).firstOrNull;
    final mealAttention =
        next != null &&
        next.missingItems.isNotEmpty &&
        !DateUtils.dateOnly(
          next.meal.plannedAt,
        ).isAfter(DateUtils.dateOnly(now).add(const Duration(days: 1)));
    final status = Theme.of(context).extension<TaskStatusColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Today', [
          if (events.isEmpty && due.isEmpty)
            const Text('A little breathing room. Nothing due today.'),
          for (final event in events.take(4))
            _item(
              event.title,
              event.allDay
                  ? 'All day'
                  : TimeOfDay.fromDateTime(event.startsAt).format(context),
              Icons.event_outlined,
              '/entity/event/${event.id}',
            ),
          for (final task in due.take(4))
            _item(
              task.title,
              'Due today · ${task.status.label}',
              Icons.check_circle_outline,
              '/entity/task/${task.id}',
            ),
          if (events.length > 4) _link('All today’s events', '/calendar'),
          if (due.length > 4) _link('All tasks', '/tasks'),
        ]),
        if (overdue.isNotEmpty || mealAttention)
          _section('Attention', [
            for (final task in overdue.take(3))
              _item(
                task.title,
                'Overdue · ${_date(task.dueAt!.toLocal())}',
                Icons.schedule,
                '/entity/task/${task.id}',
              ),
            if (overdue.length > 3)
              _link('${overdue.length} overdue tasks', '/tasks'),
            if (mealAttention)
              _item(
                'Ingredients needed for ${next.meal.name}',
                '${next.missingItems.length} still needed',
                Icons.shopping_basket_outlined,
                '/shopping',
              ),
          ]),
        _section('Next meal', [
          if (next == null) const Text('No upcoming meal planned.'),
          if (next != null) ...[
            if (next.meal.recipeImageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  next.meal.recipeImageUrl!,
                  height: 112,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            _item(
              next.meal.name,
              '${_date(next.meal.plannedAt)}${next.meal.hasTime ? ' · ${TimeOfDay.fromDateTime(next.meal.plannedAt).format(context)}' : ''}${next.meal.mealSlot == null ? '' : ' · ${next.meal.mealSlot}'} · ${next.missingItems.length} ingredients needed',
              Icons.restaurant_outlined,
              '/entity/meal/${next.meal.id}',
            ),
            if (next.missingItems.isNotEmpty)
              _link('Open Shopping', '/shopping'),
          ],
          if (next == null) _link('Plan a meal', '/meals'),
        ]),
        _section('Tasks', [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _count('${data.countStatus(TaskStatus.toDo)} To Do', status.toDo),
              _count(
                '${data.countStatus(TaskStatus.inProgress)} In Progress',
                status.inProgress,
              ),
              if (overdue.isNotEmpty) Text('${overdue.length} overdue'),
            ],
          ),
          _link('Open Tasks', '/tasks'),
        ]),
        _section('Shopping', [
          _item(
            '${data.missingIngredients(now)} meal ingredients · ${data.generalNeeded} General items',
            'Still needed for the next two meals and your household',
            Icons.shopping_cart_outlined,
            '/shopping',
          ),
        ]),
        _section(
          'Expenses · ${MaterialLocalizations.of(context).formatMonthYear(now)}',
          [
            _item(
              formatExpenseEur(data.expenses.currentMonthTotalCents(now)),
              'Current month',
              Icons.account_balance_wallet_outlined,
              '/expenses',
            ),
            for (final payer in data.expenses.payerTotals(now).entries)
              Text(
                '${data.expenses.person(payer.key)?.name ?? 'Household member'} · ${formatExpenseEur(payer.value)}',
              ),
          ],
        ),
      ],
    );
  }

  void _open(String route) {
    if (['/tasks', '/meals', '/calendar', '/shopping'].contains(route)) {
      context.go(route);
    } else {
      context.push(route);
    }
  }

  Widget _link(String text, String route) =>
      TextButton(onPressed: () => _open(route), child: Text(text));
  String _date(DateTime date) =>
      MaterialLocalizations.of(context).formatShortDate(date);
  Widget _count(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 10, color: color),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
  Widget _item(String title, String subtitle, IconData icon, String route) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: () => _open(route),
      );
  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    ),
  );
}
