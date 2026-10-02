import 'package:flutter/material.dart';

import '../domain/meal.dart';

class IngredientEditor extends StatefulWidget {
  const IngredientEditor({required this.initial, super.key});

  final List<IngredientDraft> initial;

  @override
  State<IngredientEditor> createState() => IngredientEditorState();
}

class IngredientEditorState extends State<IngredientEditor> {
  late List<_IngredientFields> _items;

  List<IngredientDraft> get values => [
    for (var i = 0; i < _items.length; i++)
      IngredientDraft(
        label: _items[i].label.text,
        quantity: _items[i].quantity.text,
        unit: _items[i].unit.text,
        have: _items[i].have,
        sortOrder: i,
      ),
  ];

  @override
  void initState() {
    super.initState();
    _items = widget.initial
        .map(
          (item) => _IngredientFields(
            item.label,
            item.quantity ?? '',
            item.unit ?? '',
            item.have,
          ),
        )
        .toList();
    if (_items.isEmpty) _items.add(_IngredientFields('', '', '', false));
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var index = 0; index < _items.length; index++)
        Padding(
          key: ValueKey('ingredient-editor-$index'),
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              TextField(
                controller: _items[index].label,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: 'Ingredient ${index + 1}',
                  counterText: '',
                  suffixIcon: _items.length == 1
                      ? null
                      : IconButton(
                          tooltip: 'Remove ingredient',
                          onPressed: () => setState(() {
                            _items.removeAt(index).dispose();
                          }),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _items[index].quantity,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Amount (optional)',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _items[index].unit,
                      maxLength: 40,
                      decoration: const InputDecoration(
                        labelText: 'Unit (optional)',
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      TextButton.icon(
        onPressed: () =>
            setState(() => _items.add(_IngredientFields('', '', '', false))),
        icon: const Icon(Icons.add),
        label: const Text('Add ingredient'),
      ),
    ],
  );
}

class _IngredientFields {
  _IngredientFields(String label, String quantity, String unit, this.have)
    : label = TextEditingController(text: label),
      quantity = TextEditingController(text: quantity),
      unit = TextEditingController(text: unit);

  final TextEditingController label;
  final TextEditingController quantity;
  final TextEditingController unit;
  final bool have;

  void dispose() {
    label.dispose();
    quantity.dispose();
    unit.dispose();
  }
}
