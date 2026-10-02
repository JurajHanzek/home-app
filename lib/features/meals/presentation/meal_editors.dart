import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../tasks/data/task_image_picker.dart';
import '../domain/meal.dart';
import 'ingredient_editor.dart';

class RecipeEditorResult {
  const RecipeEditorResult(this.draft, {this.image, this.removeImage = false});

  final RecipeDraft draft;
  final PreparedTaskImage? image;
  final bool removeImage;
}

class MealEditorResult {
  const MealEditorResult(
    this.draft, {
    this.saveAsRecipe = false,
    this.recipeImage,
  });

  final MealDraft draft;
  final bool saveAsRecipe;
  final PreparedTaskImage? recipeImage;
}

Future<RecipeEditorResult?> showRecipeEditor(
  BuildContext context, {
  RecipeRecord? recipe,
}) => showDialog<RecipeEditorResult>(
  context: context,
  builder: (_) => _RecipeEditor(recipe: recipe),
);

Future<MealEditorResult?> showMealEditor(
  BuildContext context, {
  MealRecord? meal,
  RecipeRecord? fromRecipe,
}) => showDialog<MealEditorResult>(
  context: context,
  builder: (_) => _MealEditor(meal: meal, fromRecipe: fromRecipe),
);

class _RecipeEditor extends StatefulWidget {
  const _RecipeEditor({this.recipe});

