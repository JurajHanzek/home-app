import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/meals/domain/meal.dart';
import 'package:home_hub/features/meals/presentation/meal_editors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recipe editor previews a picked image before saving', (
    tester,
  ) async {
    final bytes = Uint8List.fromList(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/jZsAAAAASUVORK5CYII=',
      ),
    );
    const channel = MethodChannel('app.homehub/task_images');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => {'bytes': bytes, 'width': 1, 'height': 1},
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    RecipeEditorResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showRecipeEditor(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Choose image'));
    await tester.tap(find.text('Choose image'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Clear selection'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Soup');
    await tester.ensureVisible(find.text('Save recipe'));
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(result?.image?.bytes, bytes);
  });

  testWidgets('recipe editor can mark an existing image for removal', (
    tester,
  ) async {
    RecipeEditorResult? result;
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showRecipeEditor(
                  context,
                  recipe: RecipeRecord(
                    id: 'recipe-id',
                    name: 'Soup',
                    instructions: '',
                    ingredients: const [],
                    createdAt: DateTime(2026),
                    imagePath: 'household/recipes/recipe/image.jpg',
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Remove image'), findsOneWidget);
    await tester.tap(find.text('Remove image'));
    await tester.pumpAndSettle();
    expect(find.text('Keep image'), findsOneWidget);
    await tester.tap(find.text('Save recipe'));
    await tester.pumpAndSettle();
    expect(result?.removeImage, isTrue);
    expect(result?.image, isNull);
  });

  testWidgets('custom meal only offers recipe images when saving as recipe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showMealEditor(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose recipe image'), findsNothing);
    await tester.ensureVisible(find.text('Also save as a reusable recipe'));
    await tester.tap(find.text('Also save as a reusable recipe'));
    await tester.pumpAndSettle();
    expect(find.text('Choose recipe image'), findsOneWidget);
  });
}
