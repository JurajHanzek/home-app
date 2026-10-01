# HomeHub

Private Android household app for two users. The app runs without backend
credentials so the navigation and theme foundation can be previewed locally.

## Run

From this directory:

```powershell
flutter run
```

To initialize Supabase, pass the project URL and client-safe publishable key at
build time:

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Never pass a service-role key or database credential to the Flutter app. Keep
local values out of source control. Supabase initialization is skipped when
either value is absent.

## Phase 0 foundation

- Flutter + Material 3 with Dark and Flower themes.
- Riverpod for app state and go_router for navigation.
- Supabase Flutter client bootstrap from compile-time configuration.
- Primary destinations: Home, Tasks, Meals, Calendar, and Shopping; Expenses
  is reachable from Home.
- Run quality checks with `dart format .`, `flutter analyze`, and `flutter test`.
