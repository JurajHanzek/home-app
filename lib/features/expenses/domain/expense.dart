class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String color;
  final DateTime createdAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) =>
      ExpenseCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as String? ?? '#68794D',
        createdAt: DateTime.parse(json['created_at'] as String),
        archivedAt: _date(json['archived_at']),
      );
}

class ExpensePerson {
  const ExpensePerson({
    required this.id,
    required this.name,
    required this.initials,
  });

  final String id;
  final String name;
  final String initials;
}

class ExpenseRecord {
  const ExpenseRecord({
    required this.id,
    required this.amountCents,
    required this.title,
    required this.categoryId,
    required this.paidBy,
    required this.shared,
    required this.expenseDate,
    required this.note,
    required this.createdBy,
    required this.updatedAt,
    this.currency = 'EUR',
    this.receiptPath,
    this.receiptUrl,
    this.archivedAt,
  });

  final String id;
  final int amountCents;
  final String currency;
  final String title;
  final String categoryId;
  final String paidBy;
  final bool shared;
  final DateTime expenseDate;
  final String note;
  final String? receiptPath;
  final String? receiptUrl;
  final String createdBy;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  ExpenseRecord withReceiptUrl(String? url) => ExpenseRecord(
    id: id,
    amountCents: amountCents,
    currency: currency,
    title: title,
    categoryId: categoryId,
    paidBy: paidBy,
    shared: shared,
    expenseDate: expenseDate,
    note: note,
    receiptPath: receiptPath,
    receiptUrl: url,
    createdBy: createdBy,
    updatedAt: updatedAt,
    archivedAt: archivedAt,
  );

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['expense_date'] as String);
    final amount = double.parse(json['amount'].toString());
    return ExpenseRecord(
      id: json['id'] as String,
      amountCents: (amount * 100).round(),
      currency: json['currency'] as String? ?? 'EUR',
      title: json['title'] as String,
      categoryId: json['category_id'] as String,
      paidBy: json['paid_by'] as String,
      shared: json['shared'] as bool? ?? true,
      expenseDate: DateTime(date.year, date.month, date.day),
      note: json['note'] as String? ?? '',
      receiptPath: json['receipt_path'] as String?,
      createdBy: json['created_by'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      archivedAt: _date(json['archived_at']),
    );
  }
}

class ExpenseDraft {
  const ExpenseDraft({
    required this.amountCents,
    required this.title,
    required this.categoryId,
    required this.paidBy,
    required this.shared,
    required this.expenseDate,
    required this.note,
  });

  final int amountCents;
  final String title;
  final String categoryId;
  final String paidBy;
  final bool shared;
  final DateTime expenseDate;
  final String note;

  Map<String, dynamic> toJson(String actorId) => {
    'amount':
        '${amountCents ~/ 100}.${(amountCents % 100).toString().padLeft(2, '0')}',
    'currency': 'EUR',
    'title': title.trim(),
    'category_id': categoryId,
    'paid_by': paidBy,
    'shared': shared,
    'expense_date': _dateString(expenseDate),
    'note': note.trim(),
    'updated_by': actorId,
  };
}

class ExpenseCategoryDraft {
  const ExpenseCategoryDraft({required this.name, required this.color});

  final String name;
  final String color;
}

class ExpensesData {
  const ExpensesData({
    required this.categories,
    required this.people,
    required this.expenses,
  });

  final List<ExpenseCategory> categories;
  final List<ExpensePerson> people;
  final List<ExpenseRecord> expenses;

  List<ExpenseRecord> currentMonth(DateTime now) => expenses.where((item) {
    return !item.isArchived &&
        item.expenseDate.year == now.year &&
        item.expenseDate.month == now.month;
  }).toList()..sort((a, b) => b.expenseDate.compareTo(a.expenseDate));

  int currentMonthTotalCents(DateTime now) =>
      currentMonth(now).fold(0, (total, item) => total + item.amountCents);

  Map<String, int> categoryTotals(DateTime now) {
    final totals = <String, int>{};
    for (final expense in currentMonth(now)) {
      totals.update(
        expense.categoryId,
        (total) => total + expense.amountCents,
        ifAbsent: () => expense.amountCents,
      );
    }
    return totals;
  }

  Map<String, int> payerTotals(DateTime now) {
    final totals = <String, int>{};
    for (final expense in currentMonth(now)) {
      totals.update(
        expense.paidBy,
        (total) => total + expense.amountCents,
        ifAbsent: () => expense.amountCents,
      );
    }
    return totals;
  }

  ExpenseCategory? category(String id) {
    for (final item in categories) {
      if (item.id == id) return item;
    }
    return null;
  }

  ExpensePerson? person(String id) {
    for (final item in people) {
      if (item.id == id) return item;
    }
    return null;
  }
}

int? parseExpenseAmountCents(String value) {
  final cleaned = value.trim().replaceAll(' ', '');
  if (!RegExp(r'^\d+(?:[.,]\d{1,2})?$').hasMatch(cleaned)) return null;
  final normalized = cleaned.replaceAll(',', '.');
  final parts = normalized.split('.');
  final major = int.tryParse(parts.first);
  if (major == null) return null;
  final minor = parts.length == 1 ? 0 : int.parse(parts[1].padRight(2, '0'));
  return major * 100 + minor;
}

String formatExpenseEur(int cents) {
  final major = (cents ~/ 100).toString();
  final groups = <String>[];
  for (var end = major.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, major.substring(start, end));
  }
  return '€ ${groups.join('.')},${(cents % 100).toString().padLeft(2, '0')}';
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
