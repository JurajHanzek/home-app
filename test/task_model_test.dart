import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/tasks/domain/task.dart';

void main() {
  test('task lifecycle uses the database status values', () {
    expect(TaskStatus.values.map((status) => status.value), [
      'to_do',
      'in_progress',
      'done',
      'archived',
    ]);
    expect(TaskStatusLabel.parse('in_progress'), TaskStatus.inProgress);
    expect(TaskStatusLabel.parse('unknown'), TaskStatus.toDo);
  });

  test(
    'task mapping reads shared fields, assignments, dates, and ordered checklist',
    () {
      final task = TaskRecord.fromJson({
        'id': 'task-1',
        'title': 'Clean patio',
        'description': 'Shared note',
        'status': 'to_do',
        'priority': 'high',
        'category_id': 'category-1',
        'task_categories': {'name': 'Outdoor'},
        'task_assignees': [
          {'user_id': 'user-a'},
          {'user_id': 'user-b'},
        ],
        'task_checklist_items': [
          {'id': 'later', 'label': 'Sweep', 'is_done': true, 'sort_order': 1},
          {
            'id': 'first',
            'label': 'Move chairs',
            'is_done': false,
            'sort_order': 0,
          },
        ],
        'created_by': 'user-a',
        'updated_at': '2026-10-01T10:00:00.000Z',
        'due_at': '2026-10-02T07:00:00.000Z',
        'reminder_at': '2026-10-01T17:00:00.000Z',
        'source_template_id': 'template-1',
        'archived_at': null,
      });

      expect(task.description, 'Shared note');
      expect(task.categoryName, 'Outdoor');
      expect(task.assigneeIds, ['user-a', 'user-b']);
      expect(task.checklist.map((item) => item.id), ['first', 'later']);
      expect(task.checklist.last.done, isTrue);
      expect(task.dueAt, DateTime.parse('2026-10-02T07:00:00.000Z'));
      expect(task.reminderAt, isNotNull);
      expect(task.sourceTemplateId, 'template-1');
    },
  );
}
