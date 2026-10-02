const calendarEventColors = <String>[
  '#68794D',
  '#447C82',
  '#5478A4',
  '#9A6A3A',
  '#875F83',
];

class CalendarPerson {
  const CalendarPerson({
    required this.id,
    required this.name,
    required this.initials,
  });

  final String id;
  final String name;
  final String initials;
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.color,
    required this.assigneeIds,
    required this.createdBy,
    required this.updatedAt,
    this.location,
    this.category,
    this.reminderAt,
    this.recurrence,
    this.archivedAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String? location;
  final String? category;
  final String color;
  final DateTime? reminderAt;
  final Map<String, dynamic>? recurrence;
  final List<String> assigneeIds;
  final String createdBy;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    final assignees = (json['event_assignees'] as List<dynamic>? ?? const [])
        .map((row) => (row as Map<String, dynamic>)['user_id'] as String)
        .toList();
    final recurrenceValue = json['recurrence'];
    return CalendarEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(json['ends_at'] as String).toLocal(),
      allDay: json['all_day'] as bool? ?? false,
      location: json['location'] as String?,
      category: json['category'] as String?,
      color: json['color'] as String? ?? '#68794D',
      reminderAt: json['reminder_at'] == null
          ? null
          : DateTime.parse(json['reminder_at'] as String).toLocal(),
      recurrence: recurrenceValue == null
          ? null
          : Map<String, dynamic>.from(recurrenceValue as Map),
      assigneeIds: assignees,
      createdBy: json['created_by'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      archivedAt: json['archived_at'] == null
          ? null
          : DateTime.parse(json['archived_at'] as String).toLocal(),
    );
  }
}

class CalendarEventDraft {
  const CalendarEventDraft({
    required this.title,
    required this.description,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.color,
    required this.assigneeIds,
    this.location,
    this.category,
    this.reminderAt,
    this.recurrence,
  });

  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String? location;
  final String? category;
  final String color;
  final DateTime? reminderAt;
  final Map<String, dynamic>? recurrence;
  final List<String> assigneeIds;
}

class CalendarData {
  const CalendarData({required this.events, required this.people});

  final List<CalendarEvent> events;
  final List<CalendarPerson> people;
}

class CalendarAgenda {
  const CalendarAgenda({required this.today, required this.upcoming});

  final List<CalendarEvent> today;
  final List<CalendarEvent> upcoming;
}

CalendarAgenda buildCalendarAgenda(
  Iterable<CalendarEvent> events, {
  required DateTime now,
}) {
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrow = todayStart.add(const Duration(days: 1));
  final active = events.where((event) => !event.isArchived).toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return CalendarAgenda(
    today: active
        .where(
          (event) =>
              event.startsAt.isBefore(tomorrow) &&
              !event.endsAt.isBefore(todayStart),
        )
        .toList(),
    upcoming: active
        .where((event) => !event.startsAt.isBefore(tomorrow))
        .toList(),
  );
}

List<CalendarEvent> calendarEventsForDay(
  Iterable<CalendarEvent> events,
  DateTime date,
) {
  final dayStart = DateTime(date.year, date.month, date.day);
  final nextDay = dayStart.add(const Duration(days: 1));
  return events
      .where(
        (event) =>
            !event.isArchived &&
            event.startsAt.isBefore(nextDay) &&
            !event.endsAt.isBefore(dayStart),
      )
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
}
