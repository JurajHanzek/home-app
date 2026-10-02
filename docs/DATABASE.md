# HomeHub — Supabase Database & Security v0.0.1

Use UUID PKs, `household_id` on household-owned top-level records, timestamps, archive timestamps and RLS on every user-accessible table.

## Tables
- `households`: id, name, created_at
- `profiles`: id/auth user id, household_id, display_name, initials, avatar_path, accent_color, timestamps
- `user_devices`: id, user_id, fcm_token unique, platform, updated_at, disabled_at
- `task_categories`: id, household_id, name, color, icon, archived_at, timestamps; seed Outdoor/Indoor; household users may add/archive categories
- `tasks`: id, household_id, title, description, status, priority, category_id, due_at, reminder_at, created_by, updated_by, lifecycle timestamps, source_template_id
- `task_assignees`: task_id, user_id
- `task_checklist_items`: id, task_id, label, is_done, sort_order
- `task_images`: id, task_id, storage_path, size_bytes, dimensions optional, created_by, created_at, removed_at
- `task_templates`: id, household_id, title, description, category_id, priority, enabled, due/reminder offsets, created_by/updated_by, timestamps, archived_at
- `task_template_assignees`: template_id, user_id
- `task_template_checklist_items`: id, template_id, label, sort_order
- `recipes`: id, household_id, name, image_path, instructions, audit/lifecycle fields
- `recipe_ingredients`: id, recipe_id, label, quantity, unit, sort_order
- `meals`: id, household_id, planned_date, optional planned_time and meal_slot, name snapshot, recipe_id nullable, servings, notes, audit/lifecycle fields
- `meal_ingredients`: id, meal_id, label, quantity, unit, have, sort_order
- `shopping_general`: id, household_id, label, is_done, note, audit/lifecycle fields
- `events`: id, household_id, title, description, start/end, all_day, location, category/color, reminder_at, recurrence jsonb nullable, audit/lifecycle fields
- `event_assignees`: event_id, user_id
- `expense_categories`: id, household_id, name, color, archived_at, timestamps; seed Groceries, Home, Bills, Transport, Health, Leisure, Other; household users may add/archive categories
- `expenses`: id, household_id, amount numeric(12,2), currency default EUR, title, category_id, paid_by, shared, expense_date, note, receipt_path, audit/lifecycle fields
- `notifications`: id, household_id, recipient_user_id, type, entity_type/id, title, body, data jsonb, read_at, created_at
- `activity_log`: id, household_id, actor_user_id, action, entity_type/id, metadata jsonb, created_at
- `household_settings`: household_id, default_theme, notification_preferences jsonb, storage_warning_settings jsonb, updated_at

Task and event `reminder_at` values are nullable and remain unset unless a user explicitly enables a reminder. Missing-meal-ingredient reminders are configurable and default to disabled until notification UX is implemented. Done tasks remain in Done until manually archived; no automatic archive job is permitted in v0.0.1.

Storage monitoring tracks image count and bytes; it never enforces a hard application limit. Default warning settings account for 100 task images and configured storage-budget usage, and remain user-configurable. Cleanup is manual in v0.0.1. The combined Activity/Inbox screen presents notifications and activity with All, Notifications, and Activity filters.

Phase 3 adds `recipes`, `recipe_ingredients`, `meals`, and `meal_ingredients` in an additive migration. All four tables enable and force RLS; ingredient policies authorize through their parent row and composite foreign keys keep children in the parent's household. Recipe images use the existing private `household-media` bucket under `{household_id}/recipes/{recipe_id}/{file}`.

Create planned meals through the caller-authorized `create_planned_meal` function. It writes the meal and its ingredient snapshot in one transaction. From a recipe it copies current recipe ingredients to independent `meal_ingredients` rows with `have=false`; custom meals use caller-provided ingredient strings and do not require a recipe. Recipe edits never cascade into existing meals. Ingredient strings are not normalized or merged. Recipe and meal child rows use explicit ordering.

