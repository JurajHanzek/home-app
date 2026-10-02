import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/font_size_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(fontSizeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings / Options')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: RadioGroup<AppFontSize>(
                groupValue: selected,
                onChanged: (value) {
                  if (value != null) {
                    ref
                        .read(fontSizeControllerProvider.notifier)
                        .setSize(value);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        'Application font size',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    for (final size in AppFontSize.values)
                      RadioListTile<AppFontSize>(
                        key: ValueKey('font-size-${size.name}'),
                        title: Text(size.label),
                        value: size,
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Text(
                        'This setting applies throughout HomeHub and is saved on this device.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
