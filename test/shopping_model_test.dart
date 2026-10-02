import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/meals/domain/meal.dart';
import 'package:home_hub/features/shopping/domain/shopping.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12);

  test('chooses the next two active upcoming meals chronologically', () {
    final data = ShoppingData(
      meals: [
        _meal('tomorrow', DateTime(2026, 10, 3, 8)),
        _meal('today-late', DateTime(2026, 10, 2, 18), mealTime: '18:00'),
        _meal('past', DateTime(2026, 10, 1, 18)),
        _meal('today-early', DateTime(2026, 10, 2, 10), mealTime: '10:00'),
        _meal('archived', DateTime(2026, 10, 2, 20), archived: true),
        _meal('later', DateTime(2026, 10, 4, 18)),
      ],
      generalItems: const [],
    );

    expect(data.nextMealGroups(now: now).map((group) => group.meal.id), [
      'today-late',
      'tomorrow',
    ]);
  });

  test(
    'shows only missing ingredients, grouped with exact labels and duplicates',
    () {
      final data = ShoppingData(
        meals: [
          _meal(
            'one',
            DateTime(2026, 10, 2, 18),
            mealTime: '18:00',
            ingredients: [
              _ingredient('one-rice', 'rice', order: 0),
              _ingredient('one-luk', 'luk', order: 1),
              _ingredient('have-water', 'water', have: true, order: 2),
            ],
          ),
          _meal(
            'two',
            DateTime(2026, 10, 3, 18),
            mealTime: '18:00',
            ingredients: [
              _ingredient('two-rice', 'rice', order: 0),
              _ingredient('two-onion', 'crveni luk', order: 1),
            ],
          ),
        ],
        generalItems: const [],
      );

      final groups = data.nextMealGroups(now: now);
      expect(groups, hasLength(2));
      expect(groups[0].missingItems.map((item) => item.label), ['rice', 'luk']);
      expect(groups[1].missingItems.map((item) => item.label), [
        'rice',
        'crveni luk',
      ]);
      expect(groups[0].missingItems.first.id, 'one-rice');
      expect(groups[1].missingItems.first.id, 'two-rice');
    },
  );

  test(
    'handles fewer than two upcoming meals and meals with no missing items',
    () {
      final data = ShoppingData(
        meals: [
          _meal(
            'dinner',
            DateTime(2026, 10, 2, 19),
            mealTime: '19:00',
            ingredients: [_ingredient('have', 'salt', have: true, order: 0)],
          ),
        ],
        generalItems: const [],
      );
      final groups = data.nextMealGroups(now: now);
      expect(groups, hasLength(1));
      expect(groups.single.missingItems, isEmpty);
    },
  );
}

MealRecord _meal(
  String id,
  DateTime planned, {
  String? mealTime,
  bool archived = false,
  List<IngredientRecord> ingredients = const [],
}) => MealRecord(
  id: id,
  name: id,
  plannedAt: planned,
  mealTime: mealTime,
  servings: 2,
  notes: '',
  ingredients: ingredients,
  archivedAt: archived ? DateTime(2026, 10, 1) : null,
);

IngredientRecord _ingredient(
  String id,
  String label, {
  bool have = false,
  int order = 0,
}) => IngredientRecord(id: id, label: label, have: have, sortOrder: order);
