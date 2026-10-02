import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../search/search_repository.dart';

class ActivityRecord {
  const ActivityRecord({
    required this.id,
    required this.actorId,
    required this.actor,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.createdAt,
  });
  final String id, actorId, actor, action, entityType, entityId;
  final DateTime createdAt;
  String? get route => EntityType.values.any((type) => type.name == entityType)
      ? '/entity/$entityType/${Uri.encodeComponent(entityId)}'
      : entityType == 'shopping'
      ? '/shopping'
      : null;
  factory ActivityRecord.fromJson(Map<String, dynamic> json) => ActivityRecord(
    id: json['id'] as String,
    actorId: json['actor_user_id'] as String,
    actor:
        (json['profiles'] as Map?)?['display_name'] as String? ??
        'Household member',
    action: json['action'] as String,
    entityType: json['entity_type'] as String,
    entityId: json['entity_id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

final activityRepositoryProvider = Provider(
  (ref) => ActivityRepository(Supabase.instance.client),
);
final activityProvider = FutureProvider.autoDispose<List<ActivityRecord>>((
  ref,
) async {
  final repo = ref.watch(activityRepositoryProvider);
  final channel = repo.watchChanges(() => ref.invalidateSelf());
  ref.onDispose(channel.unsubscribe);
  return repo.load();
});

class ActivityRepository {
  const ActivityRepository(this.client);
  final SupabaseClient client;
  RealtimeChannel watchChanges(void Function() changed) => client
      .channel('homehub-activity')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'activity_log',
        callback: (_) => changed(),
      )
      .subscribe();
  Future<List<ActivityRecord>> load() async {
    final rows = await client
        .from('activity_log')
        .select('*, profiles!actor_user_id(display_name)')
        .order('created_at', ascending: false)
        .order('id', ascending: false)
        .limit(50)
        .timeout(const Duration(seconds: 20));
    return rows.map(ActivityRecord.fromJson).toList();
  }
}
