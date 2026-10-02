import 'package:flutter/material.dart';

import '../domain/task.dart';

class TaskListFilters extends StatelessWidget {
  const TaskListFilters({
    required this.selectedStatus,
    required this.selectedCategoryId,
    required this.categories,
    required this.archivedCount,
    required this.showingArchived,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onArchivedPressed,
    required this.onAddCategory,
    required this.onManageCategories,
    super.key,
  });

  final TaskStatus? selectedStatus;
  final String? selectedCategoryId;
  final List<TaskCategory> categories;
  final int archivedCount;
  final bool showingArchived;
  final ValueChanged<TaskStatus?> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onArchivedPressed;
  final VoidCallback onAddCategory;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    final hasStatus = selectedStatus != null && !showingArchived;
    final hasCategory = selectedCategoryId != null;
    final categoryName =
        categories.where((c) => c.id == selectedCategoryId).firstOrNull?.name ??
        'Category';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OutlinedButton.icon(
                key: const ValueKey('task-filters'),
                onPressed: () => _open(context),
                icon: const Icon(Icons.filter_list),
                label: const Text('Filters'),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                tooltip: 'Category actions',
                icon: const Icon(Icons.category_outlined),
                onSelected: (value) =>
                    value == 'add' ? onAddCategory() : onManageCategories(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'add', child: Text('Add category')),
                  PopupMenuItem(
                    value: 'manage',
                    child: Text('Manage categories'),
                  ),
                ],
              ),
              IconButton(
                key: const ValueKey('archived-tasks-filter'),
                tooltip: showingArchived
                    ? 'Show active tasks'
                    : 'Archived ($archivedCount)',
                onPressed: onArchivedPressed,
                icon: Icon(
                  showingArchived
                      ? Icons.list_alt_outlined
                      : Icons.archive_outlined,
                ),
              ),
            ],
          ),
          if (showingArchived)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Archived tasks'),
            ),
          if (hasStatus || hasCategory)
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (hasStatus)
                  InputChip(
                    key: const ValueKey('clear-status-filter'),
                    label: Text(selectedStatus!.label),
                    onDeleted: () => onStatusChanged(null),
                  ),
                if (hasCategory)
                  InputChip(
                    key: const ValueKey('clear-category-filter'),
                    label: Text(categoryName),
                    onDeleted: () => onCategoryChanged(null),
                  ),
                TextButton(
                  onPressed: () {
                    if (!showingArchived) onStatusChanged(null);
                    onCategoryChanged(null);
                  },
                  child: const Text('Clear all'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    var status = selectedStatus;
    var category = selectedCategoryId;
    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter tasks'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!showingArchived) ...[
                    const Text('Status'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final item in [
                          TaskStatus.toDo,
                          TaskStatus.inProgress,
                          TaskStatus.done,
                        ])
                          FilterChip(
                            key: ValueKey('status-filter-${item.value}'),
                            label: Text(item.label),
                            selected: status == item,
                            onSelected: (selected) =>
                                setState(() => status = selected ? item : null),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        key: const ValueKey('category-filter-all'),
                        label: const Text('All categories'),
                        selected: category == null,
                        onSelected: (_) => setState(() => category = null),
                      ),
                      for (final item in categories)
                        FilterChip(
                          key: ValueKey('category-filter-${item.id}'),
                          label: Text(item.name),
                          selected: category == item.id,
                          onSelected: (selected) => setState(
                            () => category = selected ? item.id : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => setState(() {
                status = null;
                category = null;
              }),
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    );
    if (applied != true || !context.mounted) return;
    if (!showingArchived) onStatusChanged(status);
    onCategoryChanged(category);
  }
}
