import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/calendar_event.dart';

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(
    Supabase.instance.client,
    Supabase.instance.client.auth.currentUser!.id,
  ),
);

final calendarProvider = FutureProvider.autoDispose<CalendarData>((ref) async {
  final repository = ref.watch(calendarRepositoryProvider);
  final channel = repository.watchChanges(() => ref.invalidateSelf());
  ref.onDispose(channel.unsubscribe);
  // Surface unreachable PostgREST requests as a retryable error instead of
  // leaving the Calendar screen in its loading state indefinitely.
  return repository.load().timeout(const Duration(seconds: 20));
});

class CalendarRepository {
  const CalendarRepository(this._client, this.currentUserId);

  final SupabaseClient _client;
  final String currentUserId;

  RealtimeChannel watchChanges(void Function() changed) => _client
      .channel('homehub-calendar-$currentUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'events',
        callback: (_) => changed(),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'event_assignees',
        callback: (_) => changed(),
      )
      .subscribe();

  Future<CalendarData> load() async {
    final rows = await Future.wait([
      _client
          .from('events')
          .select('*, event_assignees(user_id)')
          .order('starts_at'),
      _client
          .from('profiles')
          .select('id,display_name,initials')
          .order('created_at'),
    ]);
    return CalendarData(
      events: (rows[0] as List)
          .map((row) => CalendarEvent.fromJson(row as Map<String, dynamic>))
          .toList(),
      people: (rows[1] as List).map((row) {
        final profile = row as Map<String, dynamic>;
        return CalendarPerson(
          id: profile['id'] as String,
          name: profile['display_name'] as String,
          initials: profile['initials'] as String,
        );
      }).toList(),
    );
  }

  Future<String> create(CalendarEventDraft draft) async {
    final row = await _client
        .from('events')
        .insert(_payload(draft))
        .select('id')
        .single();
    final id = row['id'] as String;
    await _writeAssignees(id, draft.assigneeIds);
    return id;
  }

  Future<void> update(CalendarEvent event, CalendarEventDraft draft) async {
    final payload = _payload(draft)..remove('created_by');
    await _client.from('events').update(payload).eq('id', event.id);
    await _client.from('event_assignees').delete().eq('event_id', event.id);
    await _writeAssignees(event.id, draft.assigneeIds);
  }

  Map<String, dynamic> _payload(CalendarEventDraft draft) => {
    'title': draft.title.trim(),
    'description': draft.description.trim(),
    'starts_at': draft.startsAt.toUtc().toIso8601String(),
    'ends_at': draft.endsAt.toUtc().toIso8601String(),
    'all_day': draft.allDay,
    'location': _emptyToNull(draft.location),
    'category': _emptyToNull(draft.category),
    'color': draft.color,
    'reminder_at': draft.reminderAt?.toUtc().toIso8601String(),
    'recurrence': draft.recurrence,
    'created_by': currentUserId,
    'updated_by': currentUserId,
  };

  Future<void> _writeAssignees(String eventId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    await _client.from('event_assignees').insert([
      for (final userId in userIds) {'event_id': eventId, 'user_id': userId},
    ]);
  }

  Future<void> setArchived(CalendarEvent event, bool archived) async {
    await _client
        .from('events')
        .update({
          'archived_at': archived
              ? DateTime.now().toUtc().toIso8601String()
              : null,
          'updated_by': currentUserId,
        })
        .eq('id', event.id);
  }
}

String? _emptyToNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
