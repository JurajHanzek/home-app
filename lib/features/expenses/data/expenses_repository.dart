import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../features/tasks/data/task_image_picker.dart';
import '../domain/expense.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>(
  (ref) => ExpensesRepository(
    Supabase.instance.client,
    Supabase.instance.client.auth.currentUser!.id,
  ),
);

final expensesProvider = FutureProvider.autoDispose<ExpensesData>((ref) async {
  final repository = ref.watch(expensesRepositoryProvider);
  final channel = repository.watchChanges(() => ref.invalidateSelf());
  ref.onDispose(channel.unsubscribe);
  return repository.load().timeout(const Duration(seconds: 20));
}, retry: (_, _) => null);

class ExpensesRepository {
  const ExpensesRepository(this._client, this.currentUserId);

  final SupabaseClient _client;
  final String currentUserId;

  RealtimeChannel watchChanges(void Function() changed) => _client
      .channel('homehub-expenses-$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expense_categories',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'expenses',
        callback: (_) => changed(),
      )
      .subscribe();

  Future<ExpensesData> load() async {
    final rows = await Future.wait([
      _client
          .from('expense_categories')
          .select()
          .order('archived_at', nullsFirst: true)
          .order('name'),
      _client
          .from('profiles')
          .select('id,display_name,initials')
          .order('created_at'),
      _client
          .from('expenses')
          .select()
          .order('expense_date', ascending: false)
          .order('created_at', ascending: false),
    ]);
    final categories = (rows[0] as List)
        .map((row) => ExpenseCategory.fromJson(row as Map<String, dynamic>))
        .toList();
    final people = (rows[1] as List).map((row) {
      final profile = row as Map<String, dynamic>;
      return ExpensePerson(
        id: profile['id'] as String,
        name: profile['display_name'] as String,
        initials: profile['initials'] as String,
      );
    }).toList();
    final expenses = (rows[2] as List)
        .map((row) => ExpenseRecord.fromJson(row as Map<String, dynamic>))
        .toList();
    final signed = <String, String>{};
    for (final path
        in expenses.map((item) => item.receiptPath).whereType<String>()) {
      try {
        signed[path] = await _client.storage
            .from('household-media')
            .createSignedUrl(path, 3600);
      } catch (_) {
        // Missing media displays as an optional receipt placeholder.
      }
    }
    return ExpensesData(
      categories: categories,
      people: people,
      expenses: expenses
          .map((item) => item.withReceiptUrl(signed[item.receiptPath]))
          .toList(),
    );
  }

  Future<void> createCategory(ExpenseCategoryDraft draft) async {
    await _client.from('expense_categories').insert({
      'name': draft.name.trim(),
      'color': draft.color,
      'created_by': currentUserId,
      'updated_by': currentUserId,
    });
  }

  Future<void> updateCategory(String id, ExpenseCategoryDraft draft) async {
    await _client
        .from('expense_categories')
        .update({
          'name': draft.name.trim(),
          'color': draft.color,
          'updated_by': currentUserId,
        })
        .eq('id', id);
  }

  Future<void> setCategoryArchived(
    ExpenseCategory category,
    bool archived,
  ) async {
    await _client
        .from('expense_categories')
        .update({
          'archived_at': archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'updated_by': currentUserId,
        })
        .eq('id', category.id);
  }

  Future<String> createExpense(
    ExpenseDraft draft, {
    PreparedTaskImage? receipt,
  }) async {
    final payload = draft.toJson(currentUserId)..['created_by'] = currentUserId;
    final result = await _client
        .from('expenses')
        .insert(payload)
        .select('id')
        .single();
    final id = result['id'] as String;
    if (receipt != null) {
      String? uploadedPath;
      try {
        final path = uploadedPath = await _uploadReceipt(id, receipt.bytes);
        await _client
            .from('expenses')
            .update({'receipt_path': path, 'updated_by': currentUserId})
            .eq('id', id);
      } catch (_) {
        if (uploadedPath != null) await _removeReceipt(uploadedPath);
        throw ExpenseReceiptSaveException(id);
      }
    }
    return id;
  }

  Future<void> updateExpense(
    ExpenseRecord expense,
    ExpenseDraft draft, {
    PreparedTaskImage? receipt,
    bool removeReceipt = false,
  }) async {
    String? newPath;
    if (receipt != null) {
      newPath = await _uploadReceipt(expense.id, receipt.bytes);
    }
    final payload = draft.toJson(currentUserId);
    if (newPath != null) payload['receipt_path'] = newPath;
    if (removeReceipt) payload['receipt_path'] = null;
    try {
      await _client.from('expenses').update(payload).eq('id', expense.id);
    } catch (_) {
      if (newPath != null) await _removeReceipt(newPath);
      rethrow;
    }
    final oldPath = expense.receiptPath;
    if ((removeReceipt || newPath != null) && oldPath != null) {
      await _removeReceipt(oldPath);
    }
  }

  Future<void> setArchived(ExpenseRecord expense, bool archived) async {
    await _client
        .from('expenses')
        .update({
          'archived_at': archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'updated_by': currentUserId,
        })
        .eq('id', expense.id);
  }

  Future<String> _uploadReceipt(String expenseId, Uint8List bytes) async {
    final householdId = await _client
        .from('profiles')
        .select('household_id')
        .eq('id', currentUserId)
        .single()
        .then((row) => row['household_id'] as String);
    final path = '$householdId/expenses/$expenseId/${const Uuid().v4()}.jpg';
    await _client.storage
        .from('household-media')
        .uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );
    return path;
  }

  Future<void> _removeReceipt(String path) async {
    try {
      await _client.storage.from('household-media').remove([path]);
    } catch (_) {
      // A stale private object is safer than failing the persisted expense edit.
    }
  }
}

class ExpenseReceiptSaveException implements Exception {
  const ExpenseReceiptSaveException(this.expenseId);
  final String expenseId;
}
