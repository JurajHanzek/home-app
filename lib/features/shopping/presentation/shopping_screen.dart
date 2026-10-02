import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../meals/domain/meal.dart';
import '../data/shopping_repository.dart';
import '../domain/shopping.dart';

enum _ShoppingSection { nextMeals, general }

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  final _newItem = TextEditingController();
  _ShoppingSection _section = _ShoppingSection.nextMeals;
  bool _showArchived = false;
  bool _saving = false;

  @override
  void dispose() {
    _newItem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shoppingProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<_ShoppingSection>(
            segments: const [
              ButtonSegment(
                value: _ShoppingSection.nextMeals,
                icon: Icon(Icons.restaurant_outlined),
                label: Text('Next 2 meals'),
              ),
              ButtonSegment(
                value: _ShoppingSection.general,
                icon: Icon(Icons.shopping_basket_outlined),
                label: Text('General'),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (values) => setState(() {
              _section = values.first;
              _showArchived = false;
            }),
            showSelectedIcon: false,
          ),
        ),
        Expanded(
          child: state.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ShoppingError(onRetry: _reload),
            data: (data) => _section == _ShoppingSection.nextMeals
                ? _nextMeals(data)
                : _generalList(data),
          ),
        ),
      ],
    );
  }

  Widget _nextMeals(ShoppingData data) {
    final groups = data.nextMealGroups(now: DateTime.now());
    if (groups.isEmpty) {
      return const _ShoppingEmpty(
        icon: Icons.event_busy_outlined,
        title: 'No upcoming meals',
        detail: 'Plan a meal to see its missing ingredients here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Missing ingredients for your next meals',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final group in groups) _mealGroup(group),
        ],
      ),
    );
  }

  Widget _mealGroup(MealShoppingGroup group) {
    final meal = group.meal;
    final date = meal.plannedAt.toLocal();
    final dateLabel = _mealDate(date, DateTime.now());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meal.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              '$dateLabel${meal.hasTime ? ' · ${_mealTime(date)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 18),
            if (group.missingItems.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Nothing left to pick up for this meal'),
                    ),
                  ],
                ),
              )
            else
              for (final item in group.missingItems)
                CheckboxListTile(
                  key: ValueKey('meal-${meal.id}-ingredient-${item.id}'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: false,
                  title: Text(item.label),
                  subtitle: item.quantity == null && item.unit == null
                      ? null
                      : Text(
                          [item.quantity, item.unit]
                              .whereType<String>()
                              .where((value) => value.isNotEmpty)
                              .join(' '),
                        ),
                  onChanged: _saving
                      ? null
                      : (value) => _setMealIngredient(item, value ?? true),
                ),
          ],
        ),
      ),
    );
  }

  Widget _generalList(ShoppingData data) {
    final items =
        data.generalItems
            .where((item) => item.isArchived == _showArchived)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final active = items.where((item) => !item.isDone).toList();
    final done = items.where((item) => item.isDone).toList();
    final archivedCount = data.generalItems
        .where((item) => item.isArchived)
        .length;
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _showArchived ? 'Archived items' : 'Household list',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showArchived = !_showArchived),
                icon: Icon(
                  _showArchived ? Icons.arrow_back : Icons.inventory_2_outlined,
                ),
                label: Text(
                  _showArchived ? 'Active list' : 'Archived ($archivedCount)',
                ),
              ),
            ],
          ),
          if (!_showArchived) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newItem,
                    enabled: !_saving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addGeneralItem(),
                    decoration: const InputDecoration(
                      hintText: 'Add an item',
                      prefixIcon: Icon(Icons.add),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Add item',
                  onPressed: _saving ? null : _addGeneralItem,
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (active.isEmpty && done.isEmpty)
              const _ShoppingEmpty(
                icon: Icons.shopping_basket_outlined,
                title: 'Your list is empty',
                detail: 'Add something you need for the household.',
              )
            else ...[
              for (final item in active) _generalRow(item),
              if (done.isNotEmpty)
                Card(
                  child: ExpansionTile(
                    initiallyExpanded: false,
                    title: Text('Completed (${done.length})'),
                    children: [for (final item in done) _generalRow(item)],
                  ),
                ),
            ],
          ] else if (items.isEmpty)
            const _ShoppingEmpty(
              icon: Icons.inventory_2_outlined,
              title: 'No archived items',
              detail: 'Archived shopping items will appear here.',
            )
          else
            for (final item in items) _generalRow(item),
        ],
      ),
    );
  }

  Widget _generalRow(GeneralShoppingItem item) => Card(
    margin: const EdgeInsets.only(bottom: 6),
    child: CheckboxListTile(
      key: ValueKey('general-${item.id}'),
      dense: true,
      value: item.isDone,
      onChanged: _saving || _showArchived
          ? null
          : (value) => _setGeneralDone(item.id, value ?? false),
      title: Text(
        item.label,
        style: item.isDone
            ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      secondary: PopupMenuButton<String>(
        tooltip: 'Item options',
        onSelected: (value) {
          if (value == 'edit') _editGeneralItem(item);
          if (value == 'archive') _archiveGeneralItem(item, true);
          if (value == 'restore') _archiveGeneralItem(item, false);
        },
        itemBuilder: (_) => item.isArchived
            ? const [PopupMenuItem(value: 'restore', child: Text('Restore'))]
            : [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
      ),
    ),
  );

  Future<void> _addGeneralItem() async {
    final label = _newItem.text;
    if (label.trim().isEmpty) return;
    await _mutate(
      () => ref.read(shoppingRepositoryProvider).addGeneralItem(label),
      success: () => _newItem.clear(),
      failureMessage: 'Could not add this item. Try again.',
    );
  }

  Future<void> _editGeneralItem(GeneralShoppingItem item) async {
    final controller = TextEditingController(text: item.label);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit shopping item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Item'),
          onSubmitted: (_) => Navigator.pop(context, controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || updated.trim().isEmpty || updated == item.label) {
      return;
    }
    await _mutate(
      () => ref
          .read(shoppingRepositoryProvider)
          .renameGeneralItem(item.id, updated),
      failureMessage: 'Could not update this item. Try again.',
    );
  }

  Future<void> _setGeneralDone(String id, bool done) => _mutate(
    () => ref.read(shoppingRepositoryProvider).setGeneralItemDone(id, done),
    failureMessage: 'Could not update this item. Try again.',
  );

  Future<void> _archiveGeneralItem(GeneralShoppingItem item, bool archived) =>
      _mutate(
        () => ref
            .read(shoppingRepositoryProvider)
            .setGeneralItemArchived(item.id, archived),
        failureMessage: archived
            ? 'Could not archive this item.'
            : 'Could not restore this item.',
      );

  Future<void> _setMealIngredient(IngredientRecord item, bool have) => _mutate(
    () => ref
        .read(shoppingRepositoryProvider)
        .setMealIngredientHave(item.id, have),
    failureMessage: 'Could not update this meal ingredient. Try again.',
  );

  Future<void> _mutate(
    Future<void> Function() action, {
    VoidCallback? success,
    required String failureMessage,
  }) async {
    setState(() => _saving = true);
    try {
      await action();
      success?.call();
      ref.invalidate(shoppingProvider);
    } catch (_) {
      if (mounted) _message(failureMessage);
      ref.invalidate(shoppingProvider);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reload() async {
    try {
      await ref.refresh(shoppingProvider.future).then<void>((_) {});
    } catch (_) {
      // The provider displays the retry state.
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _ShoppingEmpty extends StatelessWidget {
  const _ShoppingEmpty({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(detail, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _ShoppingError extends StatelessWidget {
  const _ShoppingError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          const Text(
            'Shopping could not be loaded. Check your connection and try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _mealDate(DateTime date, DateTime now) {
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Today';
  if (day == today.add(const Duration(days: 1))) return 'Tomorrow';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String _mealTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
