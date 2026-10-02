class IngredientRecord {
  const IngredientRecord({
    required this.id,
    required this.label,
    this.quantity,
    this.unit,
    this.have = false,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final String? quantity;
  final String? unit;
  final bool have;
  final int sortOrder;

  factory IngredientRecord.fromJson(Map<String, dynamic> json) =>
      IngredientRecord(
        id: json['id'] as String,
        label: json['label'] as String,
        quantity: json['quantity'] as String?,
        unit: json['unit'] as String?,
        have: json['have'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}

class IngredientDraft {
  const IngredientDraft({
    required this.label,
    this.quantity,
    this.unit,
    this.have = false,
    this.sortOrder = 0,
  });

  final String label;
  final String? quantity;
  final String? unit;
  final bool have;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'label': label.trim(),
    'quantity': _emptyToNull(quantity),
    'unit': _emptyToNull(unit),
    'have': have,
    'sort_order': sortOrder,
  };
}

class RecipeRecord {
  const RecipeRecord({
    required this.id,
    required this.name,
    required this.instructions,
    required this.ingredients,
    required this.createdAt,
    this.imagePath,
    this.imageUrl,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String instructions;
  final String? imagePath;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime? archivedAt;
  final List<IngredientRecord> ingredients;

  bool get archived => archivedAt != null;

  RecipeRecord withImageUrl(String? value) => RecipeRecord(
    id: id,
    name: name,
    instructions: instructions,
    ingredients: ingredients,
    createdAt: createdAt,
    imagePath: imagePath,
    imageUrl: value,
    archivedAt: archivedAt,
  );

  factory RecipeRecord.fromJson(Map<String, dynamic> json) => RecipeRecord(
    id: json['id'] as String,
    name: json['name'] as String,
    instructions: json['instructions'] as String? ?? '',
    imagePath: json['image_path'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    archivedAt: _date(json['archived_at']),
    ingredients:
        _children(
            json['recipe_ingredients'],
          ).map(IngredientRecord.fromJson).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
  );
}

class MealRecord {
  const MealRecord({
    required this.id,
    required this.name,
    required this.plannedAt,
    this.mealTime,
    required this.servings,
    required this.notes,
    required this.ingredients,
    this.mealSlot,
    this.recipeId,
    this.recipeImagePath,
    this.recipeImageUrl,
    this.archivedAt,
  });

  final String id;
  final String name;
  final DateTime plannedAt;
  final String? mealTime;
  final String? mealSlot;
  final String? recipeId;
  final String? recipeImagePath;
  final String? recipeImageUrl;
  final int servings;
  final String notes;
  final DateTime? archivedAt;
  final List<IngredientRecord> ingredients;

  int get availableIngredients => ingredients.where((item) => item.have).length;
  bool get hasMissingIngredients => ingredients.any((item) => !item.have);
  bool get hasTime => mealTime != null;

  MealRecord withRecipeImageUrl(String? value) => MealRecord(
    id: id,
    name: name,
    plannedAt: plannedAt,
    mealTime: mealTime,
    servings: servings,
    notes: notes,
    ingredients: ingredients,
    mealSlot: mealSlot,
    recipeId: recipeId,
    recipeImagePath: recipeImagePath,
    recipeImageUrl: value,
    archivedAt: archivedAt,
  );

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    final recipe = json['recipes'] is Map<String, dynamic>
        ? json['recipes'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final children =
        _children(
            json['meal_ingredients'],
          ).map(IngredientRecord.fromJson).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final date = DateTime.parse(json['planned_date'] as String);
    final time = json['planned_time'] as String?;
    final timeParts = time?.split(':') ?? const <String>[];
    final plannedAt = DateTime(
      date.year,
      date.month,
      date.day,
      timeParts.isEmpty ? 0 : int.parse(timeParts[0]),
      timeParts.length < 2 ? 0 : int.parse(timeParts[1]),
    );
    return MealRecord(
      id: json['id'] as String,
      name: json['name'] as String,
      plannedAt: plannedAt,
      mealTime: time,
      mealSlot: json['meal_slot'] as String?,
      recipeId: json['recipe_id'] as String?,
      recipeImagePath: recipe['image_path'] as String?,
      servings: json['servings'] as int? ?? 2,
      notes: json['notes'] as String? ?? '',
      archivedAt: _date(json['archived_at']),
      ingredients: children,
    );
  }
}

class MealDraft {
  const MealDraft({
    required this.name,
    required this.plannedAt,
    this.includeTime = false,
    required this.servings,
    required this.notes,
    required this.ingredients,
    this.mealSlot,
    this.recipeId,
  });

  final String name;
  final DateTime plannedAt;
  final bool includeTime;
  final String? mealSlot;
  final String? recipeId;
  final int servings;
  final String notes;
  final List<IngredientDraft> ingredients;
}

class RecipeDraft {
  const RecipeDraft({
    required this.name,
    required this.instructions,
    required this.ingredients,
  });

  final String name;
  final String instructions;
  final List<IngredientDraft> ingredients;
}

class MealsData {
  const MealsData({required this.recipes, required this.meals});

  final List<RecipeRecord> recipes;
  final List<MealRecord> meals;
}

List<Map<String, dynamic>> _children(dynamic value) =>
    (value as List<dynamic>? ?? const <dynamic>[]).cast<Map<String, dynamic>>();

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
