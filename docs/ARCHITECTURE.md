# HomeHub — Architecture v0.0.1

## Stack
Flutter/Dart, Material 3, Supabase Auth/Postgres/RLS/Realtime/Storage/Edge Functions, FCM only for push delivery.

## Flutter structure
```text
lib/
  main.dart
  app/        # bootstrap, app, router
  core/       # config, theme, errors, utils, shared widgets
  features/
    auth/
    home/
    tasks/
    meals/
    shopping/
    calendar/
    expenses/
    search/
    notifications/
    settings/
```
Inside features use pragmatic `data/domain/presentation` separation only where useful.

## State & routing
Recommended baseline: **Riverpod** for async state/dependency injection and **go_router** for navigation/deep links/auth guards. If an existing coherent project uses alternatives, do not replace them without reason.

## Data access
UI must not call raw Supabase tables directly. Use feature repositories/services with typed models. Avoid one giant SupabaseService.

## Realtime
Supabase is authoritative. Subscribe only to needed household data. No offline mutation queue.

## Images
Select/capture → resize/compress on device → target ~500 KB → private Storage → save stable path/metadata → authorized display access. Never persist signed URLs.

## Push
`mutation → trusted notification decision → notification/activity record → Edge Function/server → FCM → Android → deep link`.
FCM credentials remain server-side.

## Themes
Semantic tokens: background, surfaces, primary/secondary, text, status colors, category colors, spacing, radii, typography. Dark and Flower map the same tokens differently. Botanical decoration must be separable from content layout.

## Errors
Controlled loading/error/retry states; no raw exception dumps or user-facing crashes.

## Secrets
Flutter may contain only intended client-safe public config. Never ship service-role keys, database passwords or FCM service credentials.

## Phase 0 implementation notes
- Supabase Flutter initialization is optional and reads the `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` Dart defines. Without both values the app starts without a Supabase client, keeping the foundation runnable before backend setup.
- Dark Mode is the initial theme. The Flower/Dark switch is managed in Riverpod; theme preference persistence belongs with Settings.
- The Android build disables Kotlin incremental compilation to avoid cross-drive incremental-cache failures on Windows when the app workspace and Pub cache are on different drives.

## Testing
Prioritize auth, RLS household isolation, task CRUD/assignment/archive/template, meal-specific ingredient state, shopping next-two-meals behavior, events, expenses, JSON export and deep-link parsing.

## Primary navigation
Initial target: Home, Tasks, Meals, Calendar, Shopping. Expenses should be prominent from Home and/or overflow/module entry. Do not force six cramped bottom-nav destinations without UX review.
