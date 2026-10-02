import 'package:flutter/material.dart';

import '../domain/calendar_event.dart';

Future<CalendarEventDraft?> showCalendarEventEditor(
  BuildContext context, {
  required List<CalendarPerson> people,
  CalendarEvent? event,
  DateTime? initialDate,
}) => showDialog<CalendarEventDraft>(
  context: context,
  builder: (_) => _CalendarEventEditor(
    people: people,
    event: event,
    initialDate: initialDate,
  ),
);

class _CalendarEventEditor extends StatefulWidget {
  const _CalendarEventEditor({
    required this.people,
    this.event,
    this.initialDate,
  });

  final List<CalendarPerson> people;
  final CalendarEvent? event;
  final DateTime? initialDate;

  @override
  State<_CalendarEventEditor> createState() => _CalendarEventEditorState();
}

class _CalendarEventEditorState extends State<_CalendarEventEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late final TextEditingController _category;
  late DateTime _startsAt;
  late DateTime _endsAt;
  DateTime? _reminderAt;
  String _color = calendarEventColors.first;
  final Set<String> _assigneeIds = {};
  bool _allDay = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final now = DateTime.now().add(const Duration(hours: 1));
    final selectedDate = widget.initialDate;
    final startDate = selectedDate == null
        ? now
        : DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 9);
    _startsAt = event?.startsAt ?? startDate;
    _endsAt = event?.endsAt ?? startDate.add(const Duration(hours: 1));
    _allDay = event?.allDay ?? false;
    _reminderAt = event?.reminderAt;
    _color = event?.color ?? calendarEventColors.first;
    _assigneeIds.addAll(event?.assigneeIds ?? const []);
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    _category = TextEditingController(text: event?.category ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    title: Text(widget.event == null ? 'New event' : 'Edit event'),
    titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    actionsPadding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          spacing: 14,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Event title *'),
            ),
            TextField(
              controller: _description,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _allDay,
              onChanged: _toggleAllDay,
            ),
            _dateTimeRow(
              title: 'Starts',
              value: _startsAt,
              dateAction: _pickStartDate,
              timeAction: _allDay ? null : _pickStartTime,
            ),
            _dateTimeRow(
              title: 'Ends',
              value: _endsAt,
              dateAction: _pickEndDate,
              timeAction: _allDay ? null : _pickEndTime,
            ),
            TextField(
              controller: _location,
              maxLength: 160,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            TextField(
              controller: _category,
              maxLength: 80,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Category (optional)',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 8, bottom: 4),
                child: Text('Event color'),
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                for (final color in calendarEventColors)
                  Semantics(
                    button: true,
                    selected: _color == color,
                    label: 'Event color ${_colorName(color)}',
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _color = color),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor: Color(
                            int.parse(color.substring(1), radix: 16) +
                                0xFF000000,
                          ),
                          child: _color == color
                              ? const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 12, bottom: 4),
                child: Text('Who is involved? (up to two)'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 6,
                children: [
                  for (final person in widget.people)
                    FilterChip(
                      label: Text(person.name),
                      selected: _assigneeIds.contains(person.id),
                      onSelected: (selected) =>
                          _toggleAssignee(person, selected),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder'),
              subtitle: Text(
                _reminderAt == null
                    ? 'Off by default'
                    : 'Set for ${_formatDateTime(_reminderAt!)} · delivery is not active yet',
              ),
              value: _reminderAt != null,
              onChanged: _toggleReminder,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save event')),
    ],
  );

  Widget _dateTimeRow({
    required String title,
    required DateTime value,
    required VoidCallback dateAction,
    VoidCallback? timeAction,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(width: 56, child: Text(title)),
        Expanded(
          child: TextButton.icon(
            key: ValueKey('event-${title.toLowerCase()}-date'),
            onPressed: dateAction,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: Text(_formatDate(value)),
          ),
        ),
        if (timeAction != null)
          TextButton.icon(
            onPressed: timeAction,
            icon: const Icon(Icons.schedule_outlined, size: 18),
            label: Text(_formatTime(value)),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('All day'),
          ),
      ],
    ),
  );

  Future<void> _pickStartDate() async {
    final date = await _pickDate(_startsAt);
    if (date == null) return;
    setState(() {
      _startsAt = _withDate(_startsAt, date, allDay: _allDay);
      if (_allDay) {
        _endsAt = _allDayEnd(_endsAt, date);
      } else if (_endsAt.isBefore(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final date = await _pickDate(_endsAt, firstDate: _startsAt);
    if (date == null) return;
    setState(() {
      _endsAt = _withDate(_endsAt, date, allDay: _allDay);
      if (_allDay) _endsAt = _allDayEnd(_endsAt, date);
    });
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? firstDate}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: firstDate ?? DateTime(2000),
        lastDate: DateTime(2100),
      );

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(
        _startsAt.year,
        _startsAt.month,
        _startsAt.day,
        time.hour,
        time.minute,
      );
      if (_endsAt.isBefore(_startsAt)) {
        _endsAt = _startsAt.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endsAt),
    );
    if (time == null) return;
    setState(
      () => _endsAt = DateTime(
        _endsAt.year,
        _endsAt.month,
        _endsAt.day,
        time.hour,
        time.minute,
      ),
    );
  }

  void _toggleAllDay(bool value) => setState(() {
    _allDay = value;
    if (value) {
      _startsAt = DateTime(_startsAt.year, _startsAt.month, _startsAt.day);
      _endsAt = _allDayEnd(_endsAt, _endsAt);
    } else {
      _startsAt = DateTime(_startsAt.year, _startsAt.month, _startsAt.day, 9);
      _endsAt = _startsAt.add(const Duration(hours: 1));
    }
  });

  void _toggleAssignee(CalendarPerson person, bool selected) {
    setState(() {
      if (selected && _assigneeIds.length < 2) {
        _assigneeIds.add(person.id);
      } else if (!selected) {
        _assigneeIds.remove(person.id);
      }
    });
    if (selected &&
        _assigneeIds.length >= 2 &&
        !_assigneeIds.contains(person.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An event can have up to two assignees.')),
      );
    }
  }

  Future<void> _toggleReminder(bool enabled) async {
    if (!enabled) {
      setState(() => _reminderAt = null);
      return;
    }
    final initial =
        _reminderAt ?? _startsAt.subtract(const Duration(minutes: 15));
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time != null) {
      setState(
        () => _reminderAt = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter an event title.')));
      return;
    }
    if (_endsAt.isBefore(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End must be on or after the start.')),
      );
      return;
    }
    Navigator.pop(
      context,
      CalendarEventDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        startsAt: _startsAt,
        endsAt: _endsAt,
        allDay: _allDay,
        location: _location.text,
        category: _category.text,
        color: _color,
        reminderAt: _reminderAt,
        recurrence: widget.event?.recurrence,
        assigneeIds: _assigneeIds.toList(),
      ),
    );
  }
}

DateTime _withDate(DateTime oldValue, DateTime date, {required bool allDay}) =>
    DateTime(
      date.year,
      date.month,
      date.day,
      allDay ? 0 : oldValue.hour,
      allDay ? 0 : oldValue.minute,
    );

DateTime _allDayEnd(DateTime existing, DateTime fallback) {
  final date = existing.isBefore(fallback) ? fallback : existing;
  return DateTime(date.year, date.month, date.day, 23, 59);
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${_formatTime(value)}';

String _colorName(String value) => switch (value) {
  '#68794D' => 'olive',
  '#447C82' => 'teal',
  '#5478A4' => 'blue',
  '#9A6A3A' => 'amber',
  _ => 'plum',
};