  final RecipeRecord? recipe;

  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  final _formKey = GlobalKey<FormState>();
  final _ingredientsKey = GlobalKey<IngredientEditorState>();
  late final TextEditingController _name;
  late final TextEditingController _instructions;
  PreparedTaskImage? _image;
  bool _removeImage = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.recipe?.name ?? '');
    _instructions = TextEditingController(
      text: widget.recipe?.instructions ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: Text(widget.recipe == null ? 'New recipe' : 'Edit recipe'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a recipe name'
                    : null,
                decoration: const InputDecoration(labelText: 'Recipe name'),
              ),
              TextField(
                controller: _instructions,
                maxLines: 3,
                maxLength: 4000,
                decoration: const InputDecoration(
                  labelText: 'Instructions or notes',
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text('Ingredients'),
                ),
              ),
              IngredientEditor(
                key: _ingredientsKey,
                initial:
                    widget.recipe?.ingredients
                        .map(
                          (item) => IngredientDraft(
                            label: item.label,
                            quantity: item.quantity,
                            unit: item.unit,
                            sortOrder: item.sortOrder,
                          ),
                        )
                        .toList() ??
                    const [],
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 12, bottom: 6),
                  child: Text('Recipe image (optional)'),
                ),
              ),
              _imagePreview(
                context,
                bytes: _image?.bytes,
                url: _removeImage ? null : widget.recipe?.imageUrl,
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: Text(
                      _image == null && widget.recipe?.imagePath == null
                          ? 'Choose image'
                          : 'Replace image',
                    ),
                  ),
                  if (_image != null)
                    TextButton.icon(
                      onPressed: () => setState(() => _image = null),
                      icon: const Icon(Icons.close),
                      label: const Text('Clear selection'),
                    )
                  else if (widget.recipe?.imagePath != null)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _removeImage = !_removeImage),
                      icon: Icon(
                        _removeImage ? Icons.undo : Icons.delete_outline,
                      ),
                      label: Text(_removeImage ? 'Keep image' : 'Remove image'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _busy ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _busy ? null : _save,
        child: Text(_busy ? 'Saving…' : 'Save recipe'),
      ),
    ],
  );

  Future<void> _pickImage() async {
    try {
      final image = await TaskImagePicker.pick();
      if (mounted && image != null) {
        setState(() {
          _image = image;
          _removeImage = false;
        });
      }
    } catch (_) {
      if (mounted) _message('Could not prepare that image.');
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    Navigator.pop(
      context,
      RecipeEditorResult(
        RecipeDraft(
          name: _name.text.trim(),
          instructions: _instructions.text.trim(),
          ingredients: _ingredientsKey.currentState!.values,
        ),
        image: _image,
        removeImage: _removeImage,
      ),
    );
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _MealEditor extends StatefulWidget {
  const _MealEditor({this.meal, this.fromRecipe});

  final MealRecord? meal;
  final RecipeRecord? fromRecipe;

  @override
  State<_MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<_MealEditor> {
  final _formKey = GlobalKey<FormState>();
  final _ingredientsKey = GlobalKey<IngredientEditorState>();
  late final TextEditingController _name;
  late final TextEditingController _servings;
  late final TextEditingController _notes;
  late DateTime _plannedAt;
  String? _slot;
  bool _includeTime = false;
  bool _saveAsRecipe = false;
  PreparedTaskImage? _recipeImage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final meal = widget.meal;
    final recipe = widget.fromRecipe;
    _plannedAt =
        meal?.plannedAt.toLocal() ?? DateTime(now.year, now.month, now.day);
    _includeTime = meal?.hasTime ?? false;
    _slot = meal?.mealSlot;
    _name = TextEditingController(text: meal?.name ?? recipe?.name ?? '');
    _servings = TextEditingController(text: '${meal?.servings ?? 2}');
    _notes = TextEditingController(text: meal?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<IngredientDraft> get _initialIngredients {
    final meal = widget.meal;
    if (meal != null) {
      return meal.ingredients
          .map(
            (item) => IngredientDraft(
              label: item.label,
              quantity: item.quantity,
              unit: item.unit,
              have: item.have,
              sortOrder: item.sortOrder,
            ),
          )
          .toList();
    }
    return (widget.fromRecipe?.ingredients ?? const <IngredientRecord>[])
        .map(
          (item) => IngredientDraft(
            label: item.label,
            quantity: item.quantity,
            unit: item.unit,
            sortOrder: item.sortOrder,
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: Text(widget.meal == null ? 'Plan a meal' : 'Edit meal'),
    content: SizedBox(
      width: 460,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                autofocus: true,
                maxLength: 120,
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a meal name'
                    : null,
                decoration: const InputDecoration(labelText: 'Meal name'),
              ),
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(_shortDate(_plannedAt)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Set a time'),
                value: _includeTime,
                onChanged: (value) => setState(() {
                  if (value && _plannedAt.hour == 0 && _plannedAt.minute == 0) {
                    _plannedAt = DateTime(
                      _plannedAt.year,
                      _plannedAt.month,
                      _plannedAt.day,
                      18,
                    );
                  }
                  _includeTime = value;
                }),
              ),
              if (_includeTime)
                TextButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_outlined),
                  label: Text(
                    '${_plannedAt.hour.toString().padLeft(2, '0')}:${_plannedAt.minute.toString().padLeft(2, '0')}',
                  ),
                ),
              DropdownButtonFormField<String?>(
                initialValue: _slot,
                decoration: const InputDecoration(
                  labelText: 'Meal slot (optional)',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('No meal slot')),
                  DropdownMenuItem(
                    value: 'breakfast',
                    child: Text('Breakfast'),
                  ),
                  DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                  DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                  DropdownMenuItem(value: 'snack', child: Text('Snack')),
                ],
                onChanged: (value) => setState(() => _slot = value),
              ),
              TextFormField(
                controller: _servings,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final servings = int.tryParse(value ?? '');
                  return servings == null || servings < 1 || servings > 100
                      ? 'Enter servings from 1 to 100'
                      : null;
                },
                decoration: const InputDecoration(labelText: 'Servings'),
              ),
              TextField(
                controller: _notes,
                maxLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Text('Ingredients'),
                ),
              ),
              if (widget.fromRecipe == null)
                IngredientEditor(
                  key: _ingredientsKey,
                  initial: _initialIngredients,
                )
              else ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'The recipe ingredients will be copied into this meal. You can change them after saving.',
                  ),
                ),
                for (final ingredient in _initialIngredients)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.circle, size: 8),
                    title: Text(ingredient.label),
                    subtitle:
                        ingredient.quantity == null && ingredient.unit == null
                        ? null
                        : Text(
                            [ingredient.quantity, ingredient.unit]
                                .whereType<String>()
                                .where((value) => value.isNotEmpty)
                                .join(' '),
                          ),
                  ),
              ],
              if (widget.meal == null && widget.fromRecipe == null)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Also save as a reusable recipe'),
                  value: _saveAsRecipe,
                  onChanged: (value) =>
                      setState(() => _saveAsRecipe = value ?? false),
                ),
              if (widget.meal == null &&
                  widget.fromRecipe == null &&
                  _saveAsRecipe) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recipe image (optional)'),
                ),
                if (_recipeImage != null)
                  _imagePreview(context, bytes: _recipeImage!.bytes),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickRecipeImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(
                        _recipeImage == null
                            ? 'Choose recipe image'
                            : 'Replace image',
                      ),
                    ),
                    if (_recipeImage != null)
                      TextButton.icon(
                        onPressed: () => setState(() => _recipeImage = null),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove image'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save meal')),
    ],
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _plannedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) {
      setState(
        () => _plannedAt = DateTime(
          value.year,
          value.month,
          value.day,
          _plannedAt.hour,
          _plannedAt.minute,
        ),
      );
    }
  }

  Future<void> _pickRecipeImage() async {
    try {
      final image = await TaskImagePicker.pick();
      if (mounted && image != null) setState(() => _recipeImage = image);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not prepare that image.')),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_plannedAt),
    );
    if (value != null) {
      setState(
        () => _plannedAt = DateTime(
          _plannedAt.year,
          _plannedAt.month,
          _plannedAt.day,
          value.hour,
          value.minute,
        ),
      );
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      MealEditorResult(
        MealDraft(
          name: _name.text.trim(),
          plannedAt: _plannedAt,
          includeTime: _includeTime,
          mealSlot: _slot,
          recipeId: widget.meal?.recipeId ?? widget.fromRecipe?.id,
          servings: int.parse(_servings.text),
          notes: _notes.text.trim(),
          ingredients: widget.fromRecipe == null
              ? _ingredientsKey.currentState!.values
              : const [],
        ),
        saveAsRecipe: _saveAsRecipe,
        recipeImage: _recipeImage,
      ),
    );
  }
}

Widget _imagePreview(BuildContext context, {Uint8List? bytes, String? url}) =>
    ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 150,
        width: double.infinity,
        child: bytes != null
            ? Image.memory(bytes, fit: BoxFit.cover)
            : url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imagePlaceholder(context),
              )
            : _imagePlaceholder(context),
      ),
    );

Widget _imagePlaceholder(BuildContext context) => ColoredBox(
  color: Theme.of(context).colorScheme.secondaryContainer,
  child: Icon(
    Icons.menu_book_outlined,
    color: Theme.of(context).colorScheme.onSecondaryContainer,
    size: 40,
  ),
);

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
