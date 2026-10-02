import 'package:flutter/material.dart';

import '../domain/expense.dart';

class ExpenseFilters {
  const ExpenseFilters({this.month, this.categoryId, this.paidBy, this.shared});

  final DateTime? month;
  final String? categoryId;
  final String? paidBy;
  final bool? shared;

  bool get isActive =>
      month != null || categoryId != null || paidBy != null || shared != null;

  bool matches(ExpenseRecord expense) =>
      (month == null ||
          (expense.expenseDate.year == month!.year &&
              expense.expenseDate.month == month!.month)) &&
      (categoryId == null || expense.categoryId == categoryId) &&
      (paidBy == null || expense.paidBy == paidBy) &&
      (shared == null || expense.shared == shared);
}

Future<ExpenseFilters?> showExpenseFilters(
  BuildContext context, {
  required ExpensesData data,
  required ExpenseFilters filters,
}) => showDialog<ExpenseFilters>(
  context: context,
  builder: (_) => _FilterDialog(data: data, filters: filters),
);

class _FilterDialog extends StatefulWidget {
  const _FilterDialog({required this.data, required this.filters});
  final ExpensesData data;
  final ExpenseFilters filters;

  @override
  State<_FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<_FilterDialog> {
  late DateTime? _month = widget.filters.month;
  late String? _category = widget.filters.categoryId;
  late String? _payer = widget.filters.paidBy;
  late bool? _shared = widget.filters.shared;
  int _reset = 0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = {
      for (var offset = 0; offset < 12; offset++)
        DateTime(now.year, now.month - offset),
      for (final expense in widget.data.expenses)
        DateTime(expense.expenseDate.year, expense.expenseDate.month),
      ?_month,
    }.toList()..sort((a, b) => b.compareTo(a));
    return AlertDialog(
      title: const Text('Filter expenses'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            key: ValueKey(_reset),
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<DateTime>(
                key: const Key('filter-month'),
                initialValue: _month,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Month'),
                items: [
                  const DropdownMenuItem(child: Text('All months')),
                  for (final month in months)
                    DropdownMenuItem(
                      value: month,
                      child: Text(expenseMonthLabel(context, month)),
                    ),
                ],
                onChanged: (value) => setState(() => _month = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('filter-category'),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(child: Text('All categories')),
                  for (final category in widget.data.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        '${category.name}${category.isArchived ? ' (archived)' : ''}',
                      ),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('filter-payer'),
                initialValue: _payer,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: [
                  const DropdownMenuItem(child: Text('Anyone')),
                  for (final person in widget.data.people)
                    DropdownMenuItem(
                      value: person.id,
                      child: Text(person.name),
                    ),
                ],
                onChanged: (value) => setState(() => _payer = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<bool>(
                key: const Key('filter-type'),
                initialValue: _shared,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(child: Text('Shared and personal')),
                  DropdownMenuItem(value: true, child: Text('Shared')),
                  DropdownMenuItem(value: false, child: Text('Personal')),
                ],
                onChanged: (value) => setState(() => _shared = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() {
            _month = null;
            _category = null;
            _payer = null;
            _shared = null;
            _reset++;
          }),
          child: const Text('Reset'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ExpenseFilters(
              month: _month,
              categoryId: _category,
              paidBy: _payer,
              shared: _shared,
            ),
          ),
          child: const Text('Apply filters'),
        ),
      ],
    );
  }
}

String expenseMonthLabel(BuildContext context, DateTime month) =>
    MaterialLocalizations.of(context).formatMonthYear(month);
