import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/calendar_repository.dart';
import '../domain/calendar_event.dart';
import 'calendar_editor.dart';

enum _CalendarView { agenda, past, archived }

enum _CalendarMode { month, agenda }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.detailId});
  final String? detailId;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  _CalendarMode _mode = _CalendarMode.month;
  _CalendarView _view = _CalendarView.agenda;
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _displayedMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calendarProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _CalendarError(error: error, onRetry: _reload),
      data: _content,
    );
  }

  Widget _content(CalendarData data) {
    if (widget.detailId != null) {
      final event = data.events
          .where((item) => item.id == widget.detailId)
          .firstOrNull;
      if (event == null) {
        return const Center(child: Text('Event no longer available'));
      }
      return _EventDetails(
        event: event,
        people: data.people,
        onEdit: () => _edit(data, event: event),
        onArchive: () => _archive(event, !event.isArchived),
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final active = data.events.where((event) => !event.isArchived).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final archived = data.events.where((event) => event.isArchived).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final agenda = buildCalendarAgenda(data.events, now: now);
    final todayEvents = agenda.today;
    final upcoming = agenda.upcoming;
    final past = active.where((event) => event.endsAt.isBefore(today)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

    final visible = switch (_view) {
      _CalendarView.agenda => [...todayEvents, ...upcoming],
      _CalendarView.past => past,
      _CalendarView.archived => archived,
    };

    return Stack(
      children: [
        Column(
          children: [
            _modeSelector(past.length, archived.length),
            Expanded(
              child: _mode == _CalendarMode.month
                  ? _monthContent(data, active)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: _view == _CalendarView.agenda
                          ? _agendaList(todayEvents, upcoming, data.people)
                          : _eventList(visible, data.people),
                    ),
            ),
          ],
        ),
        if (_view != _CalendarView.archived)
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: () => _edit(
                data,
                initialDate: _mode == _CalendarMode.month
                    ? _selectedDate
                    : null,
              ),
              icon: const Icon(Icons.add),
              label: const Text('New event'),
            ),
          ),
      ],
    );
  }

  Widget _modeSelector(int pastCount, int archivedCount) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
    child: Row(
      children: [
        Expanded(
          child: SegmentedButton<_CalendarMode>(
            segments: const [
              ButtonSegment(value: _CalendarMode.month, label: Text('Month')),
              ButtonSegment(value: _CalendarMode.agenda, label: Text('Agenda')),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (selected) => setState(() {
              _mode = selected.first;
              _view = _CalendarView.agenda;
            }),
          ),
        ),
        if (_mode == _CalendarMode.agenda)
          PopupMenuButton<_CalendarView>(
            tooltip: 'Calendar views',
            onSelected: (value) => setState(() => _view = value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _CalendarView.agenda,
                child: Text('Today and upcoming'),
              ),
              PopupMenuItem(
                value: _CalendarView.past,
                child: Text('Past events ($pastCount)'),
              ),
              PopupMenuItem(
                value: _CalendarView.archived,
                child: Text('Archived events ($archivedCount)'),
              ),
            ],
          ),
      ],
    ),
  );

  Widget _monthContent(CalendarData data, List<CalendarEvent> active) {
    final monthName = _monthName(_displayedMonth.month);
    final firstOfMonth = DateTime(_displayedMonth.year, _displayedMonth.month);
    final dayCount = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    ).day;
    final cellCount = ((firstOfMonth.weekday - 1 + dayCount + 6) ~/ 7) * 7;
    final cells = <Widget>[];
    for (var i = 0; i < cellCount; i++) {
      final day = i - (firstOfMonth.weekday - 1) + 1;
      if (day < 1 || day > dayCount) {
        cells.add(const SizedBox(height: 44));
      } else {
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
        final events = calendarEventsForDay(active, date);
        cells.add(_dayCell(date, events));
      }
    }
    final rows = <TableRow>[];
    for (var i = 0; i < cells.length; i += 7) {
      rows.add(TableRow(children: cells.sublist(i, i + 7)));
    }
    final selectedEvents = calendarEventsForDay(active, _selectedDate);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  '$monthName ${_displayedMonth.year}',
                  key: const Key('calendar-month-title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: _goToToday, child: const Text('Today')),
              IconButton(
                tooltip: 'Next month',
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              for (final weekday in const [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Table(
            children: rows,
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_formatDate(_selectedDate)} · ${selectedEvents.length} ${selectedEvents.length == 1 ? 'event' : 'events'}',
                  key: const Key('calendar-selected-day-title'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _reload,
            child: selectedEvents.isEmpty
                ? ListView(
                    key: const Key('calendar-selected-day-list'),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    children: const [_InlineEmpty('No events on this day')],
                  )
                : ListView.separated(
                    key: const Key('calendar-selected-day-list'),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
                    itemCount: selectedEvents.length,
                    itemBuilder: (context, index) => _EventCard(
                      event: selectedEvents[index],
                      people: data.people,
                      onTap: () => _details(selectedEvents[index], data.people),
                      onEdit: () => _edit(data, event: selectedEvents[index]),
                      onArchive: () => _archive(selectedEvents[index], true),
                      onRestore: () => _archive(selectedEvents[index], false),
                    ),
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _dayCell(DateTime date, List<CalendarEvent> events) {
    final today = DateUtils.isSameDay(date, DateTime.now());
    final selected = DateUtils.isSameDay(date, _selectedDate);
    final shownEvents = events.take(3);
    final markerColor = events.isEmpty
        ? null
        : _eventColor(events.first.color, context);
    return TableCell(
      child: Semantics(
        button: true,
        selected: selected,
        label:
            '${today ? 'Today, ' : ''}${_formatDate(date)}, ${events.length} events',
        child: InkWell(
          key: ValueKey('calendar-day-${_dateKey(date)}'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedDate = date),
          child: SizedBox(
            height: 44,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  key: today ? const Key('calendar-today-date') : null,
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: today
                        ? Theme.of(context).colorScheme.primary
                        : selected
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : markerColor?.withValues(alpha: 0.2) ??
                              Colors.transparent,
                    shape: BoxShape.circle,
                    border: markerColor != null && !today && !selected
                        ? Border.all(color: markerColor, width: 1.5)
                        : today && !selected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  child: Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: selected || today || events.isNotEmpty
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: today
                          ? Theme.of(context).colorScheme.onPrimary
                          : null,
                    ),
                  ),
                ),
                SizedBox(
                  height: 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final event in shownEvents)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Container(
                            key: ValueKey(
                              'calendar-event-dot-${_dateKey(date)}-${event.id}',
                            ),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: _eventColor(event.color, context),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      if (events.length > 3)
                        Text(
                          '+${events.length - 3}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _moveMonth(int amount) {
    final target = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + amount,
    );
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    setState(() {
      _displayedMonth = target;
      _selectedDate = DateTime(
        target.year,
        target.month,
        _selectedDate.day.clamp(1, lastDay),
      );
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _selectedDate = DateTime(now.year, now.month, now.day);
      _displayedMonth = DateTime(now.year, now.month);
    });
  }

  Widget _agendaList(
    List<CalendarEvent> today,
    List<CalendarEvent> upcoming,
    List<CalendarPerson> people,
  ) => ListView(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
    children: [
      _SectionHeader(title: 'Today', detail: _formatDate(DateTime.now())),
      if (today.isEmpty)
        const _InlineEmpty('Nothing scheduled for today')
      else
        for (final event in today)
          _EventCard(
            event: event,
            people: people,
            onTap: () => _details(event, people),
            onEdit: () => _edit(
              CalendarData(events: [], people: people),
              event: event,
            ),
            onArchive: () => _archive(event, true),
            onRestore: () => _archive(event, false),
          ),
      const SizedBox(height: 12),
      const _SectionHeader(title: 'Upcoming'),
      if (upcoming.isEmpty)
        const _InlineEmpty('Nothing else coming up')
      else
        for (final event in upcoming)
          _EventCard(
            event: event,
            people: people,
            onTap: () => _details(event, people),
            onEdit: () => _edit(
              CalendarData(events: [], people: people),
              event: event,
            ),
            onArchive: () => _archive(event, true),
            onRestore: () => _archive(event, false),
          ),
    ],
  );

  Widget _eventList(List<CalendarEvent> events, List<CalendarPerson> people) =>
      events.isEmpty
      ? ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
          children: [_CalendarEmpty(archived: _view == _CalendarView.archived)],
        )
      : ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
          itemCount: events.length,
          itemBuilder: (context, index) => _EventCard(
            event: events[index],
            people: people,
            onTap: () => _details(events[index], people),
            onEdit: () => _edit(
              CalendarData(events: [], people: people),
              event: events[index],
            ),
            onArchive: () => _archive(events[index], true),
            onRestore: () => _archive(events[index], false),
          ),
          separatorBuilder: (_, _) => const SizedBox(height: 8),
        );

  Future<void> _edit(
    CalendarData data, {
    CalendarEvent? event,
    DateTime? initialDate,
  }) async {
    final draft = await showCalendarEventEditor(
      context,
      people: data.people,
      event: event,
      initialDate: initialDate,
    );
    if (draft == null) return;
    var parentSaved = false;
    try {
      final repository = ref.read(calendarRepositoryProvider);
      if (event == null) {
        await repository.create(draft);
      } else {
        await repository.update(event, draft);
      }
      parentSaved = true;
      await _reload();
    } catch (_) {
      await _reload();
      if (mounted) {
        _message(
          parentSaved
              ? 'Event saved, but its assignees could not be updated.'
              : 'Could not complete saving this event. Refresh to check its status.',
        );
      }
    }
  }

  Future<void> _details(
    CalendarEvent event,
    List<CalendarPerson> people,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _EventDetails(
        event: event,
        people: people,
        onEdit: () {
          Navigator.pop(dialogContext);
          _edit(
            CalendarData(events: [], people: people),
            event: event,
          );
        },
        onArchive: () {
          Navigator.pop(dialogContext);
          _archive(event, !event.isArchived);
        },
      ),
    );
  }

  Future<void> _archive(CalendarEvent event, bool archived) async {
    try {
      await ref.read(calendarRepositoryProvider).setArchived(event, archived);
      await _reload();
    } catch (_) {
      if (mounted) {
        _message(
          archived
              ? 'Could not archive this event.'
              : 'Could not restore this event.',
        );
      }
    }
  }

  Future<void> _reload() async {
    try {
      await ref.refresh(calendarProvider.future).then<void>((_) {});
    } catch (_) {
      // The provider exposes failures in the retry state.
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        if (detail != null)
          Text(detail!, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.people,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
  });

  final CalendarEvent event;
  final List<CalendarPerson> people;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final assignees = people
        .where((person) => event.assigneeIds.contains(person.id))
        .map((person) => person.name)
        .join(', ');
    final when = event.allDay
        ? 'All day · ${_formatDate(event.startsAt)}'
        : '${_formatDate(event.startsAt)} · ${_formatTime(event.startsAt)}–${_formatTime(event.endsAt)}';
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 7, color: _eventColor(event.color, context)),
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(when, style: Theme.of(context).textTheme.bodySmall),
                      if (event.location != null && event.location!.isNotEmpty)
                        _EventMeta(
                          icon: Icons.place_outlined,
                          text: event.location!,
                        ),
                      _EventMeta(
                        icon: Icons.people_outline,
                        text: assignees.isEmpty ? 'Household' : assignees,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Event options',
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'archive') onArchive();
                if (value == 'restore') onRestore();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(
                  value: event.isArchived ? 'restore' : 'archive',
                  child: Text(event.isArchived ? 'Restore' : 'Archive'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventMeta extends StatelessWidget {
  const _EventMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}

class _EventDetails extends StatelessWidget {
  const _EventDetails({
    required this.event,
    required this.people,
    required this.onEdit,
    required this.onArchive,
  });

  final CalendarEvent event;
  final List<CalendarPerson> people;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final names = people
        .where((person) => event.assigneeIds.contains(person.id))
        .map((person) => person.name)
        .join(', ');
    return AlertDialog(
      title: Text(event.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _detailRow(
              Icons.event_outlined,
              event.allDay
                  ? 'All day · ${_formatDate(event.startsAt)}${_dateRange(event)}'
                  : '${_formatDateTime(event.startsAt)} – ${_formatDateTime(event.endsAt)}',
            ),
            _detailRow(
              Icons.people_outline,
              names.isEmpty ? 'Household' : names,
            ),
            if (event.location != null && event.location!.isNotEmpty)
              _detailRow(Icons.place_outlined, event.location!),
            if (event.category != null && event.category!.isNotEmpty)
              _detailRow(Icons.label_outline, event.category!),
            if (event.reminderAt != null)
              _detailRow(
                Icons.notifications_none,
                'Reminder: ${_formatDateTime(event.reminderAt!)} · delivery is not active yet',
              ),
            if (event.description.isNotEmpty) ...[
              const Divider(height: 24),
              Text(event.description),
            ],
            if (event.isArchived) const Text('Archived'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onArchive,
          child: Text(event.isArchived ? 'Restore' : 'Archive'),
        ),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit'),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );

  String _dateRange(CalendarEvent event) =>
      DateUtils.dateOnly(event.startsAt) == DateUtils.dateOnly(event.endsAt)
      ? ''
      : ' – ${_formatDate(event.endsAt)}';
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
    child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
  );
}

class _CalendarEmpty extends StatelessWidget {
  const _CalendarEmpty({required this.archived});
  final bool archived;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          archived ? Icons.archive_outlined : Icons.event_available_outlined,
          size: 44,
        ),
        const SizedBox(height: 12),
        Text(
          archived ? 'No archived events' : 'No past events',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

class _CalendarError extends StatelessWidget {
  const _CalendarError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  String get message {
    if (error is TimeoutException) {
      return 'Calendar is taking too long to respond. Check your connection and retry.';
    }
    if (error is PostgrestException) {
      final exception = error as PostgrestException;
      if (exception.code == 'PGRST205' ||
          exception.code == '42P01' ||
          exception.code == 'PGRST200') {
        return 'Calendar database setup is missing or its schema cache is stale. Ask the project owner to apply the Phase 5 migration and refresh the Supabase API schema.';
      }
    }
    return 'Calendar could not be loaded. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

Color _eventColor(String value, BuildContext context) {
  try {
    final color = Color(
      int.parse(value.replaceFirst('#', ''), radix: 16) + 0xFF000000,
    );
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.6, 1.0))
        .withLightness(
          Theme.of(context).brightness == Brightness.dark ? 0.68 : 0.34,
        )
        .toColor();
  } catch (_) {
    return const Color(0xFF68794D);
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

String _monthName(int month) => const [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
][month - 1];

String _formatTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _formatDateTime(DateTime value) =>
    '${_formatDate(value)} ${_formatTime(value)}';
