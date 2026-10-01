# HomeHub — Product Specification v0.0.1

## Product
Private Android household organizer for two initial users: Home, Tasks, Meals/Recipes, Shopping, Calendar, Expenses, Search/Archive, Notifications, Settings and JSON backup. No Play Store requirement.

Principles: simple workflows; shared realtime household state; Supabase source of truth; archive important records; internet required in v0.0.1; last-write-wins; global search excludes shopping history.

## Themes
**Dark Mode:** modern charcoal/black surfaces with restrained accents.
**Flower Mode:** cream base, darker olive accents, selective charcoal/black elements and tasteful botanical decoration without reducing readability.
Both use the same component/layout structure and centralized design tokens.

## Household & profiles
One household, two pre-created users, no public registration UI. Profiles: display name, initials/avatar, accent color. Assignment supports nobody/User A/User B/both. Assignment describes responsibility/attendance, not visibility.

## Home
Answer “What matters right now?” with today's events, due/overdue tasks, next meal, missing ingredients, task/shopping summaries, current-month expenses, recent activity and storage warning where applicable.

## Tasks
Lifecycle: `To Do → In Progress → Done → Archived`.
Initial categories: **Outdoor** and **Indoor**; users can add categories later.

Fields: title, shared editable description, status, category, priority, 0/1/2 assignees, optional due/reminder, checklist, images, actor/timestamp metadata. No comments. Both users edit the same description. Editing a task assigned to the other user is allowed and can notify them. Archived tasks remain searchable/restorable. Permanent delete is exceptional and confirmed.

### Repetitive task templates
A task may be marked **Repetitive task** and saved as a reusable template (e.g. mowing the lawn). Preserve title, description, category, priority, default assignees, checklist and optional due/reminder offsets.

Completing/archiving an instance never deletes its template. A new instance is independent; editing it does not alter the template unless explicitly updating the template. Old task images are not copied by default.

v0.0.1 uses **manual template activation**, not automatic every-X-days generation. Keep schema extensible for future recurrence.

## Images
Private Supabase Storage. Compress/resize on device before upload; target approximately **≤500 KB**. DB/JSON stores path/metadata, never binaries. Meal/recipe images are protected by default. No automatic cleanup in v0.0.1. Settings shows counters/warnings; manual cleanup should prefer oldest archived-task images and never active-task images by default.

## Meals & Recipes
`Add Meal → From Recipes` or `Add Meal → New Meal`.
Recipes: name, optional image, ingredients with optional quantity/unit, instructions/notes.
Planned meal: date/slot, optional recipe, custom name, servings, notes.

Ingredient `have` state belongs to the **planned meal instance**. No global pantry/fridge inventory. Rice marked available tomorrow says nothing about a later meal.

## Shopping
Two sections:
1. **Next 2 meals** — every missing ingredient string, grouped by meal.
2. **General** — manually entered strings with checked/unchecked state.

No aggregation/normalization. `crveni luk` and `luk` remain separate. Shopping history is excluded from global search. Rapid additions should be eligible for grouped push.

## Calendar
Household events assigned to nobody/one/both users; all household users can see them. Fields: title, description, start/end, all-day, location, assignees, category/color, reminder, recurrence metadata, archive metadata. Schema should be recurrence-ready.

## Expenses
Lightweight household ledger: amount, EUR initially, title/merchant, category, paid_by, shared yes/no, date, note, optional receipt image, archive/audit metadata.

v0.0.1: current-month total, category breakdown, who paid what.
No bank integrations, OCR, receipt parsing, advanced budgeting or debt settlement.

## Notifications
Supabase owns logic/state; FCM delivers Android push.
- assignment/reassignment/taking another user's task → affected user;
- other user edits a task assigned to you → push;
- never self-push;
- task completed → configurable;
- rapid shopping additions → grouped;
- meal changed → other user;
- upcoming meal missing ingredients → reminder;
- event created/changed/reminder → relevant users;
- expense notifications configurable, default may be off.

Deep links to relevant task/meal/shopping/event/expense. Keep in-app notification/activity history.

## Realtime & connectivity
Near-realtime Supabase updates. No offline-first editing. Network failure may make features unavailable but must not crash. Last-write-wins.

## Search
Search active/archived tasks and descriptions, recipes, meals, events and expenses. Exclude shopping history. Group results by entity type.

## Archive
Archive/restore is the normal removal lifecycle. Permanent delete is exceptional and explicit.

## Backup
Export structured household data to JSON with `schema_version`; no image binaries. Never export passwords, auth/FCM tokens, secrets or signed URLs. Include safe profile metadata, categories, tasks/checklists/templates, recipes, meals/ingredient states, general shopping, events, expenses and safe settings.

## Activity
Record actor, action, entity type/id, timestamp and small metadata for meaningful mutations. Activity is not chat.

## Non-goals v0.0.1
Offline-first sync; collaborative text merging; automatic image cleanup; automatic task recurrence; pantry inventory; ingredient aggregation; task comments/chat; bank/OCR features; elaborate analytics/animations; Play Store distribution.
