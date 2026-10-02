# HomeHub

Private Android household app for two users. Without backend credentials, the
app shows a safe setup screen. Accounts are provisioned by a household
administrator; the app does not offer public signup.

## Run

From this directory:

```powershell
flutter run
```

Pass the project URL and client-safe publishable key at build time:

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Never pass a service-role key or database credential to the Flutter app. Keep
local values out of source control. Supabase initialization is skipped when
either value is absent; the app remains runnable and displays setup instructions.

## Foundation and authentication

- Flutter + Material 3 with Dark and Flower themes.
- Riverpod for app state and go_router for navigation.
- Supabase Flutter client bootstrap from compile-time configuration.
- Email/password sign-in only; no public signup. See [Supabase setup](supabase/README.md) for trusted account/household provisioning.
- Supabase household/profile/device/settings migration with restrictive RLS and pgTAP tests.
- Primary destinations: Home, Tasks, Meals, Calendar, and Shopping; Expenses
  is reachable from Home.
- Run quality checks with `dart format .`, `flutter analyze`, and `flutter test`.
