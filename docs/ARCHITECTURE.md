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

Phase 7 `dashboardProvider` composes the existing Tasks, Meals, Shopping, Calendar and Expenses providers concurrently. It shares their cached results and realtime channels rather than starting a second dashboard subscription set. The existing Meals/Shopping overlap remains bounded; no per-card subscriptions are added. A 25-second dashboard deadline, pull-to-refresh and app-resume refresh provide retry paths. A minute timer updates date/time-derived selections. Activity has one shared auto-disposed insert subscription and is loaded independently so an unapplied Phase 7 migration does not hide the rest of Home.

`SearchRepository` calls the paginated security-invoker `search_household_entities` RPC for Search and Archive. Queries are explicit submissions, with generation checks to discard stale responses and a 20-second deadline. The typed `EntityType`/`EntityResult` carries stable IDs and archive flags. `/entity/:type/:id` hosts each original feature's detail widget, adding ID-based selection to existing screens and retaining their editors, repository mutations and error handling. Results refresh on return. A missing/deleted record displays a controlled unavailable state. Five bottom destinations remain unchanged.

`ActivityRepository` reads the latest 50 server-authored records with profile display names, ordered by timestamp and ID descending. Home takes five; `/activity` hosts Activity / Inbox. Entity references route through the same detail host; General activity navigates to Shopping. The activity model and presentation are separate from Search/Home, so Phase 8 can compose notification records without replacing the activity store. No FCM or notification delivery is added.

## Authentication and household access
- The client supports email/password sign-in only. There is no signup flow; local Supabase Auth signup is disabled and hosted projects must also keep signup disabled.
- Router access requires a valid Supabase session and a profile linked to a household. Missing membership shows an administrator-directed account setup state.
- Trusted administrators create/invite the two Auth users, then call the non-exposed, owner-only household provisioning function. The Flutter client never provisions households or profiles.
- Row Level Security is mandatory for each exposed household table. The client has only narrow column/table grants; household isolation is enforced by Postgres policies.
- Phase 1 adds `AuthRepository` and typed `HouseholdMembership`; route guards wait for both session and profile membership before opening household destinations.

## Realtime
Supabase is authoritative. Subscribe only to needed household data. No offline mutation queue. Phase 2 subscribes to task/category/assignee/checklist/image/template changes; Phase 3 subscribes to recipe/recipe-ingredient/meal/meal-ingredient changes. Row visibility is enforced by table RLS.

Phase 4 Shopping uses a feature repository. Its Next 2 meals view derives grouped rows from the next two active meals and their existing `meal_ingredients`; marking one obtained writes `have` to that row by primary key. General list items are independent rows in `shopping_general`. Shopping subscribes to `shopping_general`, `meals`, and `meal_ingredients` so household changes refresh both sections under existing RLS. The repository/data shape leaves grouped notification decisions to the later Notifications phase; Phase 4 does not create notification records or send pushes.

Phase 5 Calendar uses a typed event repository and defaults to a compact, Monday-first Month grid with colored event dots and selected-day event cards. Month and Agenda are separate modes; Agenda keeps Today/Upcoming plus Past/Archived views. All household members can read each event; `event_assignees` marks involved users and is not an access-control filter. The repository subscribes to `events` and `event_assignees`. Event reminders are stored only when explicitly enabled; delivery waits for the Notifications phase. Recurrence metadata is preserved in storage without automatic instance generation.

## Images
Phase 6 Expenses uses typed expense/category/person models and a repository for ledger mutations, category management, archive/restore and realtime invalidation on `expenses` and `expense_categories`. Current-month summaries use integer cents and active expenses in the device-local calendar month. Both shared and personal rows count; payer totals use `paid_by`, independently of `created_by`. Expenses opens from Home as a standalone screen with back navigation, leaving the five bottom-navigation destinations unchanged.

Receipts reuse the Android document picker/compressor. Upload JPEGs to `{household_id}/expenses/{expense_id}/{uuid}.jpg` in the private `household-media` bucket. Store only the stable path in Postgres and request one-hour signed URLs when loading; refresh renews them. Missing/signing-failed receipts do not hide the ledger. Receipt creation follows the expense insert; a failed upload leaves the expense saved and reports that the receipt needs retrying. Replacement/removal deletes the old object on a best-effort basis after updating the expense. No debt or settlement logic is included.

Select from Android's system document picker → resize/compress on device to a maximum 1920 px edge and approximately 500 KB → private Storage → save stable path/metadata → request short-lived signed URLs for display. Never persist signed URLs. Task images use the household-media private bucket and household/task folder keys.

## Push
`mutation → trusted notification decision → notification/activity record → Edge Function/server → FCM → Android → deep link`.
FCM credentials remain server-side.

## Themes
Flower Mode uses centralized `FlowerTheme` colors/component styles and a `FlowerBackdrop` behind the application Navigator. Flower scaffolds are transparent over an opaque mint/ivory canvas; cards and dialogs remain opaque for readability. Original vector botanical artwork uses a repaint-isolated CustomPainter with a finite 1.8-second animation; reduced motion draws the final still frame immediately. Decoration is excluded from hit testing and semantics. Dark Mode does not instantiate the botanical layer.

Semantic tokens: background, surfaces, primary/secondary, text, status colors, category colors, spacing, radii, typography. Dark and Flower map the same tokens differently. Botanical decoration must be separable from content layout.
Task status colors are provided by a `ThemeExtension` for both modes. The selected `AppFontSize` design token drives global Flutter text scaling. The Android host stores the Small/Normal/Large preference in app-private SharedPreferences and restores it when the Flutter app starts.

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
v0.0.1 bottom navigation: Home, Tasks, Meals, Calendar, Shopping. Expenses remains accessible from Home and is not a sixth bottom-navigation item. Notifications and activity share one Activity/Inbox screen with All, Notifications, and Activity filters.
