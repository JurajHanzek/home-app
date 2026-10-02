import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/meals_repository.dart';
import '../domain/meal.dart';
import 'meal_editors.dart';

enum _MealsSection { planned, recipes }

class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key, this.detailId, this.recipeDetail = false});
  final String? detailId;
  final bool recipeDetail;

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  _MealsSection _section = _MealsSection.planned;
  bool _showPastMeals = false;
  bool _showArchivedMeals = false;
  bool _showArchivedRecipes = false;

  Future<void> _reload() async {
    try {
      await ref.refresh(mealsProvider.future).then<void>((_) {});
    } catch (_) {
      // The provider reports load failures through its retry state.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(mealsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _MealsError(onRetry: _reload),
      data: (data) => _content(data),
    );
  }

  Widget _content(MealsData data) {
    if (widget.detailId != null) {
      if (widget.recipeDetail) {
        final recipe = data.recipes
            .where((item) => item.id == widget.detailId)
            .firstOrNull;
        if (recipe == null) {
          return const Center(child: Text('Recipe no longer available'));
        }
        return _recipeDetails(
          recipe,
          onEdit: () => _saveRecipe(recipe: recipe),
          onPlan: () => _editMeal(null, fromRecipe: recipe),
        );
      }
      final meal = data.meals
          .where((item) => item.id == widget.detailId)
          .firstOrNull;
      if (meal == null) {
        return const Center(child: Text('Meal no longer available'));
      }
      return Column(
        children: [
          if (meal.archivedAt != null)
            ListTile(
              title: const Text('Archived'),
              trailing: TextButton(
                onPressed: () => _restoreMeal(meal),
                child: const Text('Restore'),
              ),
            ),
          Expanded(
            child: _MealDetails(
              meal: meal,
              repository: ref.read(mealsRepositoryProvider),
              onEdit: () => _editMeal(meal),
              onChanged: _reload,
            ),
          ),
        ],
      );
    }
    final recipes = data.recipes
        .where((recipe) => recipe.archived == _showArchivedRecipes)
        .toList();
    final startOfToday = DateTime.now();
    final today = DateTime(
      startOfToday.year,
      startOfToday.month,
      startOfToday.day,
    );
    final meals = data.meals.where((meal) {
      if (_showArchivedMeals) return meal.archivedAt != null;
      if (meal.archivedAt != null) return false;
      return _showPastMeals
          ? meal.plannedAt.isBefore(today)
          : !meal.plannedAt.isBefore(today);
    }).toList()..sort((a, b) => a.plannedAt.compareTo(b.plannedAt));

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<_MealsSection>(
                segments: const [
                  ButtonSegment(
                    value: _MealsSection.planned,
                    icon: Icon(Icons.event_note_outlined),
                    label: Text('Planned meals'),
                  ),
                  ButtonSegment(
                    value: _MealsSection.recipes,
                    icon: Icon(Icons.menu_book_outlined),
                    label: Text('Recipes'),
                  ),
                ],
                selected: {_section},
                onSelectionChanged: (value) => setState(() {
                  _section = value.first;
                }),
                showSelectedIcon: false,
              ),
            ),
            Expanded(
              child: _section == _MealsSection.planned
                  ? _mealList(meals, data)
                  : _recipeList(recipes),
            ),
          ],
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: FloatingActionButton.extended(
            onPressed: _section == _MealsSection.planned
                ? () => _addMeal(data)
                : () => _saveRecipe(),
            icon: const Icon(Icons.add),
            label: Text(
              _section == _MealsSection.planned ? 'Add meal' : 'New recipe',
            ),
          ),
        ),
      ],
    );
  }

  Widget _mealList(List<MealRecord> meals, MealsData data) {
    final title = _showArchivedMeals
        ? 'Archived meals'
        : _showPastMeals
        ? 'Past meals'
        : 'Coming up';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 12, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (!_showArchivedMeals)
                PopupMenuButton<String>(
                  tooltip: 'Meal history',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (action) => setState(() {
                    _showPastMeals = action == 'past';
                    _showArchivedMeals = action == 'archived';
                  }),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: _showPastMeals ? 'upcoming' : 'past',
                      child: Text(
                        _showPastMeals ? 'Upcoming meals' : 'Past meals',
                      ),
                    ),
                    PopupMenuItem(
                      value: 'archived',
                      child: Text(
                        'Archived meals (${data.meals.where((m) => m.archivedAt != null).length})',
                      ),
                    ),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: () => setState(() => _showArchivedMeals = false),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Active'),
                ),
            ],
          ),
        ),
        Expanded(
          child: meals.isEmpty
              ? _MealsEmpty(
                  message: _showArchivedMeals
                      ? 'No archived meals'
                      : _showPastMeals
                      ? 'No past meals'
                      : 'Nothing planned yet',
                  detail: _showArchivedMeals
                      ? 'Archived meals can be restored here.'
                      : _showPastMeals
                      ? 'Past meals will be kept here.'
                      : 'Plan a meal or choose one from your recipes.',
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: meals.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _MealCard(
                      meal: meals[index],
                      onTap: () => _showMeal(meals[index]),
                      onEdit: () => _editMeal(meals[index]),
                      onArchive: () => _archiveMeal(meals[index]),
                      onRestore: () => _restoreMeal(meals[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _recipeList(List<RecipeRecord> recipes) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 12, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _showArchivedRecipes ? 'Archived recipes' : 'Recipe library',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _showArchivedRecipes = !_showArchivedRecipes),
              icon: Icon(
                _showArchivedRecipes
                    ? Icons.arrow_back
                    : Icons.archive_outlined,
                size: 18,
              ),
              label: Text(_showArchivedRecipes ? 'Active' : 'Archived'),
            ),
          ],
        ),
      ),
      Expanded(
        child: recipes.isEmpty
            ? _MealsEmpty(
                message: _showArchivedRecipes
                    ? 'No archived recipes'
                    : 'No recipes yet',
                detail: _showArchivedRecipes
                    ? 'Archived recipes can be restored here.'
                    : 'Save favorite meals here to reuse them.',
              )
            : RefreshIndicator(
                onRefresh: _reload,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                  itemCount: recipes.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _RecipeCard(
                    recipe: recipes[index],
                    onTap: () => _showRecipe(recipes[index]),
                    onEdit: () => _saveRecipe(recipe: recipes[index]),
                    onToggleArchived: () => _setRecipeArchived(recipes[index]),
                  ),
                ),
              ),
      ),
    ],
  );

  Future<void> _addMeal(MealsData data) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Add meal')),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('From a recipe'),
              onTap: () => Navigator.pop(context, 'recipe'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('New meal'),
              subtitle: const Text(
                'Plan a custom meal without saving a recipe',
              ),
              onTap: () => Navigator.pop(context, 'custom'),
            ),
          ],
        ),
      ),
    );
    if (action == 'custom') {
      await _editMeal(null);
    } else if (action == 'recipe') {
      final activeRecipes = data.recipes.where((r) => !r.archived).toList();
      if (activeRecipes.isEmpty) {
        setState(() => _section = _MealsSection.recipes);
        _message('Create a recipe first, then plan a meal from it.');
        return;
      }
      final recipe = await _chooseRecipe(activeRecipes);
      if (recipe != null) await _editMeal(null, fromRecipe: recipe);
    }
  }

  Future<RecipeRecord?> _chooseRecipe(
    List<RecipeRecord> recipes,
  ) => showModalBottomSheet<RecipeRecord>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: [
            const ListTile(title: Text('Choose a recipe')),
            Expanded(
              child: recipes.isEmpty
                  ? const Center(child: Text('Create a recipe first.'))
                  : ListView.builder(
                      itemCount: recipes.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: recipes[index].imageUrl == null
                            ? const Icon(Icons.restaurant_outlined)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  recipes[index].imageUrl!,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                        title: Text(recipes[index].name),
                        subtitle: Text(
                          '${recipes[index].ingredients.length} ingredients',
                        ),
                        onTap: () => Navigator.pop(context, recipes[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _editMeal(MealRecord? meal, {RecipeRecord? fromRecipe}) async {
    final result = await showMealEditor(
      context,
      meal: meal,
      fromRecipe: fromRecipe,
    );
    if (result == null) return;
    var imageSaveFailed = false;
    try {
      final repository = ref.read(mealsRepositoryProvider);
      var draft = result.draft;
      if (result.saveAsRecipe) {
        final recipeId = await repository.createRecipe(
          RecipeDraft(
            name: draft.name,
            instructions: draft.notes,
            ingredients: draft.ingredients,
          ),
        );
        if (result.recipeImage case final image?) {
          try {
            await repository.setRecipeImage(
              recipeId,
              image.bytes,
              width: image.width,
              height: image.height,
            );
          } catch (_) {
            imageSaveFailed = true;
          }
        }
        draft = MealDraft(
          name: draft.name,
          plannedAt: draft.plannedAt,
          includeTime: draft.includeTime,
          mealSlot: draft.mealSlot,
          recipeId: recipeId,
          servings: draft.servings,
          notes: draft.notes,
          ingredients: draft.ingredients,
        );
      }
      if (meal == null) {
        await repository.createMeal(draft);
      } else {
        await repository.updateMeal(meal, draft);
      }
      await _reload();
      if (imageSaveFailed && mounted) {
        _message(
          'Meal and recipe saved, but the recipe image could not be uploaded.',
        );
      }
    } catch (_) {
      await _reload();
      if (mounted) _message('Could not save the meal. Try again.');
    }
  }

  Future<void> _showMeal(MealRecord meal) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _MealDetails(
      meal: meal,
      repository: ref.read(mealsRepositoryProvider),
      onEdit: () {
        Navigator.pop(context);
        _editMeal(meal);
      },
      onChanged: _reload,
    ),
  );

  Future<void> _archiveMeal(MealRecord meal) async {
    try {
      await ref.read(mealsRepositoryProvider).setMealArchived(meal.id, true);
      await _reload();
    } catch (_) {
      if (mounted) _message('Could not archive this meal.');
    }
  }

  Future<void> _restoreMeal(MealRecord meal) async {
    try {
      await ref.read(mealsRepositoryProvider).setMealArchived(meal.id, false);
      await _reload();
    } catch (_) {
      if (mounted) _message('Could not restore this meal.');
    }
  }

  Future<void> _showRecipe(RecipeRecord recipe) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (dialogContext) => _recipeDetails(
        recipe,
        onEdit: () => Navigator.pop(dialogContext, 'edit'),
        onPlan: () => Navigator.pop(dialogContext, 'plan'),
      ),
    );
    if (action == 'plan') await _editMeal(null, fromRecipe: recipe);
    if (action == 'edit') await _saveRecipe(recipe: recipe);
  }

  Widget _recipeDetails(
    RecipeRecord recipe, {
    required VoidCallback onEdit,
    required VoidCallback onPlan,
  }) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          if (recipe.archived)
            ListTile(
              title: const Text('Archived'),
              trailing: TextButton(
                onPressed: () => _setRecipeArchived(recipe),
                child: const Text('Restore'),
              ),
            ),
          if (recipe.imageUrl != null)
            Image.network(
              recipe.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ListTile(
            title: Text(recipe.name),
            subtitle: Text(
              recipe.instructions.isEmpty ? 'Ingredients' : recipe.instructions,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final ingredient in recipe.ingredients)
                  ListTile(
                    dense: true,
                    title: Text(ingredient.label),
                    trailing: Text(
                      [ingredient.quantity, ingredient.unit]
                          .whereType<String>()
                          .where((value) => value.isNotEmpty)
                          .join(' '),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPlan,
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Plan meal'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _saveRecipe({RecipeRecord? recipe}) async {
    final result = await showRecipeEditor(context, recipe: recipe);
    if (result == null) return;
    var recipeSaved = false;
    try {
      final repository = ref.read(mealsRepositoryProvider);
      final String id;
      if (recipe == null) {
        id = await repository.createRecipe(result.draft);
        recipeSaved = true;
      } else {
        id = recipe.id;
        await repository.updateRecipe(id, result.draft);
        recipeSaved = true;
      }
      final image = result.image;
      if (image != null) {
        await repository.setRecipeImage(
          id,
          image.bytes,
          width: image.width,
          height: image.height,
        );
      } else if (result.removeImage && recipe != null) {
        await repository.removeRecipeImage(id);
      }
      await _reload();
    } catch (_) {
      await _reload();
      if (mounted) {
        _message(
          recipeSaved
              ? 'Recipe saved, but its image could not be uploaded.'
              : 'Could not save the recipe. Try again.',
        );
      }
    }
  }

  Future<void> _setRecipeArchived(RecipeRecord recipe) async {
    try {
      await ref
          .read(mealsRepositoryProvider)
          .setRecipeArchived(recipe.id, !recipe.archived);
      await _reload();
    } catch (_) {
      if (mounted) _message('Could not update this recipe.');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.meal,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final MealRecord meal;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final missing = meal.ingredients.length - meal.availableIngredients;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            if (meal.recipeImageUrl != null)
              Image.network(
                meal.recipeImageUrl!,
                width: 88,
                height: 104,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _mealIcon(context),
              )
            else
              _mealIcon(context),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      meal.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_weekdayDate(meal.plannedAt)}${meal.hasTime ? '  ·  ${_time(meal.plannedAt)}' : ''}${meal.mealSlot == null ? '' : '  ·  ${_titleCase(meal.mealSlot!)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text('${meal.servings} servings'),
                    const SizedBox(height: 4),
                    if (meal.ingredients.isEmpty)
                      const Text('No ingredients added')
                    else
                      Text(
                        missing == 0
                            ? '${meal.availableIngredients}/${meal.ingredients.length} ingredients available'
                            : '$missing ingredients still needed',
                        style: TextStyle(
                          color: missing == 0
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.tertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Meal options',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'archive') onArchive();
                if (value == 'restore') onRestore();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit meal')),
                PopupMenuItem(
                  value: meal.archivedAt == null ? 'archive' : 'restore',
                  child: Text(meal.archivedAt == null ? 'Archive' : 'Restore'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mealIcon(BuildContext context) => Container(
    width: 88,
    height: 104,
    color: Theme.of(context).colorScheme.secondaryContainer,
    alignment: Alignment.center,
    child: Icon(
      Icons.restaurant_outlined,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.recipe,
    required this.onTap,
    required this.onEdit,
    required this.onToggleArchived,
  });

  final RecipeRecord recipe;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchived;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Row(
      children: [
        if (recipe.imageUrl != null)
          Image.network(
            recipe.imageUrl!,
            width: 112,
            height: 104,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _recipeIcon(context),
          )
        else
          _recipeIcon(context),
        Expanded(
          child: ListTile(
            onTap: onTap,
            title: Text(
              recipe.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('${recipe.ingredients.length} ingredients'),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Recipe options',
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'archive' || value == 'restore') onToggleArchived();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: recipe.archived ? 'restore' : 'archive',
              child: Text(recipe.archived ? 'Restore' : 'Archive'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _recipeIcon(BuildContext context) => Container(
    width: 112,
    height: 104,
    alignment: Alignment.center,
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Icon(
      Icons.menu_book_outlined,
      size: 36,
      color: Theme.of(context).colorScheme.onSecondaryContainer,
    ),
  );
}

class _MealDetails extends StatefulWidget {
  const _MealDetails({
    required this.meal,
    required this.repository,
    required this.onEdit,
    required this.onChanged,
  });

  final MealRecord meal;
  final MealsRepository repository;
  final VoidCallback onEdit;
  final Future<void> Function() onChanged;

  @override
  State<_MealDetails> createState() => _MealDetailsState();
}

class _MealDetailsState extends State<_MealDetails> {
  late final Map<String, bool> _have = {
    for (final item in widget.meal.ingredients) item.id: item.have,
  };
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final meal = widget.meal;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            ListTile(
              title: Text(meal.name),
              subtitle: Text(
                '${_weekdayDate(meal.plannedAt)}${meal.hasTime ? ' · ${_time(meal.plannedAt)}' : ''} · ${meal.servings} servings',
              ),
              trailing: IconButton(
                tooltip: 'Edit meal',
                onPressed: widget.onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            if (meal.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(meal.notes),
                ),
              ),
            const Divider(),
            Expanded(
              child: meal.ingredients.isEmpty
                  ? const Center(child: Text('No ingredients added'))
                  : ListView(
                      children: [
                        for (final item in meal.ingredients)
                          CheckboxListTile(
                            value: _have[item.id] ?? item.have,
                            onChanged: _saving
                                ? null
                                : (value) => _toggle(item.id, value ?? false),
                            title: Text(item.label),
                            subtitle: item.quantity == null && item.unit == null
                                ? null
                                : Text(
                                    [item.quantity, item.unit]
                                        .whereType<String>()
                                        .where((text) => text.isNotEmpty)
                                        .join(' '),
                                  ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggle(String id, bool value) async {
    setState(() {
      _saving = true;
      _have[id] = value;
    });
    try {
      await widget.repository.setIngredientHave(id, value);
      await widget.onChanged();
    } catch (_) {
      if (mounted) {
        setState(() => _have[id] = !value);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update ingredient.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _MealsEmpty extends StatelessWidget {
  const _MealsEmpty({required this.message, required this.detail});

  final String message;
  final String detail;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_outlined, size: 44),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(detail, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _MealsError extends StatelessWidget {
  const _MealsError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          const Text(
            'Meals could not be loaded. Confirm the Phase 3 database migration is applied and check your connection.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

String _weekdayDate(DateTime value) {
  final local = value.toLocal();
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]}';
}

String _time(DateTime value) =>
    '${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
