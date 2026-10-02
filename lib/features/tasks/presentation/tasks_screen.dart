import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../data/task_image_picker.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'task_filters.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.detailId});
  final String? detailId;
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskStatus? _status;
  String? _categoryId;
  bool _showArchived = false;

  Future<void> _reload() async {
    try {
      await ref.refresh(tasksProvider.future).then<void>((_) {});
    } catch (_) {
      // The provider exposes the failure to the error/retry UI. A retry tap
      // should not also leak the same backend exception to Flutter's zone.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasksProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorPane(
        message:
            'Tasks could not be loaded. Check the connection and confirm the Phase 2 database migration is applied.',
        onRetry: _reload,
      ),
      data: (data) => _board(context, data),
    );
  }

  Widget _board(BuildContext context, TaskBoardData data) {
    if (widget.detailId != null) {
      final task = data.tasks
          .where((item) => item.id == widget.detailId)
          .firstOrNull;
      if (task == null) {
        return const Center(child: Text('Task no longer available'));
      }
      return _TaskDetails(
        task: task,
        data: data,
        repository: ref.read(taskRepositoryProvider),
        onEdit: () => _edit(data, task: task),
        onStatus: (status) => _changeStatus(task, status),
        onChanged: _reload,
      );
    }
    final visible = filterTaskRecords(
      data.tasks,
      status: _status,
      categoryId: _categoryId,
      archivedOnly: _showArchived,
    );
    final activeCategories = data.categories
        .where((category) => !category.archived)
        .toList();
    return Stack(
      children: [
        Column(
          children: [
            TaskListFilters(
              selectedStatus: _status,
              selectedCategoryId: _categoryId,
              categories: activeCategories,
              archivedCount: data.tasks
                  .where((task) => task.status == TaskStatus.archived)
                  .length,
              showingArchived: _showArchived,
              onStatusChanged: (status) => setState(() {
                _status = status;
                _showArchived = false;
              }),
              onCategoryChanged: (id) => setState(() {
                _categoryId = id;
              }),
              onArchivedPressed: () =>
                  setState(() => _showArchived = !_showArchived),
              onAddCategory: () => _addCategory(data),
              onManageCategories: () => _manageCategories(data),
            ),
            if (data.templates.isNotEmpty && !_showArchived)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 4),
                  child: TextButton.icon(
                    onPressed: () => _useTemplate(data),
                    icon: const Icon(Icons.repeat, size: 18),
                    label: const Text('Create from template'),
                  ),
                ),
              ),
            Expanded(
              child: visible.isEmpty
                  ? _EmptyTasks(archived: _showArchived)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                        itemCount: visible.length,
                        itemBuilder: (context, index) => TaskCard(
                          task: visible[index],
                          data: data,
                          onTap: () => _details(visible[index], data),
                          onStatus: (status) =>
                              _changeStatus(visible[index], status),
                        ),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                      ),
                    ),
            ),
          ],
        ),
        if (!_showArchived)
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: () => _edit(data),
              icon: const Icon(Icons.add),
              label: const Text('New task'),
            ),
          ),
      ],
    );
  }

  Future<void> _changeStatus(TaskRecord task, TaskStatus status) async {
    if (status == TaskStatus.archived &&
        !await _confirm('Archive task?', 'You can restore this task later.')) {
      return;
    }
    try {
      await ref.read(taskRepositoryProvider).setStatus(task, status);
      await _reload();
    } catch (_) {
      if (mounted) _snack('Could not update the task. Try again.');
    }
  }

  Future<void> _edit(TaskBoardData data, {TaskRecord? task}) async {
    final saved = await showDialog<_TaskFormResult>(
      context: context,
      builder: (_) => _TaskEditor(data: data, task: task),
    );
    if (saved == null) return;
    var taskSaved = false;
    try {
      final repo = ref.read(taskRepositoryProvider);
      if (task == null) {
        final id = await repo.create(
          saved.draft,
          makeTemplate: saved.makeTemplate,
        );
        taskSaved = true;
        if (mounted) {
          setState(() {
            _status = null;
            _categoryId = null;
            _showArchived = false;
          });
        }
        if (saved.image != null) {
          await repo.addImage(
            id,
            saved.image!.bytes,
            width: saved.image!.width,
            height: saved.image!.height,
          );
        }
      } else {
        await repo.update(
          task,
          saved.draft,
          updateTemplate: saved.updateTemplate,
        );
        taskSaved = true;
        if (saved.image != null) {
          await repo.addImage(
            task.id,
            saved.image!.bytes,
            width: saved.image!.width,
            height: saved.image!.height,
          );
        }
      }
      await _reload();
    } catch (_) {
      // Child rows are saved sequentially. Even if a later insert fails, the
      // parent task can already exist, so always refetch to reveal partial
      // success instead of leaving the list stale.
      if (task == null && mounted) {
        setState(() {
          _status = null;
          _categoryId = null;
          _showArchived = false;
        });
      }
      await _reload();
      if (mounted) {
        _snack(
          taskSaved
              ? 'Task saved, but its image could not be uploaded.'
              : 'Could not save the task. Check your connection and try again.',
        );
      }
    }
  }

  Future<void> _details(TaskRecord task, TaskBoardData data) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _TaskDetails(
        task: task,
        data: data,
        repository: ref.read(taskRepositoryProvider),
        onEdit: () {
          Navigator.pop(dialogContext);
          _edit(data, task: task);
        },
        onStatus: (status) {
          Navigator.pop(dialogContext);
          _changeStatus(task, status);
        },
        onChanged: _reload,
      ),
    );
  }

  Future<void> _addCategory(TaskBoardData data) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New task category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'Category name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(taskRepositoryProvider).createCategory(name);
      await _reload();
    } catch (_) {
      if (mounted) _snack('That category could not be added.');
    }
  }

  Future<void> _manageCategories(TaskBoardData data) async {
    final selected = await showDialog<(String, bool)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage categories'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: data.categories
                  .map(
                    (category) => ListTile(
                      title: Text(category.name),
                      subtitle: Text(category.archived ? 'Archived' : 'Active'),
                      trailing: TextButton(
                        onPressed: () => Navigator.pop(context, (
                          category.id,
                          category.archived,
                        )),
                        child: Text(category.archived ? 'Restore' : 'Archive'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (selected != null) {
      try {
        final repository = ref.read(taskRepositoryProvider);
        if (selected.$2) {
          await repository.restoreCategory(selected.$1);
        } else if (await _confirm(
          'Archive category?',
          'Existing tasks keep this category.',
        )) {
          await repository.archiveCategory(selected.$1);
        }
        await _reload();
      } catch (_) {
        if (mounted) _snack('Could not update category.');
      }
    }
  }

  Future<void> _useTemplate(TaskBoardData data) async {
    final template = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Create from template')),
            ...data.templates.map(
              (item) => ListTile(
                leading: const Icon(Icons.repeat),
                title: Text(item['title'] as String),
                subtitle: Text(item['description'] as String? ?? ''),
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );
    if (template == null) return;
    try {
      await ref.read(taskRepositoryProvider).createFromTemplate(template, null);
      await _reload();
    } catch (_) {
      if (mounted) _snack('Could not create a task from this template.');
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      ) ??
      false;

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.data,
    required this.onTap,
    required this.onStatus,
    super.key,
  });
  final TaskRecord task;
  final TaskBoardData data;
  final VoidCallback onTap;
  final ValueChanged<TaskStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final assignees = task.assigneeIds
        .map((id) {
          for (final person in data.people) {
            if (person.id == id) return person.initials;
          }
          return null;
        })
        .whereType<String>()
        .join(' · ');
    final done = task.checklist.where((item) => item.done).length;
    final flower = Theme.of(context).brightness == Brightness.light;
    final statusColors = Theme.of(context).extension<TaskStatusColors>()!;
    final statusColor = switch (task.status) {
      TaskStatus.toDo => statusColors.toDo,
      TaskStatus.inProgress => statusColors.inProgress,
      TaskStatus.done || TaskStatus.archived => statusColors.done,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      color: flower ? const Color(0xFFF9FCEF) : null,
      child: Stack(
        children: [
          if (flower)
            Positioned(
              right: 42,
              bottom: -20,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Icon(
                      Icons.local_florist,
                      size: 82,
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.065),
                    ),
                  ),
                ),
              ),
            ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  label: 'Status: ${task.status.label}',
                  child: Container(
                    width: flower ? 4 : 8,
                    margin: flower
                        ? const EdgeInsets.fromLTRB(10, 18, 0, 18)
                        : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(flower ? 4 : 0),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: onTap,
                    child: Padding(
                      padding: flower
                          ? const EdgeInsets.fromLTRB(12, 10, 4, 14)
                          : const EdgeInsets.fromLTRB(12, 7, 4, 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(
                                    alpha: flower ? 0.09 : 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    flower ? 24 : 8,
                                  ),
                                  border: flower
                                      ? null
                                      : Border.all(
                                          color: statusColor.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                ),
                                child: Text(
                                  task.status.label,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: statusColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              PopupMenuButton<TaskStatus>(
                                tooltip: 'Move task',
                                padding: EdgeInsets.zero,
                                onSelected: onStatus,
                                itemBuilder: (_) => [
                                  for (final status in TaskStatus.values.where(
                                    (s) => s != task.status,
                                  ))
                                    PopupMenuItem(
                                      value: status,
                                      child: Text(
                                        status == TaskStatus.archived
                                            ? 'Archive'
                                            : status == TaskStatus.toDo &&
                                                  task.status ==
                                                      TaskStatus.archived
                                            ? 'Restore'
                                            : 'Move to ${status.label}',
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 12,
                            runSpacing: 2,
                            children: [
                              if (task.categoryName != null)
                                _TaskMeta(
                                  Icons.label_outline,
                                  task.categoryName!,
                                ),
                              _TaskMeta(
                                _priorityIcon(task.priority),
                                task.priority.label,
                              ),
                              if (task.dueAt != null)
                                _TaskMeta(
                                  Icons.event_outlined,
                                  _date(task.dueAt!),
                                ),
                              if (assignees.isNotEmpty)
                                _TaskMeta(Icons.person_outline, assignees),
                              if (task.checklist.isNotEmpty)
                                _TaskMeta(
                                  Icons.checklist,
                                  '$done/${task.checklist.length}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 3),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.archived});
  final bool archived;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(archived ? Icons.archive_outlined : Icons.task_alt, size: 48),
          const SizedBox(height: 12),
          Text(
            archived ? 'No archived tasks' : 'No tasks match these filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            archived
                ? 'Archived tasks will appear here.'
                : 'Clear a filter or add a task to see it here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cloud_off_outlined, size: 44),
        const SizedBox(height: 12),
        Text(message),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}

class _TaskFormResult {
  const _TaskFormResult(
    this.draft, {
    this.makeTemplate = false,
    this.updateTemplate = false,
    this.image,
  });
  final TaskDraft draft;
  final bool makeTemplate, updateTemplate;
  final PreparedTaskImage? image;
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({required this.data, this.task});
  final TaskBoardData data;
  final TaskRecord? task;
  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  late final TextEditingController _title, _description, _checklist;
  late TaskStatus _status;
  late TaskPriority _priority;
  String? _categoryId, _imageLabel;
  final List<String> _assignees = [];
  DateTime? _dueAt, _reminderAt;
  bool _makeTemplate = false,
      _updateTemplate = false,
      _reminderEnabled = false,
      _busy = false;
  PreparedTaskImage? _image;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title ?? '');
    _description = TextEditingController(text: task?.description ?? '');
    _checklist = TextEditingController(
      text: task?.checklist.map((item) => item.label).join('\n') ?? '',
    );
    _status = task?.status ?? TaskStatus.toDo;
    _priority = task?.priority ?? TaskPriority.normal;
    _categoryId = task?.categoryId;
    _assignees.addAll(task?.assigneeIds ?? const []);
    _dueAt = task?.dueAt;
    _reminderAt = task?.reminderAt;
    _reminderEnabled = task?.reminderAt != null;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _checklist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.data.categories
        .where((category) => !category.archived || category.id == _categoryId)
        .toList();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(widget.task == null ? 'New task' : 'Edit task'),
      titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            spacing: 14,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Title *'),
              ),
              TextField(
                controller: _description,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Shared description',
                ),
              ),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('No category'),
                  ),
                  ...categories.map(
                    (c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.archived ? '${c.name} (archived)' : c.name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: TaskStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: TaskPriority.values
                    .map(
                      (p) => DropdownMenuItem(value: p, child: Text(p.label)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 14),
                  child: Text('Assigned to (up to two)'),
                ),
              ),
              Wrap(
                spacing: 6,
                children: widget.data.people
                    .map(
                      (person) => FilterChip(
                        label: Text(person.name),
                        selected: _assignees.contains(person.id),
                        onSelected: (selected) => setState(() {
                          if (selected && _assignees.length < 2) {
                            _assignees.add(person.id);
                          } else if (!selected) {
                            _assignees.remove(person.id);
                          }
                        }),
                      ),
                    )
                    .toList(),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueAt == null ? 'No due date' : 'Due ${_date(_dueAt!)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDue,
                    child: Text(_dueAt == null ? 'Set date' : 'Change'),
                  ),
                  if (_dueAt != null)
                    IconButton(
                      tooltip: 'Clear due date',
                      onPressed: () => setState(() {
                        _dueAt = null;
                        _reminderEnabled = false;
                        _reminderAt = null;
                      }),
                      icon: const Icon(Icons.clear),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                subtitle: Text(
                  _reminderAt == null
                      ? 'No reminder set (delivery is not active yet)'
                      : _dateTime(_reminderAt!),
                ),
                value: _reminderEnabled,
                onChanged: (value) async {
                  setState(() => _reminderEnabled = value);
                  if (value) await _pickReminder();
                },
              ),
              TextField(
                controller: _checklist,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Checklist',
                  hintText: 'One item per line',
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _imageLabel ?? 'Add task image (compressed on device)',
                ),
              ),
              if (widget.task == null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Save as repetitive task template'),
                  value: _makeTemplate,
                  onChanged: (value) =>
                      setState(() => _makeTemplate = value ?? false),
                ),
              if (widget.task?.sourceTemplateId != null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Also update reusable template'),
                  subtitle: const Text('Off by default'),
                  value: _updateTemplate,
                  onChanged: (value) =>
                      setState(() => _updateTemplate = value ?? false),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(
        () => _dueAt = DateTime(picked.year, picked.month, picked.day, 9),
      );
    }
  }

  Future<void> _pickReminder() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _reminderAt ?? now,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked == null) {
      setState(() => _reminderEnabled = false);
      return;
    }
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _reminderAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time != null) {
      setState(
        () => _reminderAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await TaskImagePicker.pick();
      if (image != null) {
        setState(() {
          _image = image;
          _imageLabel =
              'Image ready (${(image.bytes.length / 1024).round()} KB)';
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare this image.')),
        );
      }
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    if (_assignees.length > 2) return;
    setState(() => _busy = true);
    final draft = TaskDraft(
      title: _title.text,
      description: _description.text,
      status: _status,
      priority: _priority,
      categoryId: _categoryId,
      assigneeIds: List.of(_assignees),
      checklist: _checklist.text
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList(),
      dueAt: _dueAt,
      reminderAt: _reminderEnabled ? _reminderAt : null,
    );
    Navigator.pop(
      context,
      _TaskFormResult(
        draft,
        makeTemplate: _makeTemplate,
        updateTemplate: _updateTemplate,
        image: _image,
      ),
    );
  }
}

class _TaskDetails extends StatefulWidget {
  const _TaskDetails({
    required this.task,
    required this.data,
    required this.repository,
    required this.onEdit,
    required this.onStatus,
    required this.onChanged,
  });
  final TaskRecord task;
  final TaskBoardData data;
  final TaskRepository repository;
  final VoidCallback onEdit, onChanged;
  final ValueChanged<TaskStatus> onStatus;
  @override
  State<_TaskDetails> createState() => _TaskDetailsState();
}

class _TaskDetailsState extends State<_TaskDetails> {
  List<(String, String)> _images = [];
  late final Map<String, bool> _checkStatus;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _checkStatus = {
      for (final item in widget.task.checklist) item.id: item.done,
    };
    _loadImages();
  }

  Future<void> _loadImages() async {
    try {
      final photos = await widget.repository.images(widget.task.id);
      if (mounted) {
        setState(() {
          _images = photos;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignees = widget.data.people
        .where((person) => widget.task.assigneeIds.contains(person.id))
        .map((p) => p.name)
        .join(', ');
    final messenger = ScaffoldMessenger.of(context);
    return AlertDialog(
      title: Text(widget.task.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.task.description.isEmpty
                    ? 'No description'
                    : widget.task.description,
              ),
              const SizedBox(height: 12),
              Text(
                '${widget.task.status.label} · ${widget.task.priority.label}',
              ),
              if (widget.task.categoryName != null)
                Text('Category: ${widget.task.categoryName}'),
              if (assignees.isNotEmpty) Text('Assigned to: $assignees'),
              if (widget.task.dueAt != null)
                Text('Due: ${_date(widget.task.dueAt!)}'),
              if (widget.task.reminderAt != null)
                Text('Reminder: ${_dateTime(widget.task.reminderAt!)}'),
              const Divider(),
              const Text(
                'Checklist',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (widget.task.checklist.isEmpty)
                const Text('No checklist items'),
              ...widget.task.checklist.map(
                (item) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.label),
                  value: _checkStatus[item.id] ?? item.done,
                  onChanged: (value) async {
                    try {
                      await widget.repository.toggleChecklist(
                        item.id,
                        value ?? false,
                      );
                      if (!mounted) return;
                      setState(() => _checkStatus[item.id] = value ?? false);
                      widget.onChanged();
                    } catch (_) {
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Could not update checklist.'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
              const Divider(),
              const Text(
                'Task images',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _images.isEmpty)
                const Text('No images attached'),
              if (_images.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: _images
                      .map(
                        (image) => Stack(
                          alignment: Alignment.topRight,
                          children: [
                            Image.network(
                              image.$2,
                              width: 92,
                              height: 92,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image),
                            ),
                            IconButton(
                              onPressed: () async {
                                try {
                                  await widget.repository.removeImage(image.$1);
                                  await _loadImages();
                                  widget.onChanged();
                                } catch (_) {
                                  if (mounted) {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not remove image.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
      actions: [
        PopupMenuButton<TaskStatus>(
          onSelected: widget.onStatus,
          itemBuilder: (_) => [
            if (widget.task.status == TaskStatus.archived)
              const PopupMenuItem(
                value: TaskStatus.toDo,
                child: Text('Restore to To Do'),
              )
            else
              const PopupMenuItem(
                value: TaskStatus.archived,
                child: Text('Archive'),
              ),
            ...[TaskStatus.toDo, TaskStatus.inProgress, TaskStatus.done]
                .where((status) => status != widget.task.status)
                .map(
                  (status) => PopupMenuItem(
                    value: status,
                    child: Text('Move to ${status.label}'),
                  ),
                ),
          ],
        ),
        TextButton(onPressed: widget.onEdit, child: const Text('Edit')),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

IconData _priorityIcon(TaskPriority priority) => switch (priority) {
  TaskPriority.low => Icons.south,
  TaskPriority.normal => Icons.remove,
  TaskPriority.high => Icons.priority_high,
  TaskPriority.urgent => Icons.keyboard_double_arrow_up,
};
String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _dateTime(DateTime value) =>
    '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
