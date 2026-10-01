import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.state,
    required this.dataBuilder,
    this.onRetry,
    super.key,
  });

  final AsyncValue<T> state;
  final Widget Function(T value) dataBuilder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return state.when(
      data: dataBuilder,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 36),
              const SizedBox(height: 12),
              const Text('We couldn’t load this yet.'),
              if (onRetry case final retry?) ...[
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
