import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(
    Supabase.instance.client,
    Supabase.instance.client.auth.currentUser!.id,
  ),
);

final tasksProvider = FutureProvider.autoDispose<TaskBoardData>((ref) async {
  final repository = ref.watch(taskRepositoryProvider);
  final stream = repository.watchChanges(() => ref.invalidateSelf());
  ref.onDispose(stream.unsubscribe);
  return repository.load();
});

class TaskBoardData {
  const TaskBoardData({
    required this.tasks,
    required this.categories,
    required this.people,
    required this.templates,
  });
  final List<TaskRecord> tasks;
  final List<TaskCategory> categories;
  final List<HouseholdPerson> people;
  final List<Map<String, dynamic>> templates;
}

class TaskRepository {
  const TaskRepository(this._client, this.currentUserId);
  final SupabaseClient _client;
  final String currentUserId;

  RealtimeChannel watchChanges(void Function() changed) => _client
      .channel('homehub-tasks-$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'tasks',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_categories',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_assignees',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_checklist_items',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_images',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_templates',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_template_assignees',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'task_template_checklist_items',
        callback: (_) => changed(),
      )
      .subscribe();

  Future<TaskBoardData> load() async {
    final rows = await Future.wait([
      _client
          .from('tasks')
          .select(
            '*, task_categories(name), task_assignees(user_id), task_checklist_items(*)',
          )
          .order('updated_at', ascending: false),
      _client.from('task_categories').select().order('name'),
      _client
          .from('profiles')
          .select('id,display_name,initials')
          .order('created_at'),
      _client
          .from('task_templates')
          .select(
            '*, task_template_assignees(user_id), task_template_checklist_items(*)',
          )
          .isFilter('archived_at', null)
          .eq('enabled', true)
          .order('title'),
    ]);
    return TaskBoardData(
      tasks: (rows[0] as List)
          .map((row) => TaskRecord.fromJson(row as Map<String, dynamic>))
          .toList(),
      categories: (rows[1] as List)
          .map((row) => TaskCategory.fromJson(row as Map<String, dynamic>))
          .toList(),
      people: (rows[2] as List).map((row) {
        final p = row as Map<String, dynamic>;
        return HouseholdPerson(
          id: p['id'] as String,
          name: p['display_name'] as String,
          initials: p['initials'] as String,
        );
      }).toList(),
      templates: (rows[3] as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<String> create(TaskDraft draft, {bool makeTemplate = false}) async {
    String? templateId = draft.sourceTemplateId;
    if (makeTemplate) templateId = await _createTemplate(draft);
    final task = await _client
        .from('tasks')
        .insert(_taskPayload(draft, sourceTemplateId: templateId))
        .select('id')
        .single();
    final id = task['id'] as String;
    await _replaceChildren(id, draft);
    return id;
  }

  Future<void> update(
    TaskRecord task,
    TaskDraft draft, {
    bool updateTemplate = false,
  }) async {
    final payload = _taskPayload(draft, sourceTemplateId: task.sourceTemplateId)
      ..remove('created_by');
    await _client.from('tasks').update(payload).eq('id', task.id);
    await _replaceChildren(task.id, draft, existingChecklist: task.checklist);
    if (updateTemplate && task.sourceTemplateId != null) {
      await _updateTemplate(task.sourceTemplateId!, draft);
    }
  }

  Map<String, dynamic> _taskPayload(
    TaskDraft draft, {
    String? sourceTemplateId,
  }) => {
    'title': draft.title.trim(),
    'description': draft.description.trim(),
    'status': draft.status.value,
    'priority': draft.priority.value,
    'category_id': draft.categoryId,
    'due_at': draft.dueAt?.toUtc().toIso8601String(),
    'reminder_at': draft.reminderAt?.toUtc().toIso8601String(),
    'created_by': currentUserId,
    'updated_by': currentUserId,
    'archived_at': draft.status == TaskStatus.archived
        ? DateTime.now().toUtc().toIso8601String()
        : null,
    'source_template_id': sourceTemplateId,
  };

  Future<void> setStatus(TaskRecord task, TaskStatus status) async {
    await _client
        .from('tasks')
        .update({
          'status': status.value,
          'archived_at': status == TaskStatus.archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'updated_by': currentUserId,
        })
        .eq('id', task.id);
  }

  Future<void> _replaceChildren(
    String taskId,
    TaskDraft draft, {
    List<TaskChecklistItem> existingChecklist = const [],
  }) async {
    await _client.from('task_assignees').delete().eq('task_id', taskId);
    if (draft.assigneeIds.isNotEmpty) {
      await _client
          .from('task_assignees')
          .insert(
            draft.assigneeIds
                .map((id) => {'task_id': taskId, 'user_id': id})
                .toList(),
          );
    }
    final completionByIndex = <int, bool>{
      for (var i = 0; i < existingChecklist.length; i++)
        i: existingChecklist[i].done,
    };
    await _client.from('task_checklist_items').delete().eq('task_id', taskId);
    if (draft.checklist.isNotEmpty) {
      await _client
          .from('task_checklist_items')
          .insert(
            draft.checklist
                .asMap()
                .entries
                .where((entry) => entry.value.trim().isNotEmpty)
                .map(
                  (entry) => {
                    'task_id': taskId,
                    'label': entry.value.trim(),
                    'is_done': completionByIndex[entry.key] ?? false,
                    'sort_order': entry.key,
                  },
                )
                .toList(),
          );
    }
  }

  Future<String> _createTemplate(TaskDraft draft) async {
    final template = await _client
        .from('task_templates')
        .insert({
          'title': draft.title.trim(),
          'description': draft.description.trim(),
          'category_id': draft.categoryId,
          'priority': draft.priority.value,
          'created_by': currentUserId,
          'updated_by': currentUserId,
          ..._templateTiming(draft),
        })
        .select('id')
        .single();
    final id = template['id'] as String;
    if (draft.assigneeIds.isNotEmpty) {
      await _client
          .from('task_template_assignees')
          .insert(
            draft.assigneeIds
                .map((userId) => {'template_id': id, 'user_id': userId})
                .toList(),
          );
    }
    final checklist = draft.checklist
        .asMap()
        .entries
        .where((e) => e.value.trim().isNotEmpty)
        .map(
          (e) => {
            'template_id': id,
            'label': e.value.trim(),
            'sort_order': e.key,
          },
        )
        .toList();
    if (checklist.isNotEmpty) {
      await _client.from('task_template_checklist_items').insert(checklist);
    }
    return id;
  }

  Future<void> _updateTemplate(String id, TaskDraft draft) async {
    await _client
        .from('task_templates')
        .update({
          'title': draft.title.trim(),
          'description': draft.description.trim(),
          'category_id': draft.categoryId,
          'priority': draft.priority.value,
          'updated_by': currentUserId,
          ..._templateTiming(draft),
        })
        .eq('id', id);
    await _client
        .from('task_template_assignees')
        .delete()
        .eq('template_id', id);
    if (draft.assigneeIds.isNotEmpty) {
      await _client
          .from('task_template_assignees')
          .insert(
            draft.assigneeIds
                .map((userId) => {'template_id': id, 'user_id': userId})
                .toList(),
          );
    }
    await _client
        .from('task_template_checklist_items')
        .delete()
        .eq('template_id', id);
    final checklist = draft.checklist
        .asMap()
        .entries
        .where((e) => e.value.trim().isNotEmpty)
        .map(
          (e) => {
            'template_id': id,
            'label': e.value.trim(),
            'sort_order': e.key,
          },
        )
        .toList();
    if (checklist.isNotEmpty) {
      await _client.from('task_template_checklist_items').insert(checklist);
    }
  }

  Map<String, dynamic> _templateTiming(TaskDraft draft) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return {
      'due_offset_days': draft.dueAt == null
          ? null
          : DateTime(
              draft.dueAt!.year,
              draft.dueAt!.month,
              draft.dueAt!.day,
            ).difference(today).inDays.clamp(-36500, 36500).toInt(),
      'reminder_offset_minutes': draft.reminderAt == null
          ? null
          : (draft.dueAt == null
                    ? draft.reminderAt!.difference(now)
                    : draft.dueAt!.difference(draft.reminderAt!))
                .inMinutes
                .clamp(-5256000, 5256000)
                .toInt(),
    };
  }

  Future<void> createCategory(String name) async =>
      _client.from('task_categories').insert({'name': name.trim()});
  Future<void> archiveCategory(String id) async => _client
      .from('task_categories')
      .update({'archived_at': DateTime.now().toUtc().toIso8601String()})
      .eq('id', id);
  Future<void> restoreCategory(String id) async => _client
      .from('task_categories')
      .update({'archived_at': null})
      .eq('id', id);

  Future<void> createFromTemplate(
    Map<String, dynamic> template,
    DateTime? dueAt,
  ) async {
    final assignees =
        (template['task_template_assignees'] as List<dynamic>? ?? const [])
            .map((row) => (row as Map<String, dynamic>)['user_id'] as String)
            .toList();
    final checklist =
        (template['task_template_checklist_items'] as List<dynamic>? ??
                const [])
            .map((row) => (row as Map<String, dynamic>)['label'] as String)
            .toList();
    final offsets = template['due_offset_days'] as int?;
    final effectiveDue =
        dueAt ??
        (offsets == null ? null : DateTime.now().add(Duration(days: offsets)));
    final reminderMins = template['reminder_offset_minutes'] as int?;
    final draft = TaskDraft(
      title: template['title'] as String,
      description: template['description'] as String? ?? '',
      status: TaskStatus.toDo,
      priority: TaskPriorityLabel.parse(template['priority'] as String),
      categoryId: template['category_id'] as String?,
      assigneeIds: assignees,
      checklist: checklist,
      dueAt: effectiveDue,
      reminderAt: reminderMins == null
          ? null
          : effectiveDue == null
          ? DateTime.now().add(Duration(minutes: reminderMins))
          : effectiveDue.subtract(Duration(minutes: reminderMins)),
      sourceTemplateId: template['id'] as String,
    );
    await create(draft);
  }

  Future<void> addImage(
    String taskId,
    Uint8List bytes, {
    int? width,
    int? height,
  }) async {
    final householdId = await _client
        .from('profiles')
        .select('household_id')
        .eq('id', currentUserId)
        .single()
        .then((row) => row['household_id'] as String);
    final path =
        '$householdId/tasks/$taskId/${DateTime.now().microsecondsSinceEpoch}.jpg';
    await _client.storage
        .from('household-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    try {
      await _client.from('task_images').insert({
        'task_id': taskId,
        'storage_path': path,
        'size_bytes': bytes.length,
        'width': width,
        'height': height,
        'created_by': currentUserId,
      });
    } catch (_) {
      await _client.storage.from('household-media').remove([path]);
      rethrow;
    }
  }

  Future<List<(String, String)>> images(String taskId) async {
    final rows = await _client
        .from('task_images')
        .select('id,storage_path')
        .eq('task_id', taskId)
        .isFilter('removed_at', null);
    final result = <(String, String)>[];
    for (final row in rows) {
      final path = row['storage_path'] as String;
      final signed = await _client.storage
          .from('household-media')
          .createSignedUrl(path, 3600);
      result.add((row['id'] as String, signed));
    }
    return result;
  }

  Future<void> removeImage(String id) async {
    final row = await _client
        .from('task_images')
        .select('storage_path')
        .eq('id', id)
        .single();
    await _client.storage.from('household-media').remove([
      row['storage_path'] as String,
    ]);
    await _client
        .from('task_images')
        .update({'removed_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> toggleChecklist(String id, bool done) async => _client
      .from('task_checklist_items')
      .update({'is_done': done})
      .eq('id', id);
}
