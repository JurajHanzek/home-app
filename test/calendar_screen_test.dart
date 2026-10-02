import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_hub/core/theme/app_theme.dart';
import 'package:home_hub/features/calendar/data/calendar_repository.dart';
import 'package:home_hub/features/calendar/domain/calendar_event.dart';
import 'package:home_hub/features/calendar/presentation/calendar_editor.dart';
import 'package:home_hub/features/calendar/presentation/calendar_screen.dart';

void main() {
  testWidgets('missing Calendar schema shows the required setup action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarProvider.overrideWith((ref) async {
            throw const PostgrestException(
              message: 'Could not find the table in the schema cache',
              code: 'PGRST205',
            );
          }),
        ],
        child: MaterialApp(home: const Scaffold(body: CalendarScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('apply the Phase 5 migration'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'Month is default and supports navigation, day selection, dots and date prefill',
    (tester) async {
      tester.view.physicalSize = const Size(360, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final selected = DateTime(now.year, now.month, 20);
      final dayEvents = [
        _event('All day gathering', selected, allDay: true),
        _event('Morning visit', selected.add(const Duration(hours: 9))),
        _event('Evening dinner', selected.add(const Duration(hours: 18))),
        _event('Extra event', selected.add(const Duration(hours: 19))),
      ];
      final data = CalendarData(events: dayEvents, people: const []);
      final repository = _CalendarRepositoryFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarProvider.overrideWith((ref) async => data),
            calendarRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(home: const Scaffold(body: CalendarScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Agenda'), findsOneWidget);
      expect(
        find.textContaining('${_monthName(now.month)} ${now.year}'),
        findsOneWidget,
      );
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Mon')).dx,
        lessThan(tester.getTopLeft(find.text('Tue')).dx),
      );
      expect(
        tester.getTopLeft(find.text('Tue')).dx,
        lessThan(tester.getTopLeft(find.text('Sun')).dx),
      );
      expect(find.byKey(const Key('calendar-today-date')), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      final previous = DateTime(now.year, now.month - 1);
      expect(
        find.textContaining('${_monthName(previous.month)} ${previous.year}'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${_monthName(now.month)} ${now.year}'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey('calendar-day-${_dayKey(selected)}')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${_formatDate(selected)} · 4 events'),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('calendar-event-dot-${_dayKey(selected)}-All day gathering'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('calendar-event-dot-${_dayKey(selected)}-Morning visit'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('calendar-event-dot-${_dayKey(selected)}-Evening dinner'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          ValueKey('calendar-event-dot-${_dayKey(selected)}-Extra event'),
        ),
        findsNothing,
      );
      expect(find.text('All day gathering'), findsOneWidget);
      expect(find.textContaining('All day ·'), findsOneWidget);
      expect(find.text('Morning visit'), findsOneWidget);
      expect(find.text('Evening dinner'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('All day gathering')).dy,
        lessThan(tester.getTopLeft(find.text('Morning visit')).dy),
      );
      expect(find.textContaining('4 events'), findsOneWidget);

      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${_monthName(now.month)} ${now.year}'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '${_formatDate(DateTime(now.year, now.month, now.day))} ·',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(ValueKey('calendar-day-${_dayKey(selected)}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New event'));
      await tester.pumpAndSettle();
      final startDate = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('event-starts-date')),
          matching: find.byType(Text),
        ),
      );
      expect(startDate.data, _formatDate(selected));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Morning visit'));
      await tester.pumpAndSettle();
      expect(find.text('Morning visit'), findsNWidgets(2));
      expect(
        find.textContaining('${_formatDate(selected)} 09:00'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'agenda puts today and upcoming first and keeps history separate',
    (tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final data = CalendarData(
        people: const [
          CalendarPerson(id: 'user-a', name: 'Alex', initials: 'A'),
        ],
        events: [
          _event(
            'today-event',
            today.add(const Duration(hours: 10)),
            assigned: ['user-a'],
            location: 'Park',
          ),
          _event(
            'upcoming-event',
            today.add(const Duration(days: 1, hours: 11)),
          ),
          _event(
            'past-event',
            today.subtract(const Duration(days: 1, hours: 2)),
          ),
          _event(
            'archived-event',
            today.add(const Duration(days: 2)),
            archived: true,
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [calendarProvider.overrideWith((ref) async => data)],
          child: MaterialApp(
            theme: AppTheme.forMode(HomeHubTheme.dark),
            home: const Scaffold(body: CalendarScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(find.text('today-event'), findsOneWidget);
      expect(find.text('upcoming-event'), findsOneWidget);
      expect(find.text('past-event'), findsNothing);
      expect(find.text('archived-event'), findsNothing);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Park'), findsOneWidget);

      await tester.tap(find.byTooltip('Calendar views'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Past events (1)'));
      await tester.pumpAndSettle();
      expect(find.text('past-event'), findsOneWidget);
      expect(find.text('today-event'), findsNothing);

      await tester.tap(find.byTooltip('Calendar views'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archived events (1)'));
      await tester.pumpAndSettle();
      expect(find.text('archived-event'), findsOneWidget);
    },
  );

  testWidgets(
    'event editor defaults reminders off and limits assignments to two',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final people = const [
        CalendarPerson(id: 'a', name: 'Alex', initials: 'A'),
        CalendarPerson(id: 'b', name: 'Bela', initials: 'B'),
        CalendarPerson(id: 'c', name: 'Chris', initials: 'C'),
      ];
      CalendarEventDraft? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showCalendarEventEditor(
                  context,
                  people: people,
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.text('Off by default'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex'));
      await tester.tap(find.text('Bela'));
      await tester.tap(find.text('Chris'));
      await tester.pumpAndSettle();
      expect(
        find.text('An event can have up to two assignees.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField).first, 'Family lunch');
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();
      expect(result?.allDay, isTrue);
      expect(result?.startsAt.hour, 0);
      expect(result?.endsAt.hour, 23);
      expect(result?.assigneeIds, ['a', 'b']);
      expect(result?.reminderAt, isNull);
    },
  );

  testWidgets(
    'Calendar quick create saves a shared event through its repository',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = _CalendarRepositoryFake();
      const data = CalendarData(events: [], people: []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calendarProvider.overrideWith((ref) async => data),
            calendarRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.forMode(HomeHubTheme.flower),
            home: const Scaffold(body: CalendarScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New event'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Dentist');
      await tester.tap(find.text('Save event'));
      await tester.pumpAndSettle();

      expect(repository.createdDraft?.title, 'Dentist');
      expect(repository.createdDraft?.reminderAt, isNull);
      expect(repository.createdDraft?.assigneeIds, isEmpty);
    },
  );
}

class _CalendarRepositoryFake extends Fake implements CalendarRepository {
  CalendarEventDraft? createdDraft;

  @override
  Future<String> create(CalendarEventDraft draft) async {
    createdDraft = draft;
    return 'event-created';
  }
}

CalendarEvent _event(
  String title,
  DateTime startsAt, {
  List<String> assigned = const [],
  String? location,
  bool archived = false,
  bool allDay = false,
}) => CalendarEvent(
  id: title,
  title: title,
  description: '',
  startsAt: startsAt,
  endsAt: startsAt.add(const Duration(hours: 1)),
  allDay: allDay,
  location: location,
  color: '#447C82',
  assigneeIds: assigned,
  createdBy: 'user-a',
  updatedAt: startsAt,
  archivedAt: archived ? startsAt : null,
);

String _dayKey(DateTime value) =>
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

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
