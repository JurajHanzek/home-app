enum TaskStatus { toDo, inProgress, done, archived }

enum TaskPriority { low, normal, high, urgent }

extension TaskStatusLabel on TaskStatus {
  String get label => switch (this) {
    TaskStatus.toDo => 'To Do',
    TaskStatus.inProgress => 'In Progress',
    TaskStatus.done => 'Done',
    TaskStatus.archived => 'Archived',
  };

  String get value => switch (this) {
    TaskStatus.toDo => 'to_do',
    TaskStatus.inProgress => 'in_progress',
    TaskStatus.done => 'done',
    TaskStatus.archived => 'archived',
  };

  static TaskStatus parse(String value) => switch (value) {
    'in_progress' => TaskStatus.inProgress,
    'done' => TaskStatus.done,
    'archived' => TaskStatus.archived,
    _ => TaskStatus.toDo,
  };
}

extension TaskPriorityLabel on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.normal => 'Normal',
    TaskPriority.high => 'High',
    TaskPriority.urgent => 'Urgent',
  };

  String get value => name;

  static TaskPriority parse(String value) => TaskPriority.values.firstWhere(
    (priority) => priority.value == value,
    orElse: () => TaskPriority.normal,
  );
}

class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    this.archived = false,
  });
  final String id;
  final String name;
  final bool archived;

  factory TaskCategory.fromJson(Map<String, dynamic> json) => TaskCategory(
    id: json['id'] as String,
    name: json['name'] as String,
    archived: json['archived_at'] != null,
  );
}

class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.label,
    required this.done,
    required this.order,
  });
  final String id;
  final String label;
  final bool done;
  final int order;

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) =>
      TaskChecklistItem(
        id: json['id'] as String,
        label: json['label'] as String,
        done: json['is_done'] as bool? ?? false,
        order: json['sort_order'] as int? ?? 0,
      );
}

class HouseholdPerson {
  const HouseholdPerson({
    required this.id,
    required this.name,
    required this.initials,
  });
  final String id;
  final String name;
  final String initials;
}

class TaskRecord {
  const TaskRecord({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.categoryId,
    required this.categoryName,
    required this.assigneeIds,
    required this.checklist,
    required this.createdBy,
    required this.updatedAt,
    this.dueAt,
    this.reminderAt,
    this.sourceTemplateId,
    this.archivedAt,
  });

  final String id, title, description, createdBy;
  final TaskStatus status;
  final TaskPriority priority;
  final String? categoryId, categoryName, sourceTemplateId;
  final List<String> assigneeIds;
  final List<TaskChecklistItem> checklist;
  final DateTime updatedAt;
  final DateTime? dueAt, reminderAt, archivedAt;

  factory TaskRecord.fromJson(Map<String, dynamic> json) {
    final category = json['task_categories'] as Map<String, dynamic>?;
    final assignees = (json['task_assignees'] as List<dynamic>? ?? const [])
        .map((item) => (item as Map<String, dynamic>)['user_id'] as String)
        .toList();
    final checklist =
        (json['task_checklist_items'] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  TaskChecklistItem.fromJson(item as Map<String, dynamic>),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return TaskRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      status: TaskStatusLabel.parse(json['status'] as String),
      priority: TaskPriorityLabel.parse(json['priority'] as String),
      categoryId: json['category_id'] as String?,
      categoryName: category?['name'] as String?,
      assigneeIds: assignees,
      checklist: checklist,
      createdBy: json['created_by'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      dueAt: json['due_at'] == null
          ? null
          : DateTime.parse(json['due_at'] as String),
      reminderAt: json['reminder_at'] == null
          ? null
          : DateTime.parse(json['reminder_at'] as String),
      sourceTemplateId: json['source_template_id'] as String?,
      archivedAt: json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String),
    );
  }
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.categoryId,
    required this.assigneeIds,
    required this.checklist,
    this.dueAt,
    this.reminderAt,
    this.sourceTemplateId,
  });
  final String title, description;
  final TaskStatus status;
  final TaskPriority priority;
  final String? categoryId, sourceTemplateId;
  final List<String> assigneeIds;
  final List<String> checklist;
  final DateTime? dueAt, reminderAt;
}

List<TaskRecord> filterTaskRecords(
  Iterable<TaskRecord> tasks, {
  TaskStatus? status,
  String? categoryId,
  bool archivedOnly = false,
}) => tasks.where((task) {
  if (archivedOnly) {
    if (task.status != TaskStatus.archived) return false;
  } else {
    if (task.status == TaskStatus.archived) return false;
    if (status != null && task.status != status) return false;
  }
  if (categoryId != null && task.categoryId != categoryId) return false;
  return true;
}).toList();
