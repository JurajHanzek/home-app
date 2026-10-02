import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/meal.dart';

final mealsRepositoryProvider = Provider<MealsRepository>(
  (ref) => MealsRepository(
    Supabase.instance.client,
    Supabase.instance.client.auth.currentUser!.id,
  ),
);

final mealsProvider = FutureProvider.autoDispose<MealsData>((ref) async {
  final repository = ref.watch(mealsRepositoryProvider);
  final channel = repository.watchChanges(() => ref.invalidateSelf());
  ref.onDispose(channel.unsubscribe);
  return repository.load();
});

class MealsRepository {
  const MealsRepository(this._client, this.currentUserId);

  final SupabaseClient _client;
  final String currentUserId;

  RealtimeChannel watchChanges(void Function() changed) => _client
      .channel('homehub-meals-$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'recipes',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'recipe_ingredients',
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

  Future<MealsData> load() async {
    final result = await Future.wait([
      _client
          .from('recipes')
          .select('*, recipe_ingredients(*)')
          .order('archived_at', nullsFirst: true)
          .order('name'),
      _client
          .from('meals')
          .select('*, meal_ingredients(*), recipes(image_path)')
          .order('planned_date')
          .order('planned_time', nullsFirst: false),
    ]);
    final recipes = (result[0] as List)
        .map((row) => RecipeRecord.fromJson(row as Map<String, dynamic>))
        .toList();
    final meals = (result[1] as List)
        .map((row) => MealRecord.fromJson(row as Map<String, dynamic>))
        .toList();
    final paths = <String>{
      ...recipes.map((recipe) => recipe.imagePath).whereType<String>(),
      ...meals.map((meal) => meal.recipeImagePath).whereType<String>(),
    };
    final signed = <String, String>{};
    for (final path in paths) {
      try {
        signed[path] = await _client.storage
            .from('household-media')
            .createSignedUrl(path, 3600);
      } catch (_) {
        // An unavailable image should fall back to its themed placeholder.
      }
    }
    return MealsData(
      recipes: recipes
          .map((recipe) => recipe.withImageUrl(signed[recipe.imagePath]))
          .toList(),
      meals: meals
          .map((meal) => meal.withRecipeImageUrl(signed[meal.recipeImagePath]))
          .toList(),
    );
  }

  Future<String> createRecipe(RecipeDraft draft) async {
    final row = await _client
        .from('recipes')
        .insert({
          'name': draft.name.trim(),
          'instructions': draft.instructions.trim(),
          'created_by': currentUserId,
          'updated_by': currentUserId,
        })
        .select('id')
        .single();
    final id = row['id'] as String;
    await _writeRecipeIngredients(id, draft.ingredients);
    return id;
  }

  Future<void> updateRecipe(String id, RecipeDraft draft) async {
    await _client
        .from('recipes')
        .update({
          'name': draft.name.trim(),
          'instructions': draft.instructions.trim(),
          'updated_by': currentUserId,
        })
        .eq('id', id);
    await _client.from('recipe_ingredients').delete().eq('recipe_id', id);
    await _writeRecipeIngredients(id, draft.ingredients);
  }

  Future<void> _writeRecipeIngredients(
    String id,
    List<IngredientDraft> ingredients,
  ) async {
    final rows = ingredients
        .where((item) => item.label.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => {
            'recipe_id': id,
            'label': entry.value.label.trim(),
            'quantity': _emptyToNull(entry.value.quantity),
            'unit': _emptyToNull(entry.value.unit),
            'sort_order': entry.key,
          },
        )
        .toList();
    if (rows.isNotEmpty) await _client.from('recipe_ingredients').insert(rows);
  }

  Future<void> setRecipeArchived(String id, bool archived) async => _client
      .from('recipes')
      .update({
        'archived_at': archived
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'updated_by': currentUserId,
      })
      .eq('id', id);

  Future<void> createMeal(MealDraft draft) async {
    await _client.rpc(
      'create_planned_meal',
      params: {
        'p_name': draft.name.trim(),
        'p_planned_date': _dateOnly(draft.plannedAt),
        'p_planned_time': draft.includeTime ? _timeOnly(draft.plannedAt) : null,
        'p_meal_slot': draft.mealSlot,
        'p_servings': draft.servings,
        'p_notes': draft.notes.trim(),
        'p_recipe_id': draft.recipeId,
        'p_ingredients': draft.ingredients
            .map((ingredient) => ingredient.toJson())
            .toList(),
      },
    );
  }

  Future<void> updateMeal(MealRecord meal, MealDraft draft) async {
    await _client
        .from('meals')
        .update({
          'planned_date': _dateOnly(draft.plannedAt),
          'planned_time': draft.includeTime ? _timeOnly(draft.plannedAt) : null,
          'meal_slot': draft.mealSlot,
          'name': draft.name.trim(),
          'servings': draft.servings,
          'notes': draft.notes.trim(),
          'updated_by': currentUserId,
        })
        .eq('id', meal.id);
    await _client.from('meal_ingredients').delete().eq('meal_id', meal.id);
    final rows = draft.ingredients
        .where((ingredient) => ingredient.label.trim().isNotEmpty)
        .toList()
        .asMap()
        .entries
        .map(
          (entry) => {
            'meal_id': meal.id,
            'label': entry.value.label.trim(),
            'quantity': _emptyToNull(entry.value.quantity),
            'unit': _emptyToNull(entry.value.unit),
            'have': entry.value.have,
            'sort_order': entry.key,
          },
        )
        .toList();
    if (rows.isNotEmpty) await _client.from('meal_ingredients').insert(rows);
  }

  Future<void> setIngredientHave(String id, bool have) async =>
      _client.from('meal_ingredients').update({'have': have}).eq('id', id);

  Future<void> setMealArchived(String id, bool archived) async => _client
      .from('meals')
      .update({
        'archived_at': archived
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'updated_by': currentUserId,
      })
      .eq('id', id);

  Future<void> setRecipeImage(
    String recipeId,
    Uint8List bytes, {
    required int width,
    required int height,
  }) async {
    final oldPathRow = await _client
        .from('recipes')
        .select('image_path')
        .eq('id', recipeId)
        .single();
    final oldPath = oldPathRow['image_path'] as String?;
    final profile = await _client
        .from('profiles')
        .select('household_id')
        .eq('id', currentUserId)
        .single();
    final householdId = profile['household_id'] as String;
    final path =
        '$householdId/recipes/$recipeId/${DateTime.now().microsecondsSinceEpoch}.jpg';
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
    try {
      await _client
          .from('recipes')
          .update({'image_path': path, 'updated_by': currentUserId})
          .eq('id', recipeId);
    } catch (_) {
      await _client.storage.from('household-media').remove([path]);
      rethrow;
    }
    if (oldPath != null && oldPath != path) {
      try {
        await _client.storage.from('household-media').remove([oldPath]);
      } catch (_) {
        // The current database path is valid; a stale private object can be
        // removed by maintenance without affecting protected recipe media.
      }
    }
  }

  Future<void> removeRecipeImage(String recipeId) async {
    final row = await _client
        .from('recipes')
        .select('image_path')
        .eq('id', recipeId)
        .single();
    final path = row['image_path'] as String?;
    await _client
        .from('recipes')
        .update({'image_path': null, 'updated_by': currentUserId})
        .eq('id', recipeId);
    if (path != null) {
      await _client.storage.from('household-media').remove([path]);
    }
  }
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _dateOnly(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _timeOnly(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
