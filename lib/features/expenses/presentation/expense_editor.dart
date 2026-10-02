import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../features/tasks/data/task_image_picker.dart';
import '../domain/expense.dart';

class ExpenseEditorResult {
  const ExpenseEditorResult(
    this.draft, {
    this.receipt,
    this.removeReceipt = false,
  });

  final ExpenseDraft draft;
  final PreparedTaskImage? receipt;
  final bool removeReceipt;
}

Future<ExpenseEditorResult?> showExpenseEditor(
  BuildContext context, {
  required ExpensesData data,
  ExpenseRecord? expense,
}) => showDialog<ExpenseEditorResult>(
  context: context,
  builder: (_) => _ExpenseEditor(data: data, expense: expense),
);

class _ExpenseEditor extends StatefulWidget {
  const _ExpenseEditor({required this.data, this.expense});

  final ExpensesData data;
  final ExpenseRecord? expense;

  @override
  State<_ExpenseEditor> createState() => _ExpenseEditorState();
}

class _ExpenseEditorState extends State<_ExpenseEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late String? _categoryId;
  late String? _paidBy;
  late bool _shared;
  PreparedTaskImage? _receipt;
  bool _removeReceipt = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    _amount = TextEditingController(
      text: expense == null
          ? ''
          : '${expense.amountCents ~/ 100}.${(expense.amountCents % 100).toString().padLeft(2, '0')}',
    );
    _title = TextEditingController(text: expense?.title ?? '');
    _note = TextEditingController(text: expense?.note ?? '');
    final now = DateTime.now();
    _date = expense?.expenseDate ?? DateTime(now.year, now.month, now.day);
    final availableCategories = widget.data.categories
        .where((item) => !item.isArchived || item.id == expense?.categoryId)
        .toList();
    _categoryId =
        expense?.categoryId ??
        (availableCategories.isEmpty ? null : availableCategories.first.id);
    _paidBy =
        expense?.paidBy ??
        (widget.data.people.isEmpty ? null : widget.data.people.first.id);
    _shared = expense?.shared ?? true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expense = widget.expense;
    final categories = widget.data.categories
        .where((item) => !item.isArchived || item.id == _categoryId)
        .toList();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      title: Text(expense == null ? 'New expense' : 'Edit expense'),
      titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              spacing: 14,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('expense-amount'),
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Amount (EUR) *',
                    prefixText: '€ ',
                  ),
                  validator: (value) {
                    final cents = parseExpenseAmountCents(value ?? '');
                    return cents == null || cents <= 0 || cents > 999999999999
                        ? 'Enter an amount from 0.01 to 9,999,999,999.99.'
                        : null;
                  },
                ),
                TextFormField(
                  key: const Key('expense-title'),
                  controller: _title,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Title or merchant *',
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Enter a title or merchant.'
                      : null,
                ),
                DropdownButtonFormField<String>(
                  key: const Key('expense-category'),
                  isExpanded: true,
                  initialValue: categories.any((item) => item.id == _categoryId)
                      ? _categoryId
                      : null,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(
                          '${category.name}${category.isArchived ? ' (archived)' : ''}',
                        ),
                      ),
                  ],
                  onChanged: (value) => setState(() => _categoryId = value),
                  validator: (value) =>
                      value == null ? 'Choose a category.' : null,
                ),
                DropdownButtonFormField<String>(
                  key: const Key('expense-paid-by'),
                  isExpanded: true,
                  initialValue:
                      widget.data.people.any((person) => person.id == _paidBy)
                      ? _paidBy
                      : null,
                  decoration: const InputDecoration(labelText: 'Paid by'),
                  items: [
                    for (final person in widget.data.people)
                      DropdownMenuItem(
                        value: person.id,
                        child: Text(person.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _paidBy = value),
                  validator: (value) =>
                      value == null ? 'Choose who paid.' : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Expense date'),
                  trailing: TextButton(
                    key: const Key('expense-date'),
                    onPressed: _pickDate,
                    child: Text(_formatDate(_date)),
                  ),
                ),
                SwitchListTile(
                  key: const Key('expense-shared'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Shared household expense'),
                  value: _shared,
                  onChanged: (value) => setState(() => _shared = value),
                ),
                TextFormField(
                  controller: _note,
                  maxLines: 3,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 6),
                    child: Text('Receipt image (optional)'),
                  ),
                ),
                _receiptPreview(
                  context,
                  bytes: _receipt?.bytes,
                  url: _removeReceipt ? null : expense?.receiptUrl,
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('expense-pick-receipt'),
                      onPressed: _pickReceipt,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _receipt == null && expense?.receiptPath == null
                            ? 'Choose receipt'
                            : 'Replace receipt',
                      ),
                    ),
                    if (_receipt != null)
                      TextButton(
                        onPressed: () => setState(() => _receipt = null),
                        child: const Text('Clear selection'),
                      )
                    else if (expense?.receiptPath != null)
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _removeReceipt = !_removeReceipt),
                        icon: Icon(
                          _removeReceipt ? Icons.undo : Icons.delete_outline,
                        ),
                        label: Text(
                          _removeReceipt ? 'Keep receipt' : 'Remove receipt',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('expense-save'),
          onPressed: _save,
          child: const Text('Save expense'),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null && mounted) {
      setState(() => _date = DateTime(date.year, date.month, date.day));
    }
  }

  Future<void> _pickReceipt() async {
    try {
      final image = await TaskImagePicker.pick();
      if (image != null && mounted) {
        setState(() {
          _receipt = image;
          _removeReceipt = false;
        });
      }
    } catch (_) {
      if (mounted) _showMessage('Could not prepare that receipt image.');
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final cents = parseExpenseAmountCents(_amount.text)!;
    Navigator.pop(
      context,
      ExpenseEditorResult(
        ExpenseDraft(
          amountCents: cents,
          title: _title.text.trim(),
          categoryId: _categoryId!,
          paidBy: _paidBy!,
          shared: _shared,
          expenseDate: _date,
          note: _note.text,
        ),
        receipt: _receipt,
        removeReceipt: _removeReceipt,
      ),
    );
  }

  void _showMessage(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Widget _receiptPreview(BuildContext context, {Uint8List? bytes, String? url}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 150,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _receiptPlaceholder(context),
              )
            : _receiptPlaceholder(context),
      ),
    );

Widget _receiptPlaceholder(BuildContext context) => ColoredBox(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  child: Icon(
    Icons.receipt_long_outlined,
    size: 36,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
  ),
);

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