The Phase 4 meal-derived shopping query is straightforward: select the next two active meals ordered by `planned_date`, optional `planned_time`, then return each meal's `meal_ingredients` with `have=false`, grouped by meal and preserving `label` exactly. Do not aggregate or normalize ingredient names.

Meal-derived shopping is initially a query of the next two meals' `meal_ingredients where have=false`; do not duplicate it into another shopping table unless later UX requires independent state.

Phase 4 adds only `shopping_general` for the independent household list. Rows contain `id`, `household_id`, exact `label`, optional `note`, `is_done`, `created_by`, `updated_by`, timestamps, and nullable `archived_at`. There is no client hard-delete grant; archive/restore is the normal removal path. Index active rows by household/check state/time and archived rows by household/archive time. Enable and force RLS; authenticated select/insert/update grants are explicit, and mutable columns exclude ID, household, creator, and created time. Insert/update policies require `private.current_household_id()` and the current actor. Meal-derived shopping still reads and updates `meal_ingredients` under the existing parent-meal RLS. Add `shopping_general` to the Realtime publication; subscribe to the existing `meals` and `meal_ingredients` publication entries as well.

The Phase 4 migration is `20261002140000_phase4_shopping.sql`; its pgTAP suite covers household isolation, parent meal/ingredient authorization, targeted per-row availability, and preservation of forced RLS on existing Phase 1–3 tables. It does not change those earlier schemas.

Phase 5 adds `events` and `event_assignees` in additive migration `20261002160000_phase5_calendar.sql`. Events have title/description, required `starts_at` and `ends_at`, `all_day`, optional location/category, a hex color, nullable opt-in `reminder_at`, nullable object-valued `recurrence` metadata, audit timestamps, and `archived_at`. A check requires `ends_at >= starts_at`. Recurrence is storage-only; no automatic event instances or reminder delivery are created.

Both Calendar tables enable and force RLS. Event policies scope reads/writes to `private.current_household_id()` and require the authenticated actor for created/updated fields. Assignee rows include a household key with composite foreign keys to the parent event and profile; child policies authorize through the event and household. Authenticated clients can select/insert/delete assignments but cannot update their event/user/household keys. A transaction-locked trigger enforces no more than two assignees. Index active events by household/start and assignments by household/user. Add both tables to Realtime. The 31-assertion `calendar_security.test.sql` covers household isolation, assignment bounds, archive/restore, reminders defaulting to null, recurrence metadata, and forced RLS on earlier tables.

## Storage
Phase 6 continues the existing additive migration `20261002180000_phase6_expenses.sql`. It adds `expense_categories` and `expenses`, active/date/category/archive indexes, timestamp triggers, Realtime publication entries, and seven seeded categories for existing and future owner-provisioned households. Categories support rename/color/archive/restore; historical expense references remain intact when a category is archived.

Both tables enable and force household RLS. Select policies use `private.current_household_id()`; inserts check creator/updater against the authenticated actor and updates check the updater. Explicit insert/update column grants protect creation timestamps and immutable ownership/creator fields. No client hard-delete grant is provided. Composite foreign keys require both `paid_by` and `category_id` to belong to the expense household. EUR and positive `numeric(12,2)` amounts are enforced. `shared` is informational and has no effect on visibility or totals.

Optional receipt paths must match the expense household/ID and a UUID JPEG filename. Four additive Storage policies permit household receipt read/insert/update/delete only through an existing expense in the current household. Earlier task/recipe policies are unchanged. `expenses_security.test.sql` contains 49 authored assertions, including foreign payer/category rejection, historical category retention, private Storage access, archive/restore and preservation of forced RLS on the 19 earlier tables. Execution awaits the local database runtime; static inspection is not a passing pgTAP run.

