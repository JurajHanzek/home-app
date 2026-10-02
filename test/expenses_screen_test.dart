import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/expenses/data/expenses_repository.dart';
import 'package:home_hub/features/expenses/domain/expense.dart';
import 'package:home_hub/features/expenses/presentation/expenses_screen.dart';
import 'package:home_hub/features/expenses/presentation/expense_filters.dart';
import 'package:home_hub/features/tasks/data/task_image_picker.dart';

import 'expense_model_test.dart' show expenseFixture, expenseData;

void main() {
  test('filters combine month/year, category, paid_by and shared state', () {
    final filters = ExpenseFilters(
      month: DateTime(2026, 10),
      categoryId: 'groceries',
      paidBy: 'user-b',
      shared: false,
    );
    expect(
      filters.matches(
        expenseFixture(date: DateTime(2026, 10, 2), shared: false),
      ),
      isTrue,
    );
    expect(
      filters.matches(
        expenseFixture(date: DateTime(2025, 10, 2), shared: false),
      ),
      isFalse,
    );
    expect(
      filters.matches(
        expenseFixture(date: DateTime(2026, 9, 2), shared: false),
      ),
      isFalse,
    );
    expect(
      filters.matches(expenseFixture(date: DateTime(2026, 10, 2))),
      isFalse,
    );
    expect(
      filters.matches(
        expenseFixture(
          date: DateTime(2026, 10, 2),
          shared: false,
          payer: 'user-a',
        ),
      ),
      isFalse,
    );
    expect(
      filters.matches(
        expenseFixture(
          date: DateTime(2026, 10, 2),
          shared: false,
          category: 'home',
        ),
      ),
      isFalse,
    );
    expect(const ExpenseFilters().matches(expenseFixture()), isTrue);
  });
  Future<void> open(WidgetTester tester, _Repository repository) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          expensesProvider.overrideWith((ref) async => repository.data),
          expensesRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'detail distinguishes payer and creator; archive and restore update totals',
    (tester) async {
      final repository = _Repository();
      await open(tester, repository);
      expect(find.text('This month'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('expense-expense-1')));
      await tester.pumpAndSettle();
      expect(find.text('Paid by: Bob'), findsOneWidget);
      expect(find.text('Created by: Alice'), findsOneWidget);
      expect(find.text('No receipt attached'), findsOneWidget);
      expect(find.text('Weekly supplies'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(repository.archives, [true]);
      expect(find.text('€ 0,00'), findsOneWidget);
      expect(find.text('No expenses yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Archived expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Market'), findsOneWidget);
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore'));
      await tester.pumpAndSettle();
      expect(repository.archives, [true, false]);
      await tester.tap(find.byTooltip('Show active expenses'));
      await tester.pumpAndSettle();
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('No expenses recorded this month.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'create without receipt and edit retain payer, optional note and shared flag',
    (tester) async {
      final repository = _Repository();
      await open(tester, repository);
      await tester.tap(find.byKey(const Key('new-expense')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('expense-amount')), '23,45');
      await tester.enterText(find.byKey(const Key('expense-title')), 'Store');
      await tester.tap(find.byKey(const Key('expense-paid-by')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bob').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('expense-shared')));
      await tester.tap(find.byKey(const Key('expense-shared')));
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pumpAndSettle();
      expect(repository.saved!.amountCents, 2345);
      expect(repository.saved!.paidBy, 'user-b');
      expect(repository.saved!.shared, isFalse);
      expect(repository.saved!.note, isEmpty);
      expect(repository.receipt, isNull);

      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('expense-title')),
        'Updated market',
      );
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pumpAndSettle();
      expect(repository.updatedId, 'expense-1');
      expect(repository.saved!.title, 'Updated market');
      expect(repository.saved!.paidBy, 'user-b');
    },
  );

  testWidgets(
    'receipt picker sends compressed bytes and supports explicit removal',
    (tester) async {
      final repository = _Repository();
      const channel = MethodChannel('app.homehub/task_images');
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => {'bytes': bytes, 'width': 1, 'height': 1},
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await open(tester, repository);
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('expense-pick-receipt')));
      await tester.tap(find.byKey(const Key('expense-pick-receipt')));
      await tester.pumpAndSettle();
      expect(find.text('Clear selection'), findsOneWidget);
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pumpAndSettle();
      expect(repository.receipt!.bytes, bytes);

      repository.path = 'household/expenses/expense-1/receipt.jpg';
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      // Refresh data after the previous mutation is required for a new stored path.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const Key('expenses-list')),
        const Offset(0, 500),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Expense actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Remove receipt'));
      await tester.tap(find.text('Remove receipt'));
      await tester.tap(find.byKey(const Key('expense-save')));
      await tester.pumpAndSettle();
      expect(repository.removedReceipt, isTrue);
    },
  );

  testWidgets('archived categories remain editable on historical expenses', (
    tester,
  ) async {
    final repository = _Repository()..archivedCategory = true;
    await open(tester, repository);
    await tester.tap(find.byTooltip('Expense actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Groceries (archived)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('expense-save')));
    await tester.pumpAndSettle();
    expect(repository.saved!.categoryId, 'groceries');
    await tester.tap(find.byKey(const Key('new-expense')));
    await tester.pumpAndSettle();
    expect(find.text('Groceries (archived)'), findsNothing);
  });

  testWidgets(
    'filters stay hidden until applied, cancel preserves state and clear restores ledger',
    (tester) async {
      await open(tester, _Repository());
      expect(find.byKey(const Key('expense-active-filters')), findsNothing);
      await tester.tap(find.byKey(const Key('expense-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-active-filters')), findsNothing);
      expect(find.text('Market'), findsOneWidget);
      await tester.tap(find.byKey(const Key('expense-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-type')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Personal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-active-filters')), findsOneWidget);
      expect(find.text('No expenses match these filters.'), findsOneWidget);
      expect(find.text('Filtered total · 0 expenses'), findsOneWidget);
      expect(find.text('Market'), findsNothing);
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-active-filters')), findsNothing);
      expect(find.text('Market'), findsOneWidget);
      expect(find.text('This month'), findsOneWidget);
    },
  );

  testWidgets(
    'month selection applies only on confirmation and chip can be removed',
    (tester) async {
      await open(tester, _Repository());
      await tester.tap(find.byKey(const Key('expense-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-month')));
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final month = MaterialLocalizations.of(
        tester.element(find.byType(ExpensesScreen)),
      ).formatMonthYear(now);
      await tester.tap(find.text(month).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(find.text(month), findsOneWidget);
      expect(find.text('Filtered total · 1 expense'), findsOneWidget);
      final chip = tester.widget<InputChip>(find.byType(InputChip));
      chip.onDeleted!();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('expense-active-filters')), findsNothing);
      expect(find.text('This month'), findsOneWidget);
    },
  );

  testWidgets('loading, failure and retry produce an empty ledger', (
    tester,
  ) async {
    final completer = Completer<ExpensesData>();
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          expensesProvider.overrideWith((ref) {
            calls++;
            return calls == 1
                ? completer.future
                : Future.value(expenseData([]));
          }),
        ],
        child: const MaterialApp(home: ExpensesScreen()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Expenses could not be loaded'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No expenses yet'), findsOneWidget);
  });
}

class _Repository extends Fake implements ExpensesRepository {
  bool archived = false, archivedCategory = false, removedReceipt = false;
  String? path, updatedId;
  ExpenseDraft? saved;
  PreparedTaskImage? receipt;
  final archives = <bool>[];
  ExpensesData get data => expenseData([
    expenseFixture(archived: archived, receiptPath: path),
  ], archivedCategory: archivedCategory);
  @override
  Future<void> setArchived(ExpenseRecord expense, bool value) async {
    archives.add(value);
    archived = value;
  }

  @override
  Future<String> createExpense(
    ExpenseDraft draft, {
    PreparedTaskImage? receipt,
  }) async {
    saved = draft;
    this.receipt = receipt;
    return 'new-id';
  }

  @override
  Future<void> updateExpense(
    ExpenseRecord expense,
    ExpenseDraft draft, {
    PreparedTaskImage? receipt,
    bool removeReceipt = false,
  }) async {
    saved = draft;
    updatedId = expense.id;
    this.receipt = receipt;
    removedReceipt = removeReceipt;
  }
}
