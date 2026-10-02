import 'package:flutter_test/flutter_test.dart';
import 'package:home_hub/features/calendar/domain/calendar_event.dart';

void main() {
  test('agenda separates today, upcoming, past, and archived events', () {
    final now = DateTime(2026, 10, 2, 12);
    final agenda = buildCalendarAgenda([
      _event('tomorrow', DateTime(2026, 10, 3, 9)),
      _event('today-later', DateTime(2026, 10, 2, 18)),
      _event(
        'ongoing-today',
        DateTime(2026, 10, 1, 23),
        end: DateTime(2026, 10, 2, 13),
      ),
      _event('past', DateTime(2026, 10, 1, 10), end: DateTime(2026, 10, 1, 11)),
      _event('archived-today', DateTime(2026, 10, 2, 14), archived: true),
    ], now: now);

    expect(agenda.today.map((event) => event.id), [
      'ongoing-today',
      'today-later',
    ]);
    expect(agenda.upcoming.map((event) => event.id), ['tomorrow']);
  });

  test('event mapping preserves recurrence, all-day and assignee fields', () {
    final event = CalendarEvent.fromJson({
      'id': 'event-1',
      'title': 'Family day',
      'description': 'Bring lunch',
      'starts_at': '2026-10-03T00:00:00.000Z',
      'ends_at': '2026-10-03T23:59:00.000Z',
      'all_day': true,
      'location': 'Park',
      'category': 'Family',
      'color': '#5478A4',
      'reminder_at': null,
      'recurrence': {'frequency': 'weekly'},
      'created_by': 'user-a',
      'updated_at': '2026-10-01T10:00:00.000Z',
      'archived_at': null,
      'event_assignees': [
        {'user_id': 'user-a'},
        {'user_id': 'user-b'},
      ],
    });

    expect(event.allDay, isTrue);
    expect(event.recurrence, {'frequency': 'weekly'});
    expect(event.assigneeIds, ['user-a', 'user-b']);
    expect(event.reminderAt, isNull);
  });
}

CalendarEvent _event(
  String id,
  DateTime start, {
  DateTime? end,
  bool archived = false,
}) => CalendarEvent(
  id: id,
  title: id,
  description: '',
  startsAt: start,
  endsAt: end ?? start.add(const Duration(hours: 1)),
  allDay: false,
  color: '#68794D',
  assigneeIds: const [],
  createdBy: 'user-a',
  updatedAt: start,
  archivedAt: archived ? start : null,
);
