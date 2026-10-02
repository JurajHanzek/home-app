import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'activity_repository.dart';

class ActivityList extends ConsumerWidget {
  const ActivityList({this.compact = false, super.key});
  final bool compact;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(activityProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Activity unavailable. Check your connection and Phase 7 setup.',
            ),
            TextButton(
              onPressed: () => ref.invalidate(activityProvider),
              child: const Text('Retry activity'),
            ),
          ],
        ),
        data: (items) => items.isEmpty
            ? const Text('Your next household actions will appear here.')
            : Column(
                children: [
                  for (final item in items.take(compact ? 5 : 50))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${item.actor} · ${item.action.replaceAll('_', ' ')} ${item.entityType}',
                      ),
                      subtitle: Text(
                        '${MaterialLocalizations.of(context).formatShortDate(item.createdAt)} · ${TimeOfDay.fromDateTime(item.createdAt).format(context)}',
                      ),
                      trailing: item.route == null
                          ? null
                          : const Icon(Icons.chevron_right),
                      onTap: item.route == null
                          ? null
                          : () {
                              if (item.route == '/shopping') {
                                context.go('/shopping');
                              } else {
                                context.push(item.route!);
                              }
                            },
                    ),
                ],
              ),
      );
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Activity / Inbox')),
    body: const SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: ActivityList(),
      ),
    ),
  );
}
