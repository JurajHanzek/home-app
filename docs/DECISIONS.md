# HomeHub — Decisions Log

- **D-001 Backend:** Supabase is source of truth.
- **D-002 Push:** FCM only for Android push delivery; no other Firebase backend products.
- **D-003 Connectivity:** v0.0.1 is online-required.
- **D-004 Concurrency:** last successful write wins.
- **D-005 Tasks:** no comments/chat; shared editable description.
- **D-006 Shopping:** no ingredient aggregation/normalization.
- **D-007 Pantry:** no global pantry; `have` is per planned meal.
- **D-008 Deletion:** archive/restore preferred.
- **D-009 Images:** on-device compression target ~500 KB; no automatic cleanup v0.0.1.
- **D-010 Repetitive tasks:** reusable templates/manual activation; automatic recurrence deferred.
- **D-011 Backup:** structured JSON; image binaries excluded.
- **D-012 Expenses:** lightweight household ledger, not banking/budget platform.
- **D-013 Expenses navigation:** Expenses remains accessible from Home and is not a sixth bottom-navigation destination in v0.0.1.
- **D-014 Expense categories:** seed Groceries, Home, Bills, Transport, Health, Leisure, and Other. Categories remain household-managed and archivable.
- **D-015 Storage monitoring:** monitor both image count and storage bytes; the default warning accounts for 100 task images and configured storage-budget usage. Thresholds remain configurable, with no hard application limit. Cleanup is manual in v0.0.1.
- **D-016 Task completion:** Done tasks stay in Done until manually archived. Automatic task archiving is excluded from v0.0.1.
- **D-017 Reminders:** task and event reminders are off unless the user explicitly enables one. Missing-meal-ingredient reminders are configurable and default to disabled until notification UX is implemented.
- **D-018 Activity and notifications:** use one combined Activity/Inbox screen with All, Notifications, and Activity filters.
- **D-019 Tasks list UX:** use a Unified Task List showing all active statuses by default. Use clearable independent status filters and a separate archived view. Status indicators are semantic theme tokens: blue To Do, yellow In Progress, gray Done.
- **D-020 Font size preference:** provide application-wide Small, Normal, and Large font-size options under Settings / Options. Normal is the default; persist the choice on-device and apply it through the global font-size design token and text scaling.

Append future durable decisions; do not rewrite history.

- **D-021 Phase 7 Activity foundation:** log meaningful parent mutations in database triggers with server-derived actor/household and empty metadata; do not backfill history or log every child toggle. Reuse the Activity store when Phase 8 adds notifications and combined filters.
- **D-022 Home attention:** task due dates are day-based; unfinished tasks before the local current date are overdue. Missing ingredients become Attention only for the next meal today or tomorrow. Next Meal/Shopping counts always retain approved per-meal row semantics.
- **D-023 Phase 7 Search/Archive:** authenticated security-invoker substring RPC over the five existing RLS domains, paginated 100 at a time. Reuse existing feature detail widgets and restore handlers through standalone entity routes.
