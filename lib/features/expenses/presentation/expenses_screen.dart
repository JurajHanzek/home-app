import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/expenses_repository.dart';
import '../domain/expense.dart';
import 'expense_editor.dart';
import 'expense_filters.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key, this.detailId});
  final String? detailId;

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  bool _showArchived = false;
  ExpenseFilters _filters = const ExpenseFilters();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expensesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _ExpensesError(onRetry: _reload),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(ExpensesData data) {
    if (widget.detailId != null) {
      final expense = data.expenses
          .where((item) => item.id == widget.detailId)
          .firstOrNull;
      if (expense == null) {
        return const Center(child: Text('Expense no longer available'));
      }
      return _expenseDetails(
        data,
        expense,
        onEdit: () => _edit(data, expense: expense),
      );
    }
    final expenses =
        data.expenses
            .where(
              (item) =>
                  item.isArchived == _showArchived && _filters.matches(item),
            )
            .toList()
          ..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showArchived
                          ? 'Archived expenses'
                          : 'Household expenses',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    key: const Key('expense-categories'),
                    tooltip: 'Manage categories',
                    onPressed: () => _manageCategories(data),
                    icon: const Icon(Icons.category_outlined),
                  ),
                  IconButton(
                    tooltip: _showArchived
                        ? 'Show active expenses'
                        : 'Archived expenses',
                    onPressed: () =>
                        setState(() => _showArchived = !_showArchived),
                    icon: Icon(
                      _showArchived
                          ? Icons.receipt_long
                          : Icons.archive_outlined,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  key: const Key('expenses-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const Key('expense-filters'),
                        onPressed: () => _chooseFilters(data),
                        icon: const Icon(Icons.filter_list),
                        label: const Text('Filters'),
                      ),
                    ),
                    if (_filters.isActive) _filterChips(data),
                    const SizedBox(height: 12),
                    if (_filters.isActive)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Filtered total · ${expenses.length} ${expenses.length == 1 ? 'expense' : 'expenses'}',
                              ),
                              Text(
                                formatExpenseEur(
                                  expenses.fold<int>(
                                    0,
                                    (sum, item) => sum + item.amountCents,
                                  ),
                                ),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (!_showArchived)
                      _MonthlySummary(data: data),
                    if (expenses.isEmpty)
                      if (_filters.isActive)
                        const Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('No expenses match these filters.'),
                        )
                      else
                        _ExpensesEmpty(archived: _showArchived)
                    else
                      for (final expense in expenses)
                        _ExpenseCard(
                          expense: expense,
                          data: data,
                          onTap: () => _details(data, expense),
                          onEdit: () => _edit(data, expense: expense),
                          onArchive: () => _archive(expense, true),
                          onRestore: () => _archive(expense, false),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (!_showArchived)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              key: const Key('new-expense'),
              onPressed: () => _edit(data),
              icon: const Icon(Icons.add),
              label: const Text('New expense'),
            ),
          ),
      ],
    );
  }

  Future<void> _chooseFilters(ExpensesData data) async {
    final filters = await showExpenseFilters(
      context,
      data: data,
      filters: _filters,
    );
    if (filters != null && mounted) setState(() => _filters = filters);
  }

  Widget _filterChips(ExpensesData data) => Wrap(
    key: const Key('expense-active-filters'),
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (_filters.month != null)
        InputChip(
          label: Text(expenseMonthLabel(context, _filters.month!)),
          onDeleted: () => setState(
            () => _filters = ExpenseFilters(
              categoryId: _filters.categoryId,
              paidBy: _filters.paidBy,
              shared: _filters.shared,
            ),
          ),
        ),
      if (_filters.categoryId != null)
        InputChip(
          label: Text(data.category(_filters.categoryId!)?.name ?? 'Category'),
          onDeleted: () => setState(
            () => _filters = ExpenseFilters(
              month: _filters.month,
              paidBy: _filters.paidBy,
              shared: _filters.shared,
            ),
          ),
        ),
      if (_filters.paidBy != null)
        InputChip(
          label: Text(
            'Paid by: ${data.person(_filters.paidBy!)?.name ?? 'Household member'}',
          ),
          onDeleted: () => setState(
            () => _filters = ExpenseFilters(
              month: _filters.month,
              categoryId: _filters.categoryId,
              shared: _filters.shared,
            ),
          ),
        ),
      if (_filters.shared != null)
        InputChip(
          label: Text(_filters.shared! ? 'Shared' : 'Personal'),
          onDeleted: () => setState(
            () => _filters = ExpenseFilters(
              month: _filters.month,
              categoryId: _filters.categoryId,
              paidBy: _filters.paidBy,
            ),
          ),
        ),
      TextButton(
        onPressed: () => setState(() => _filters = const ExpenseFilters()),
        child: const Text('Clear all'),
      ),
    ],
  );

  Future<void> _details(ExpensesData data, ExpenseRecord expense) async {
    final edit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _expenseDetails(
        data,
        expense,
        onEdit: () => Navigator.pop(dialogContext, true),
      ),
    );
    if (edit == true && mounted) await _edit(data, expense: expense);
  }

  Widget _expenseDetails(
    ExpensesData data,
    ExpenseRecord expense, {
    required VoidCallback onEdit,
  }) => AlertDialog(
    title: Text(expense.title),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatExpenseEur(expense.amountCents),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Category: ${data.category(expense.categoryId)?.name ?? 'Other'}',
            ),
            Text(
              'Paid by: ${data.person(expense.paidBy)?.name ?? 'Household member'}',
            ),
            Text('Date: ${_formatDate(expense.expenseDate)}'),
            Text('Shared: ${expense.shared ? 'Yes' : 'No'}'),
            Text(
              'Created by: ${data.person(expense.createdBy)?.name ?? 'Household member'}',
            ),
            if (expense.isArchived) const Text('Archived'),
            if (expense.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(expense.note),
            ],
            const SizedBox(height: 12),
            if (expense.receiptUrl != null)
              InteractiveViewer(
                child: Image.network(
                  expense.receiptUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Text(
                    'Receipt unavailable. Refresh the ledger to retry.',
                  ),
                ),
              )
            else
              Text(
                expense.receiptPath == null
                    ? 'No receipt attached'
                    : 'Receipt unavailable. Refresh the ledger to retry.',
              ),
          ],
        ),
      ),
    ),
    actions: [
      if (expense.isArchived)
        TextButton(
          onPressed: () => _archive(expense, false),
          child: const Text('Restore'),
        ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(onPressed: onEdit, child: const Text('Edit expense')),
    ],
  );

  Future<void> _edit(ExpensesData data, {ExpenseRecord? expense}) async {
    final result = await showExpenseEditor(
      context,
      data: data,
      expense: expense,
    );
    if (result == null) return;
    try {
      final repository = ref.read(expensesRepositoryProvider);
      if (expense == null) {
        await repository.createExpense(result.draft, receipt: result.receipt);
      } else {
        await repository.updateExpense(
          expense,
          result.draft,
          receipt: result.receipt,
          removeReceipt: result.removeReceipt,
        );
      }
      await _reload();
    } on ExpenseReceiptSaveException {
      await _reload();
      if (mounted) {
        _message('Expense saved, but the receipt could not be uploaded.');
      }
    } catch (_) {
      await _reload();
      if (mounted) _message('Could not save the expense. Try again.');
    }
  }

  Future<void> _archive(ExpenseRecord expense, bool archived) async {
    if (archived &&
        !await _confirm(
          'Archive expense?',
          'This expense will leave the active ledger. You can restore it later.',
        )) {
      return;
    }
    try {
      await ref.read(expensesRepositoryProvider).setArchived(expense, archived);
      await _reload();
    } catch (_) {
      if (mounted) {
        _message(
          archived
              ? 'Could not archive the expense.'
              : 'Could not restore the expense.',
        );
      }
    }
  }

  Future<void> _manageCategories(ExpensesData data) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Expense categories'),
        content: SizedBox(
          width: 380,
          height: 420,
          child: ListView(
            children: [
              for (final category in data.categories)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: _parseColor(category.color),
                  ),
                  title: Text(category.name),
                  subtitle: Text(category.isArchived ? 'Archived' : 'Active'),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Category actions',
                    onSelected: (action) async {
                      if (action == 'edit') {
                        await _editCategory(category);
                      } else {
                        await _setCategoryArchived(
                          category,
                          !category.isArchived,
                        );
                      }
                      await _reload();
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                        value: category.isArchived ? 'restore' : 'archive',
                        child: Text(
                          category.isArchived ? 'Restore' : 'Archive',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await _editCategory(null);
              await _reload();
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add category'),
          ),
        ],
      ),
    );
  }

  Future<void> _editCategory(ExpenseCategory? category) async {
    final draft = await showExpenseCategoryEditor(context, category: category);
    if (draft == null) return;
    try {
      final repository = ref.read(expensesRepositoryProvider);
      if (category == null) {
        await repository.createCategory(draft);
      } else {
        await repository.updateCategory(category.id, draft);
      }
    } catch (_) {
      if (mounted) {
        _message('Could not save that category. Check for duplicate names.');
      }
    }
  }

  Future<void> _setCategoryArchived(
    ExpenseCategory category,
    bool archived,
  ) async {
    if (archived &&
        !await _confirm(
          'Archive category?',
          'Existing expenses keep this category. You can restore it later.',
        )) {
      return;
    }
    try {
      await ref
          .read(expensesRepositoryProvider)
          .setCategoryArchived(category, archived);
    } catch (_) {
      if (mounted) _message('Could not update the category.');
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

  Future<void> _reload() async {
    try {
      ref.invalidate(expensesProvider);
      await ref.read(expensesProvider.future);
    } catch (_) {
      // The provider exposes the retryable failure state.
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.data});
  final ExpensesData data;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final categories = data.categoryTotals(now).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final payers = data.payerTotals(now).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      key: const Key('expense-month-summary'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This month', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text(
              formatExpenseEur(data.currentMonthTotalCents(now)),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (categories.isNotEmpty || payers.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'By category',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              for (final entry in categories)
                _SummaryRow(
                  label: data.category(entry.key)?.name ?? 'Other',
                  cents: entry.value,
                ),
              const SizedBox(height: 6),
              Text('Paid by', style: Theme.of(context).textTheme.labelLarge),
              for (final entry in payers)
                _SummaryRow(
                  label: data.person(entry.key)?.name ?? 'Household member',
                  cents: entry.value,
                ),
            ] else
              const Text('No expenses recorded this month.'),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.cents});
  final String label;
  final int cents;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        Text(formatExpenseEur(cents)),
      ],
    ),
  );
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.data,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final ExpenseRecord expense;
  final ExpensesData data;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final category = data.category(expense.categoryId);
    final payer = data.person(expense.paidBy);
    return Card(
      key: ValueKey('expense-${expense.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        onTap: onTap,
        leading: expense.receiptUrl == null
            ? CircleAvatar(
                backgroundColor: _parseColor(category?.color ?? '#68794D'),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.white,
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  expense.receiptUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.receipt_long_outlined),
                ),
              ),
        title: Text(
          expense.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${category?.name ?? 'Other'} · ${_formatDate(expense.expenseDate)} · ${payer?.name ?? 'Household'}${expense.shared ? ' · Shared' : ' · Personal'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: SizedBox(
          width: 118,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  formatExpenseEur(expense.amountCents),
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 1,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Expense actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onArchive();
                  if (value == 'restore') onRestore();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: expense.isArchived ? 'restore' : 'archive',
                    child: Text(expense.isArchived ? 'Restore' : 'Archive'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpensesEmpty extends StatelessWidget {
  const _ExpensesEmpty({required this.archived});
  final bool archived;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      children: [
        Icon(
          archived ? Icons.archive_outlined : Icons.receipt_long_outlined,
          size: 44,
        ),
        const SizedBox(height: 12),
        Text(
          archived ? 'No archived expenses' : 'No expenses yet',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _ExpensesError extends StatelessWidget {
  const _ExpensesError({required this.onRetry});
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
            'Expenses could not be loaded. Check the connection and confirm the Phase 6 migration has been applied.',
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

Future<ExpenseCategoryDraft?> showExpenseCategoryEditor(
  BuildContext context, {
  ExpenseCategory? category,
}) {
  final name = TextEditingController(text: category?.name ?? '');
  var color = category?.color ?? _categoryColors.first;
  return showDialog<ExpenseCategoryDraft>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(category == null ? 'New category' : 'Edit category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('expense-category-name'),
              controller: name,
              autofocus: true,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Category name'),
            ),
            const Align(alignment: Alignment.centerLeft, child: Text('Color')),
            Wrap(
              children: [
                for (final item in _categoryColors)
                  IconButton(
                    tooltip: 'Category color $item',
                    onPressed: () => setState(() => color = item),
                    icon: CircleAvatar(
                      radius: 14,
                      backgroundColor: _parseColor(item),
                      child: color == item
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('expense-category-save'),
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                dialogContext,
                ExpenseCategoryDraft(name: name.text.trim(), color: color),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  ).whenComplete(name.dispose);
}

const _categoryColors = <String>[
  '#718B54',
  '#A27B57',
  '#657A9D',
  '#B06D43',
  '#648A7B',
  '#92739C',
  '#73777B',
];

Color _parseColor(String value) {
  try {
    return Color(
      int.parse(value.replaceFirst('#', ''), radix: 16) + 0xFF000000,
    );
  } catch (_) {
    return const Color(0xFF68794D);
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
