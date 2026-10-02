import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/tasks/domain/task.dart';
import 'package:home_hub/features/tasks/presentation/task_filters.dart';

void main() {
  testWidgets('filters are hidden until applied and support cancel and clear', (
    tester,
  ) async {
    TaskStatus? selectedStatus;
    String? selectedCategory;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: TaskListFilters(
              selectedStatus: selectedStatus,
              selectedCategoryId: selectedCategory,
              categories: const [TaskCategory(id: 'outdoor', name: 'Outdoor')],
              archivedCount: 2,
              showingArchived: false,
              onStatusChanged: (value) =>
                  setState(() => selectedStatus = value),
              onCategoryChanged: (value) =>
                  setState(() => selectedCategory = value),
              onArchivedPressed: () {},
              onAddCategory: () {},
              onManageCategories: () {},
            ),
          ),
        ),
      ),
    );

    FilterChip statusChip() => tester.widget<FilterChip>(
      find.byKey(const ValueKey('status-filter-to_do')),
    );
    FilterChip categoryChip() => tester.widget<FilterChip>(
      find.byKey(const ValueKey('category-filter-outdoor')),
    );

    expect(find.byType(FilterChip), findsNothing);
    await tester.tap(find.byKey(const ValueKey('task-filters')));
    await tester.pumpAndSettle();
    expect(statusChip().selected, isFalse);
    await tester.tap(find.byKey(const ValueKey('status-filter-to_do')));
    await tester.pumpAndSettle();
    expect(selectedStatus, isNull);
    expect(statusChip().selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('status-filter-to_do')));
    await tester.pumpAndSettle();
    expect(selectedStatus, isNull);
    expect(statusChip().selected, isFalse);
    await tester.tap(find.byKey(const ValueKey('category-filter-outdoor')));
    await tester.pumpAndSettle();
    expect(categoryChip().selected, isTrue);
    await tester.tap(find.byKey(const ValueKey('status-filter-to_do')));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();
    expect(selectedStatus, TaskStatus.toDo);
    expect(selectedCategory, 'outdoor');
    expect(find.byType(FilterChip), findsNothing);
    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('task-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(selectedStatus, TaskStatus.toDo);
    expect(selectedCategory, 'outdoor');
    tester
        .widget<InputChip>(find.byKey(const ValueKey('clear-status-filter')))
        .onDeleted!();
    await tester.pumpAndSettle();
    expect(selectedStatus, isNull);
    expect(selectedCategory, 'outdoor');
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(selectedCategory, isNull);
    expect(find.byType(InputChip), findsNothing);
  });

  test(
    'task filtering defaults to all active and combines status/category independently',
    () {
      final tasks = [
        _task('a', TaskStatus.toDo, 'outdoor'),
        _task('b', TaskStatus.inProgress, 'indoor'),
        _task('c', TaskStatus.done, 'outdoor'),
        _task('d', TaskStatus.archived, 'outdoor'),
      ];

      expect(filterTaskRecords(tasks).map((task) => task.id), ['a', 'b', 'c']);
      expect(
        filterTaskRecords(
          tasks,
          status: TaskStatus.done,
        ).map((task) => task.id),
        ['c'],
      );
      expect(
        filterTaskRecords(tasks, categoryId: 'outdoor').map((task) => task.id),
        ['a', 'c'],
      );
      expect(
        filterTaskRecords(tasks, status: TaskStatus.done, categoryId: 'indoor'),
        isEmpty,
      );
      expect(
        filterTaskRecords(tasks, archivedOnly: true).map((task) => task.id),
        ['d'],
      );
    },
  );

  test('status theme tokens remain semantically distinct in both themes', () {
    for (final mode in HomeHubTheme.values) {
      final tokens = AppTheme.forMode(mode).extension<TaskStatusColors>()!;
      expect(tokens.toDo, isNot(tokens.inProgress));
      expect(tokens.toDo, isNot(tokens.done));
      expect(tokens.inProgress, isNot(tokens.done));
    }
  });
}

TaskRecord _task(String id, TaskStatus status, String categoryId) => TaskRecord(
  id: id,
  title: id,
  description: '',
  status: status,
  priority: TaskPriority.normal,
  categoryId: categoryId,
  categoryName: null,
  assigneeIds: const [],
  checklist: const [],
  createdBy: 'user-a',
  updatedAt: DateTime.utc(2026, 10, 1),
);
