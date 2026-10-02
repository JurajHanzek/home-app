# HomeHub — Product Specification v0.0.1

## Product
Private Android household organizer for two initial users: Home, Tasks, Meals/Recipes, Shopping, Calendar, Expenses, Search/Archive, Notifications, Settings and JSON backup. No Play Store requirement.

Principles: simple workflows; shared realtime household state; Supabase source of truth; archive important records; internet required in v0.0.1; last-write-wins; global search excludes shopping history.

## Themes
**Dark Mode:** AMOLED true-black page, app-bar and navigation backgrounds; neutral near-black cards and dialogs with subtle borders; restrained cool-blue accents, clear off-white text and muted secondary text. Use flat surfaces, simple rounded controls and clean typography. Preserve semantic task-status colors.
**Flower Mode:** pale mint-to-ivory botanical background, deep leafy-green buttons and text accents, sage/olive selected states and small lilac/blush floral accents. Use ivory cards, soft rounded controls and original floral/leaf corner illustrations, keeping the central reading area clear. A brief bloom entrance settles into a static background and is skipped when reduced motion is enabled.
Both use the same component/layout structure and centralized design tokens.
Application-wide font size is a user preference under Settings / Options: Small, Normal, or Large, with Normal as the default. It is persisted on the device and applied through the centralized AppFontSize design token and global text scaling in every screen.

## Household & profiles
One household, two pre-created users, no public registration UI. Profiles: display name, initials/avatar, accent color. Assignment supports nobody/User A/User B/both. Assignment describes responsibility/attendance, not visibility.

## Home
Answer “What matters right now?” with today's events, due/overdue tasks, next meal, missing ingredients, task/shopping summaries, current-month expenses, recent Activity/Inbox items and storage warnings where applicable. Expenses remain accessible from Home and are not a sixth bottom-navigation item in v0.0.1.

Phase 7 uses a compact scrolling dashboard: Today includes active overlapping Calendar events and unfinished tasks due on the local calendar date; Attention includes unfinished tasks due before today and the next meal's missing ingredients only when that meal is today or tomorrow. Today/Attention previews are capped with links to the full feature. Done and archived tasks are excluded from due/overdue summaries. Next Meal and Shopping counts reuse the next-two-meals rules without merging ingredient rows. Expenses uses active current-calendar-month integer-cent totals and `paid_by` totals. Search and Archive are Home actions. Recent Activity shows five entries with access to the latest 50 in Activity / Inbox. Storage warning implementation remains with Settings; no speculative alerts are added here.

## Tasks
Lifecycle: `To Do → In Progress → Done → Archived`.
Initial categories: **Outdoor** and **Indoor**; users can add and archive categories later.

Task filter choices open from a Filters button, matching Expenses. Only applied status/category filters appear on the list as removable chips with Clear all. Apply commits the dialog selection; Cancel leaves existing filters unchanged. Category add/manage actions and archived-task access remain separate toolbar actions.

The Tasks screen uses one compact **Unified Task List**. By default it shows all non-archived To Do, In Progress, and Done tasks together. Each row has a semantic left-edge status indicator: blue for To Do, yellow for In Progress, and gray for Done. Status filters for To Do, In Progress, and Done are independently clearable; no status is selected by default. Category filtering (including Outdoor/Indoor and user categories) is independent of the status filter. Archived tasks are opened separately and are not a fourth active status filter.

Fields: title, shared editable description, status, category, priority, 0/1/2 assignees, optional due/reminder, checklist, images, actor/timestamp metadata. Task reminders are disabled unless a user explicitly enables one. Done tasks stay Done until manually archived; automatic task archiving is not included in v0.0.1. No comments. Both users edit the same description. Editing a task assigned to the other user is allowed and can notify them. Archived tasks remain searchable/restorable. Permanent delete is exceptional and confirmed.

### Repetitive task templates
A task may be marked **Repetitive task** and saved as a reusable template (e.g. mowing the lawn). Preserve title, description, category, priority, default assignees, checklist and optional due/reminder offsets.

Completing/archiving an instance never deletes its template. A new instance is independent; editing it does not alter the template unless explicitly updating the template. Old task images are not copied by default.

v0.0.1 uses **manual template activation**, not automatic every-X-days generation. Keep schema extensible for future recurrence.

## Images
Private Supabase Storage. Compress/resize on device before upload; target approximately **≤500 KB**. DB/JSON stores path/metadata, never binaries. Meal/recipe images are protected by default. Track both image count and storage size. The default warning accounts for 100 task images and configured storage-budget usage; thresholds are configurable and the app enforces no hard storage limit. No automatic cleanup in v0.0.1. Settings shows counters/warnings; manual cleanup should prefer oldest archived-task images and never active-task images by default.

## Meals & Recipes
The Meals screen opens on upcoming planned meals, with clear access to the recipe library and Add Meal. Past and archived meals remain accessible separately. Upcoming cards prioritize date/day, meal name, servings, recipe image when available, and an ingredient availability/missing count. A meal detail shows its full ingredient list and `have` controls.

`Add Meal → From Recipes` or `Add Meal → New Meal`. From Recipes snapshots the recipe's current ingredients into new meal ingredient rows. Later recipe changes do not rewrite existing meals. A custom meal may be planned without a recipe and may be saved as a reusable recipe only when the user explicitly opts in.

