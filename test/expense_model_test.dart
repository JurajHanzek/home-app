import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/expenses/domain/expense.dart';

ExpenseRecord expenseFixture({
  String id = 'expense-1',
  int cents = 1250,
  String category = 'groceries',
  String payer = 'user-b',
  bool shared = true,
  DateTime? date,
  bool archived = false,
  String? receiptPath,
}) => ExpenseRecord.fromJson({
  'id': id,
  'amount': cents / 100,
  'title': 'Market',
  'category_id': category,
  'paid_by': payer,
  'shared': shared,
  'expense_date': (date ?? DateTime.now()).toIso8601String().substring(0, 10),
  'note': 'Weekly supplies',
  'created_by': 'user-a',
  'updated_at': '2026-10-02T12:00:00Z',
  'archived_at': archived ? '2026-10-02T12:00:00Z' : null,
  'receipt_path': receiptPath,
});

ExpensesData expenseData(
  List<ExpenseRecord> expenses, {
  bool archivedCategory = false,
}) => ExpensesData(
  expenses: expenses,
  categories: [
    ExpenseCategory(
      id: 'groceries',
      name: 'Groceries',
      color: '#718B54',
      createdAt: DateTime(2026),
      archivedAt: archivedCategory ? DateTime(2026, 10) : null,
    ),
  ],
  people: const [
    ExpensePerson(id: 'user-a', name: 'Alice', initials: 'A'),
    ExpensePerson(id: 'user-b', name: 'Bob', initials: 'B'),
  ],
);

void main() {
  final now = DateTime(2026, 10, 15);
  test('month total excludes archives and other months and years', () {
    final data = expenseData([
      expenseFixture(date: DateTime(2026, 10, 1)),
      expenseFixture(date: DateTime(2026, 10, 31), cents: 25),
      expenseFixture(date: now, archived: true, cents: 9000),
      expenseFixture(date: DateTime(2026, 9, 30)),
      expenseFixture(date: DateTime(2026, 11, 1)),
      expenseFixture(date: DateTime(2025, 10, 15)),
    ]);
    expect(data.currentMonthTotalCents(now), 1275);
    expect(data.currentMonth(now).length, 2);
  });

  test('category and payer totals use paid_by, include personal expenses', () {
    final data = expenseData([
      expenseFixture(date: now, cents: 101, shared: false),
      expenseFixture(date: now, cents: 202),
      expenseFixture(date: now, cents: 400, category: 'bills', payer: 'user-a'),
      expenseFixture(date: now, cents: 9999, archived: true),
    ]);
    expect(data.currentMonthTotalCents(now), 703);
    expect(data.categoryTotals(now), {'groceries': 303, 'bills': 400});
    expect(data.payerTotals(now), {'user-b': 303, 'user-a': 400});
  });

  test('archived categories preserve historical rows and totals', () {
    final data = expenseData([
      expenseFixture(date: now),
    ], archivedCategory: true);
    expect(data.category('groceries')!.isArchived, isTrue);
    expect(data.categoryTotals(now), {'groceries': 1250});
    expect(data.currentMonthTotalCents(now), 1250);
  });

  test('archive then restore removes then restores the monthly total', () {
    expect(
      expenseData([
        expenseFixture(date: now, archived: true),
      ]).currentMonthTotalCents(now),
      0,
    );
    expect(
      expenseData([expenseFixture(date: now)]).currentMonthTotalCents(now),
      1250,
    );
  });

  test('optional receipt and temporary URL leave stored path unchanged', () {
    expect(expenseFixture().receiptPath, isNull);
    final record = expenseFixture(
      receiptPath: 'household/expenses/expense/image.jpg',
    );
    final signed = record.withReceiptUrl('https://example.test/temporary');
    expect(signed.receiptPath, record.receiptPath);
    expect(record.receiptUrl, isNull);
    expect(signed.createdBy, 'user-a');
    expect(signed.paidBy, 'user-b');
  });

  test('draft preserves exact cents, EUR, payer and calendar date', () {
    final json = ExpenseDraft(
      amountCents: 123456789,
      title: ' Market ',
      categoryId: 'groceries',
      paidBy: 'user-b',
      shared: false,
      expenseDate: now,
      note: '',
    ).toJson('user-a');
    expect(json['amount'], '1234567.89');
    expect(json['currency'], 'EUR');
    expect(json['paid_by'], 'user-b');
    expect(json['updated_by'], 'user-a');
    expect(json.containsKey('created_by'), isFalse);
    expect(json['shared'], isFalse);
    expect(json['expense_date'], '2026-10-15');
    expect(json.containsKey('receipt_url'), isFalse);
  });

  test('amount entry accepts decimal comma and rejects ambiguous values', () {
    expect(parseExpenseAmountCents('12,50'), 1250);
    expect(parseExpenseAmountCents('0.01'), 1);
    expect(parseExpenseAmountCents('12'), 1200);
    for (final value in ['-1', 'NaN', '1.234', '1,234.56', '']) {
      expect(parseExpenseAmountCents(value), isNull);
    }
    expect(formatExpenseEur(123456), '€ 1.234,56');
  });
}
