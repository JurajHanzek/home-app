import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/tasks/data/task_repository.dart';
import 'package:home_hub/features/tasks/domain/task.dart';
import 'package:home_hub/features/tasks/presentation/tasks_screen.dart';

void main() {
  testWidgets('task card lays out at intrinsic height inside a list', (
    tester,
  ) async {
    final task = TaskRecord(
      id: 'task-1',
      title: 'Wash the car',
      description: '',
      status: TaskStatus.toDo,
      priority: TaskPriority.normal,
      categoryId: null,
      categoryName: null,
      assigneeIds: const [],
      checklist: const [],
      createdBy: 'user-1',
      updatedAt: DateTime.utc(2026, 10, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.forMode(HomeHubTheme.dark),
        home: Scaffold(
          body: ListView(
            children: [
              TaskCard(
                task: task,
                data: const TaskBoardData(
                  tasks: [],
                  categories: [],
                  people: [],
                  templates: [],
                ),
                onTap: () {},
                onStatus: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Wash the car'), findsOneWidget);
  });
}
