import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_hub/features/expenses/data/expenses_repository.dart';
import 'package:home_hub/features/expenses/domain/expense.dart';
import 'package:home_hub/features/tasks/data/task_image_picker.dart';

import 'expense_model_test.dart' show expenseFixture;

void main() {
  final draft = ExpenseDraft(
    amountCents: 1234,
    title: 'Market',
    categoryId: 'category',
    paidBy: 'payer',
    shared: false,
    expenseDate: DateTime(2026, 10, 2),
    note: '',
  );
  final receipt = PreparedTaskImage(
    Uint8List.fromList([255, 216, 255, 217]),
    1,
    1,
  );
  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  ExpensesRepository repository(
    Future<http.Response> Function(http.Request) handler,
  ) {
    final client = SupabaseClient(
      'https://example.test',
      'test-key',
      httpClient: MockClient((request) async {
        final response = await handler(request);
        return http.Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    );
    addTearDown(client.dispose);
    return ExpensesRepository(client, 'creator');
  }

  test(
    'receipt-free creation stores separate actor and payer without Storage calls',
    () async {
      final requests = <http.Request>[];
      final repo = repository((request) async {
        requests.add(request);
        return json({'id': 'expense'});
      });
      expect(await repo.createExpense(draft), 'expense');
      expect(requests.length, 1);
      final payload = jsonDecode(requests.single.body) as Map;
      expect(payload['created_by'], 'creator');
      expect(payload['paid_by'], 'payer');
      expect(payload['shared'], isFalse);
      expect(payload['amount'], '12.34');
      expect(payload.containsKey('receipt_path'), isFalse);
    },
  );

  test(
    'receipt upload uses private household expense UUID key and saves only stable path',
    () async {
      String? uploadPath;
      Map? patch;
      final repo = repository((request) async {
        if (request.url.path == '/rest/v1/profiles') {
          return json({'household_id': 'household'});
        }
        if (request.url.path.startsWith('/storage/v1/object/')) {
          uploadPath = request.url.path.replaceFirst(
            '/storage/v1/object/household-media/',
            '',
          );
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          expect(
            latin1.decode(request.bodyBytes),
            contains('content-type: image/jpeg'),
          );
          expect(
            latin1.decode(request.bodyBytes),
            contains(latin1.decode(receipt.bytes)),
          );
          return json({'Key': uploadPath});
        }
        if (request.method == 'PATCH') {
          patch = jsonDecode(request.body) as Map;
          return http.Response('', 204);
        }
        return json({'id': 'expense'});
      });
      await repo.createExpense(draft, receipt: receipt);
      expect(
        uploadPath,
        matches(
          r'^household/expenses/expense/[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.jpg$',
        ),
      );
      expect(patch, {'receipt_path': uploadPath, 'updated_by': 'creator'});
    },
  );

  test(
    'failed receipt attachment reports saved expense and cleans uploaded object',
    () async {
      var inserts = 0;
      var removed = false;
      final repo = repository((request) async {
        if (request.url.path == '/rest/v1/profiles') {
          return json({'household_id': 'household'});
        }
        if (request.method == 'DELETE') {
          removed = true;
          return json([]);
        }
        if (request.url.path.startsWith('/storage/')) {
          return json({'Key': 'uploaded'});
        }
        if (request.method == 'PATCH') {
          return json({'message': 'failed', 'code': '42501'}, 403);
        }
        inserts++;
        return json({'id': 'saved-expense'});
      });
      await expectLater(
        repo.createExpense(draft, receipt: receipt),
        throwsA(
          isA<ExpenseReceiptSaveException>().having(
            (e) => e.expenseId,
            'saved id',
            'saved-expense',
          ),
        ),
      );
      expect(inserts, 1);
      expect(removed, isTrue);
    },
  );

  test('archive and restore use exact expense ID and current actor', () async {
    final patches = <Map>[];
    final repo = repository((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters['id'], 'eq.expense-1');
      patches.add(jsonDecode(request.body) as Map);
      return http.Response('', 204);
    });
    await repo.setArchived(expenseFixture(), true);
    await repo.setArchived(expenseFixture(), false);
    expect(patches.first['archived_at'], isNotNull);
    expect(patches.last['archived_at'], isNull);
    expect(patches.every((p) => p['updated_by'] == 'creator'), isTrue);
  });

  test('failed signing keeps the ledger and private path available', () async {
    final repo = repository((request) async {
      if (request.url.path.endsWith('/expense_categories')) return json([]);
      if (request.url.path.endsWith('/profiles')) return json([]);
      if (request.url.path.endsWith('/expenses')) {
        return json([
          {
            'id': 'expense',
            'amount': '12.34',
            'title': 'Market',
            'category_id': 'category',
            'paid_by': 'payer',
            'shared': false,
            'expense_date': '2026-10-02',
            'created_by': 'creator',
            'updated_at': '2026-10-02T12:00:00Z',
            'receipt_path': 'household/expenses/expense/image.jpg',
          },
        ]);
      }
      return json({'message': 'missing receipt'}, 404);
    });
    final data = await repo.load();
    expect(data.expenses.single.amountCents, 1234);
    expect(data.expenses.single.receiptPath, isNotNull);
    expect(data.expenses.single.receiptUrl, isNull);
  });
}
