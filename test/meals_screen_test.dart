import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/meals/data/meals_repository.dart';
import 'package:home_hub/features/meals/domain/meal.dart';
import 'package:home_hub/features/meals/presentation/meals_screen.dart';

void main() {
  testWidgets('upcoming meals are the default and recipes are easy to open', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final meals = MealsData(
      recipes: [
        RecipeRecord(
          id: 'recipe-1',
          name: 'Pasta',
          instructions: 'Boil water',
          ingredients: const [],
          createdAt: now,
          imagePath: 'household/recipes/recipe-1/image.jpg',
          imageUrl: 'https://images.invalid/recipe.jpg',
        ),
      ],
      meals: [
        MealRecord(
          id: 'upcoming',
          name: 'Pasta',
          plannedAt: today.add(const Duration(days: 1, hours: 18)),
          servings: 2,
          notes: '',
          ingredients: const [],
          recipeImagePath: 'household/recipes/recipe-1/image.jpg',
          recipeImageUrl: 'https://images.invalid/recipe.jpg',
        ),
        MealRecord(
          id: 'past',
          name: 'Yesterday meal',
          plannedAt: today.subtract(const Duration(days: 1)),
          servings: 2,
          notes: '',
          ingredients: const [],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mealsProvider.overrideWith((ref) async => meals)],
        child: MaterialApp(
          theme: AppTheme.forMode(HomeHubTheme.dark),
          home: const Scaffold(body: MealsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coming up'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
    expect(find.text('Yesterday meal'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) => widget is Image && widget.width == 88),
      findsOneWidget,
    );

    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    expect(find.text('Recipe library'), findsOneWidget);
    expect(find.text('Pasta'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Image && widget.width == 112,
      ),
      findsOneWidget,
    );
  });
}
