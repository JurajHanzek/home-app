import '../../meals/domain/meal.dart';

class GeneralShoppingItem {
  const GeneralShoppingItem({
    required this.id,
    required this.label,
    required this.isDone,
    required this.createdBy,
    required this.createdAt,
    this.note,
    this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String label;
  final bool isDone;
  final String createdBy;
  final DateTime createdAt;
  final String? note;
  final DateTime? updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory GeneralShoppingItem.fromJson(Map<String, dynamic> json) =>
      GeneralShoppingItem(
        id: json['id'] as String,
        label: json['label'] as String,
        isDone: json['is_done'] as bool? ?? false,
        createdBy: json['created_by'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        note: json['note'] as String?,
        updatedAt: _parseDate(json['updated_at']),
        archivedAt: _parseDate(json['archived_at']),
      );
}

class MealShoppingGroup {
  const MealShoppingGroup({required this.meal, required this.missingItems});

  final MealRecord meal;
  final List<IngredientRecord> missingItems;
}

class ShoppingData {
  const ShoppingData({required this.meals, required this.generalItems});

  final List<MealRecord> meals;
  final List<GeneralShoppingItem> generalItems;

  List<MealShoppingGroup> nextMealGroups({required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = meals.where((meal) {
      if (meal.archivedAt != null) return false;
      final planned = meal.plannedAt.toLocal();
      final day = DateTime(planned.year, planned.month, planned.day);
      if (day.isBefore(today)) return false;
      if (day == today && meal.hasTime && planned.isBefore(now)) return false;
      return true;
    }).toList()..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));

    return upcoming.take(2).map((meal) {
      final missing = meal.ingredients.where((item) => !item.have).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return MealShoppingGroup(meal: meal, missingItems: missing);
    }).toList();
  }
}

DateTime? _parseDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);
