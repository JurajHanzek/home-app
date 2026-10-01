# HomeHub — Supabase Database & Security v0.0.1

Use UUID PKs, `household_id` on household-owned top-level records, timestamps, archive timestamps and RLS on every user-accessible table.

## Tables
- `households`: id, name, created_at
- `profiles`: id/auth user id, household_id, display_name, initials, avatar_path, accent_color, timestamps
- `user_devices`: id, user_id, fcm_token unique, platform, updated_at, disabled_at
- `task_categories`: id, household_id, name, color, icon, archived_at, timestamps; seed Outdoor/Indoor
- `tasks`: id, household_id, title, description, status, priority, category_id, due_at, reminder_at, created_by, updated_by, lifecycle timestamps, source_template_id
- `task_assignees`: task_id, user_id
- `task_checklist_items`: id, task_id, label, is_done, sort_order
- `task_images`: id, task_id, storage_path, size_bytes, dimensions optional, created_by, created_at, removed_at
- `task_templates`: id, household_id, title, description, category_id, priority, enabled, due/reminder offsets, created_by/updated_by, timestamps, archived_at
- `task_template_assignees`: template_id, user_id
- `task_template_checklist_items`: id, template_id, label, sort_order
- `recipes`: id, household_id, name, image_path, instructions, audit/lifecycle fields
- `recipe_ingredients`: id, recipe_id, label, quantity, unit, sort_order
- `meals`: id, household_id, planned_at, recipe_id nullable, custom_name, servings, notes, audit/lifecycle fields
- `meal_ingredients`: id, meal_id, label, quantity, unit, have, sort_order
- `shopping_general`: id, household_id, label, is_done, note, audit/lifecycle fields
- `events`: id, household_id, title, description, start/end, all_day, location, category/color, reminder_at, recurrence jsonb nullable, audit/lifecycle fields
- `event_assignees`: event_id, user_id
- `expense_categories`: id, household_id, name, color, archived_at, timestamps
- `expenses`: id, household_id, amount numeric(12,2), currency default EUR, title, category_id, paid_by, shared, expense_date, note, receipt_path, audit/lifecycle fields
- `notifications`: id, household_id, recipient_user_id, type, entity_type/id, title, body, data jsonb, read_at, created_at
- `activity_log`: id, household_id, actor_user_id, action, entity_type/id, metadata jsonb, created_at
- `household_settings`: household_id, default_theme, notification_preferences jsonb, storage_warning_settings jsonb, updated_at

When creating a meal from a recipe, copy recipe ingredients into `meal_ingredients` so `have` state is independent and later recipe edits do not silently rewrite planned meals.

Meal-derived shopping is initially a query of the next two meals' `meal_ingredients where have=false`; do not duplicate it into another shopping table unless later UX requires independent state.

## Storage
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
- INSERT only with own household_id.
- UPDATE/archive only own household.
- Child rows authorize through parent household.
- users manage their own device rows.
- recipients read their own notifications; trusted backend creates push-related records as designed.
- household members may read household activity.

Never grant broad access to work around RLS.

## Realtime
Enable only required tables; RLS still applies. Likely: tasks/assignees/checklists/images, meals/ingredients, shopping_general, events/assignees, expenses, notifications.

## Search/indexes
Index household_id and frequent status/date/archive filters. Start search simply with controlled Postgres queries; move to FTS only if needed. Exclude shopping history.

## Backup
Export safe structured data with `schema_version`/`exported_at`. Exclude auth secrets/tokens, FCM tokens, signed URLs and binaries.