Recipes: name, optional private image, ordered ingredients with optional quantity/unit, instructions/notes, archive/restore. Planned meal: date, optional time/meal slot, optional recipe reference, name snapshot, servings, notes, and independent ingredients.

Ingredient `have` state belongs to the **planned meal instance**. No global pantry/fridge inventory. Rice marked available tomorrow says nothing about a later meal.
Ingredient strings are kept as entered; do not normalize, merge, or infer availability between meals.

## Shopping
Two sections:
1. **Next 2 meals** — every missing ingredient string, grouped by meal.
2. **General** — manually entered strings with checked/unchecked state.

No aggregation/normalization. `crveni luk` and `luk` remain separate. Shopping history is excluded from global search. Rapid additions should be eligible for grouped push.

Next 2 meals uses the next two non-archived upcoming meals in date/time order and shows only their `meal_ingredients` with `have=false`. Checking an item updates that exact meal ingredient row; ingredient state remains independent across meals and is never copied to the recipe. General items are a separate shared household list with quick add, check/uncheck, edit, and archive/restore. Completed General items are visually grouped so they do not crowd the active list. No persisted shopping rows are created for meal-derived ingredients.

## Calendar
Calendar opens in a compact Month view with a standard seven-column, Monday-first grid, month navigation, a Today action, and color dots for event days. Selecting a date shows its events chronologically below the grid. Month and Agenda modes are available; Agenda groups Today and Upcoming, with Past and Archived events accessible separately. A new event opened from Month defaults to the selected date. Events are visible to all household users regardless of assignment; assignment indicates who is involved, not who may view the event. Events may be assigned to nobody, one user, or both users.

Fields: title, description, start/end date and time, all-day state, location, optional category and color, optional reminder, recurrence metadata, creator/audit and archive metadata. Reminders are off unless a user explicitly enables one; delivery is deferred to Notifications. Keep recurrence metadata ready for future use without generating recurring instances in this phase.

## Expenses
Lightweight household ledger: amount, EUR initially, title/merchant, category, paid_by, shared yes/no, date, note, optional receipt image, archive/audit metadata.

Initial expense categories: **Groceries**, **Home**, **Bills**, **Transport**, **Health**, **Leisure**, and **Other**. Both users can manage and archive household categories.

v0.0.1: current-month total, category breakdown, who paid what.
Ledger filters open through a Filters button: month/year, category, payer, and shared/personal type. Filter controls stay hidden until opened; applied filters appear as individually removable chips with Clear all. Filters combine, apply to the current active/archived view, and show the matching total. Without filters, retain the current-month summary.
No bank integrations, OCR, receipt parsing, advanced budgeting or debt settlement.

## Activity / Inbox
Notifications and activity share one screen with filters: **All**, **Notifications**, and **Activity**. Activity records actor, action, entity type/id, timestamp and small metadata for meaningful mutations; it is not chat.

Phase 7 provides the Activity foundation and Activity / Inbox route only. Database triggers record parent task/recipe/meal/event/expense and General shopping creation, meaningful parent changes and lifecycle transitions. Identical parent saves do not log; child-only checklist/assignment/ingredient changes are not individual activity entries. Activity begins when the migration is applied, with no fabricated historical backfill. Phase 8 can compose recipient notifications with these records and add the All / Notifications / Activity filters; no notification records or push delivery are implemented in Phase 7.

## Notifications
Supabase owns logic/state; FCM delivers Android push.
- assignment/reassignment/taking another user's task → affected user;
- other user edits a task assigned to you → push;
- never self-push;
- task completed → configurable;
- rapid shopping additions → grouped;
- meal changed → other user;
- upcoming meal missing ingredients → configurable reminder, disabled by default until notification UX is implemented;
- event created/changed/reminder → relevant users;
- expense notifications configurable, default may be off.

Deep links to relevant task/meal/shopping/event/expense. Keep in-app notification/activity history.

## Realtime & connectivity
Near-realtime Supabase updates. No offline-first editing. Network failure may make features unavailable but must not crash. Last-write-wins.

## Search
Search active/archived tasks and descriptions, recipes, meals, events and expenses. Exclude shopping history. Group results by entity type.

Search is submitted explicitly and performs case-insensitive literal substring matching in titles/names and descriptions/instructions/notes. Results include archive labels and reuse existing detail experiences through standalone routes. Results load in pages of 100, with Load more; empty queries do not fetch records. Search and Archive use an invoker-authorized database function over existing RLS tables, never a client-only household filter.

## Archive
Archive/restore is the normal removal lifecycle. Permanent delete is exceptional and explicit.

The unified Archive groups archived Tasks, Recipes, Meals, Calendar Events and Expenses. Open an archived item to use its existing restore action; tasks restore through their existing status menu. General Shopping stays in its own feature. This workflow has no permanent-delete action. Android back returns from details to Search/Archive and then to Home.

## Backup
Export structured household data to JSON with `schema_version`; no image binaries. Never export passwords, auth/FCM tokens, secrets or signed URLs. Include safe profile metadata, categories, tasks/checklists/templates, recipes, meals/ingredient states, general shopping, events, expenses and safe settings.

## Non-goals v0.0.1
Offline-first sync; collaborative text merging; automatic image cleanup; automatic task recurrence; pantry inventory; ingredient aggregation; task comments/chat; bank/OCR features; elaborate analytics/animations; Play Store distribution.