Private bucket:
```text
household-media/
  {household_id}/tasks/{task_id}/{uuid}.jpg
  {household_id}/recipes/{recipe_id}/{uuid}.jpg
  {household_id}/expenses/{expense_id}/{uuid}.jpg
  {household_id}/avatars/{user_id}/{uuid}.jpg
```

## RLS
Use a safe helper for current user's household where appropriate.
- SELECT only own household.
- INSERT only with own household_id when the feature explicitly grants client inserts.
- UPDATE/archive only own household and only permitted columns.
- Child rows authorize through parent household.
- users manage their own device rows.
- recipients read their own notifications; trusted backend creates push-related records as designed.
- household members may read household activity.

Phase 1 provisioning creates exactly two profile rows for existing Auth users through the private database-owner function. Clients cannot insert/delete households or profiles, or change profile IDs/household IDs. The private schema is not exposed; security-definer functions pin an empty `search_path` and schema-qualify relations. All Phase 1 tables have RLS enabled and forced. Anonymous table access is revoked; authenticated grants are explicit and narrow.

Never grant broad access to work around RLS.

## Realtime
Enable only required tables; RLS still applies. Likely: tasks/assignees/checklists/images, meals/ingredients, shopping_general, events/assignees, expenses, notifications.

## Search/indexes
Index household_id and frequent status/date/archive filters. Start search simply with controlled Postgres queries; move to FTS only if needed. Exclude shopping history.

Phase 7 additive migration `20261003120000_phase7_home_activity_search.sql` creates `activity_log` with forced household RLS, authenticated SELECT only, no anonymous access, and a household/timestamp/ID index. Six AFTER INSERT/UPDATE triggers log parent mutations on tasks, recipes, meals, events, expenses and shopping_general. The private trigger function is security-definer with an empty search path and no client execution grant. It derives actor from `auth.uid()`, validates the actor's membership against the actual entity household, and inserts the entity ID/action/server timestamp. Metadata is an empty JSON object; titles, descriptions, amounts, notes, receipts and full snapshots are not copied. Timestamp/updater-only and identical updates are suppressed. Unauthenticated administrative writes are not attributed. No historical backfill, delete logging, or child-row logging is included. Activity is published to Realtime.

`search_household_entities(query_text, archived_only, page_offset)` is a stable SQL security-invoker function with a pinned empty search path, executable only by authenticated users. It unions the five supported entity tables under their unchanged RLS policies, excludes Shopping, returns archive flags, and uses literal case-insensitive substring matching. Results are ordered by type/lowercase title/ID, limited to 100 per page. An empty query returns nothing except in archive mode. There is no caller household parameter or privileged search bypass. Existing grants and migrations remain unchanged.

`phase7_security.test.sql` covers new grants/forced RLS, non-forgeable activity, no-op suppression, actor attribution, lifecycle actions, publication, literal/description/entity search, archive groups, pagination and two-household isolation. It is authored and statically reviewed, not runtime-verified while Docker/Postgres is unavailable.

## Backup
Export safe structured data with `schema_version`/`exported_at`. Exclude auth secrets/tokens, FCM tokens, signed URLs and binaries.

## Migration and RLS tests
Recreate local state with `supabase db reset`; run the pgTAP household-isolation suite with `supabase test db`. Each future feature migration must enable/force RLS and add explicit grants and policies before exposing a table to the client.

## Phase 2 task schema details

The task tables are added by an additive migration; Phase 1 household and Auth records are untouched. Task and template child rows carry a household key tied to their parent by composite foreign keys. RLS checks the parent household for checklist, template-checklist and image metadata. Parent IDs and household IDs are not client-updatable, and authenticated grants name mutable columns explicitly. Task images use the private `household-media` bucket with `{household_id}/tasks/{task_id}/{file}` object keys. Realtime publication includes task/category/assignee/checklist/template tables and remains governed by RLS. Template instances reference their source template, but their fields and checklist rows are independent; old images are never copied.
