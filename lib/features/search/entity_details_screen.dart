import 'package:flutter/material.dart';
import '../tasks/presentation/tasks_screen.dart';
import '../meals/presentation/meals_screen.dart';
import '../calendar/presentation/calendar_screen.dart';
import '../expenses/presentation/expenses_screen.dart';
import 'search_repository.dart';

class EntityDetailsScreen extends StatelessWidget {
  const EntityDetailsScreen({required this.type, required this.id, super.key});
  final EntityType type;
  final String id;
  @override
  Widget build(BuildContext context) {
    if (type == EntityType.expense) return ExpensesScreen(detailId: id);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (type) {
          EntityType.task => 'Task',
          EntityType.recipe => 'Recipe',
          EntityType.meal => 'Meal',
          EntityType.event => 'Event',
          EntityType.expense => 'Expense',
        }),
      ),
      body: SafeArea(
        child: switch (type) {
          EntityType.task => TasksScreen(detailId: id),
          EntityType.recipe => MealsScreen(detailId: id, recipeDetail: true),
          EntityType.meal => MealsScreen(detailId: id),
          EntityType.event => CalendarScreen(detailId: id),
          EntityType.expense => const SizedBox.shrink(),
        },
      ),
    );
  }
}
