import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/meals/domain/meal.dart';

void main() {
  test(
    'separate planned meals parse independent have state and exact strings',
    () {
      final first = MealRecord.fromJson(
        _meal(
          id: 'meal-a',
          ingredientId: 'ingredient-a',
          have: true,
          label: 'Rice',
        ),
      );
      final second = MealRecord.fromJson(
        _meal(
          id: 'meal-b',
          ingredientId: 'ingredient-b',
          have: false,
          label: 'Rice',
        ),
      );

      expect(first.ingredients.single.have, isTrue);
      expect(second.ingredients.single.have, isFalse);
      expect(first.ingredients.single.id, isNot(second.ingredients.single.id));
    },
  );

  test('meal ingredient snapshot is independent of a recipe edit', () {
    final recipeJson = {
      'id': 'recipe-1',
      'name': 'Rice bowl',
      'instructions': '',
      'created_at': '2026-10-01T10:00:00Z',
      'recipe_ingredients': [
        {'id': 'recipe-ingredient-1', 'label': 'Rice', 'sort_order': 0},
      ],
    };
    final mealJson = _meal(
      id: 'meal-1',
      ingredientId: 'meal-ingredient-1',
      have: false,
      label: 'Rice',
    );
    final recipe = RecipeRecord.fromJson(recipeJson);
    final meal = MealRecord.fromJson(mealJson);

    (recipeJson['recipe_ingredients'] as List).single['label'] = 'Brown rice';

    expect(recipe.ingredients.single.label, 'Rice');
    expect(meal.ingredients.single.label, 'Rice');
    expect(recipe.ingredients.single.id, isNot(meal.ingredients.single.id));
  });

  test(
    'custom meal needs no recipe and preserves unnormalized ingredient text',
    () {
      final meal = MealRecord.fromJson({
        ..._meal(
          id: 'custom-meal',
          ingredientId: 'custom-ingredient',
          have: false,
          label: 'crveni luk',
        ),
        'recipe_id': null,
        'meal_ingredients': [
          {
            'id': 'custom-ingredient',
            'label': 'crveni luk',
            'quantity': '2',
            'unit': 'pcs',
            'have': false,
            'sort_order': 0,
          },
        ],
      });

      expect(meal.recipeId, isNull);
      expect(meal.ingredients.single.label, 'crveni luk');
      expect(meal.ingredients.single.quantity, '2');
      expect(meal.ingredients.single.unit, 'pcs');
    },
  );

  test('planned date supports an optional time', () {
    final meal = MealRecord.fromJson({
      ..._meal(
        id: 'meal-without-time',
        ingredientId: 'ingredient-1',
        have: false,
        label: 'Rice',
      ),
      'planned_time': null,
    });

    expect(meal.hasTime, isFalse);
    expect(meal.plannedAt.hour, 0);
  });
}

Map<String, dynamic> _meal({
  required String id,
  required String ingredientId,
  required bool have,
  required String label,
}) => {
  'id': id,
  'name': 'Rice bowl',
  'planned_date': '2026-10-04',
  'planned_time': '18:00:00',
  'meal_slot': 'dinner',
  'recipe_id': 'recipe-1',
  'servings': 2,
  'notes': '',
  'meal_ingredients': [
    {
      'id': ingredientId,
      'label': label,
      'quantity': null,
      'unit': null,
      'have': have,
      'sort_order': 0,
    },
  ],
  'recipes': {'image_path': null},
};
