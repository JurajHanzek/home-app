import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/meals/domain/meal.dart';
import 'package:home_hub/features/shopping/data/shopping_repository.dart';
import 'package:home_hub/features/shopping/domain/shopping.dart';
import 'package:home_hub/features/shopping/presentation/shopping_screen.dart';

void main() {
  testWidgets('General items and meal ingredients use independent actions', (
    tester,
  ) async {
    final repository = _ShoppingRepositoryFake();
    final data = ShoppingData(
      meals: [
        MealRecord(
          id: 'meal-1',
          name: 'Dinner',
          plannedAt: DateTime.now().add(const Duration(hours: 4)),
          mealTime: '18:00',
          servings: 2,
          notes: '',
          ingredients: const [
            IngredientRecord(id: 'meal-ingredient-1', label: 'rice'),
            IngredientRecord(id: 'meal-ingredient-2', label: 'rice'),
          ],
        ),
      ],
      generalItems: [
        GeneralShoppingItem(
          id: 'general-1',
          label: 'Bread',
          isDone: false,
          createdBy: 'user-a',
          createdAt: DateTime(2026, 10, 1),
        ),
      ],
    );
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shoppingProvider.overrideWith((ref) async => data),
          shoppingRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          theme: AppTheme.forMode(HomeHubTheme.dark),
          home: const Scaffold(body: ShoppingScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    expect(find.text('Bread'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('general-general-1')));
    await tester.pumpAndSettle();
    expect(repository.generalDoneUpdates, [('general-1', true)]);

    await tester.enterText(find.byType(TextField).first, ' rice ');
    await tester.tap(find.byTooltip('Add item'));
    await tester.pumpAndSettle();
    expect(repository.addedLabels, [' rice ']);

    await tester.tap(find.text('Next 2 meals'));
    await tester.pumpAndSettle();
    expect(find.text('Dinner'), findsOneWidget);
    expect(find.text('rice'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const ValueKey('meal-meal-1-ingredient-meal-ingredient-2')),
    );
    await tester.pumpAndSettle();
    expect(repository.mealHaveUpdates, [('meal-ingredient-2', true)]);
    expect(repository.generalDoneUpdates, [('general-1', true)]);
  });
}

class _ShoppingRepositoryFake extends Fake implements ShoppingRepository {
  final List<String> addedLabels = [];
  final List<(String, bool)> generalDoneUpdates = [];
  final List<(String, bool)> mealHaveUpdates = [];

  @override
  Future<void> addGeneralItem(String label) async => addedLabels.add(label);

  @override
  Future<void> setGeneralItemDone(String id, bool isDone) async =>
      generalDoneUpdates.add((id, isDone));

  @override
  Future<void> setMealIngredientHave(String id, bool have) async =>
      mealHaveUpdates.add((id, have));
}
