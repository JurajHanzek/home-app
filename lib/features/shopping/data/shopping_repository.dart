import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../meals/domain/meal.dart';
import '../domain/shopping.dart';

final shoppingRepositoryProvider = Provider<ShoppingRepository>(
  (ref) => ShoppingRepository(
    Supabase.instance.client,
    Supabase.instance.client.auth.currentUser!.id,
  ),
);

final shoppingProvider = FutureProvider.autoDispose<ShoppingData>((ref) async {
  final repository = ref.watch(shoppingRepositoryProvider);
  final channel = repository.watchChanges(() => ref.invalidateSelf());
  ref.onDispose(channel.unsubscribe);
  return repository.load();
});

class ShoppingRepository {
  const ShoppingRepository(this._client, this.currentUserId);

  final SupabaseClient _client;
  final String currentUserId;

  RealtimeChannel watchChanges(void Function() changed) => _client
      .channel('homehub-shopping-$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'shopping_general',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'meals',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'meal_ingredients',
        callback: (_) => changed(),
      )
      .subscribe();

  Future<ShoppingData> load() async {
    final today = DateTime.now();
    final todayText =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final results = await Future.wait([
      _client.from('shopping_general').select().order('created_at'),
      _client
          .from('meals')
          .select('*, meal_ingredients(*)')
          .gte('planned_date', todayText)
          .isFilter('archived_at', null)
          .order('planned_date')
          .order('planned_time', nullsFirst: true),
    ]);
    final general = (results[0] as List)
        .map((row) => GeneralShoppingItem.fromJson(row as Map<String, dynamic>))
        .toList();
    final meals = (results[1] as List)
        .map((row) => MealRecord.fromJson(row as Map<String, dynamic>))
        .toList();
    return ShoppingData(meals: meals, generalItems: general);
  }

  Future<void> addGeneralItem(String label) async {
    await _client.from('shopping_general').insert({
      'label': label,
      'created_by': currentUserId,
      'updated_by': currentUserId,
    });
  }

  Future<void> renameGeneralItem(String id, String label) async {
    await _client
        .from('shopping_general')
        .update({'label': label, 'updated_by': currentUserId})
        .eq('id', id);
  }

  Future<void> setGeneralItemDone(String id, bool isDone) async {
    await _client
        .from('shopping_general')
        .update({'is_done': isDone, 'updated_by': currentUserId})
        .eq('id', id);
  }

  Future<void> setGeneralItemArchived(String id, bool archived) async {
    await _client
        .from('shopping_general')
        .update({
          'archived_at': archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'updated_by': currentUserId,
        })
        .eq('id', id);
  }

  Future<void> setMealIngredientHave(String id, bool have) async {
    // The primary key identifies exactly one meal_ingredient row; RLS checks
    // that its parent meal is in the current user's household.
    await _client.from('meal_ingredients').update({'have': have}).eq('id', id);
  }
}
