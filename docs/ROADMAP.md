# HomeHub — Autonomous Development Roadmap

Legend: `[ ]` not started · `[~]` in progress · `[x]` complete · `[!]` blocked

## Phase 0 — Foundation
- [x] Flutter project/repository inspection or creation
- [x] feature-oriented structure
- [x] justified dependencies only
- [x] bootstrap/config/routing/state management
- [x] Dark + Flower theme foundation
- [x] Supabase client config without committed secrets
- [x] base loading/error patterns and tests
- [x] format/analyze clean
**Gate:** app launches; navigation/theme foundation works. Passed: Android debug APK builds and widget checks cover navigation/theme switching.

## Phase 1 — Auth / Household / Security
- [ ] reproducible migrations
- [ ] households/profiles/devices/settings
- [ ] private two-user auth, no public signup
- [ ] RLS and household isolation tests
**Gate:** authorized users see only their household.

## Phase 2 — Tasks
- [ ] Outdoor/Indoor + custom categories
- [ ] CRUD + board + detail/shared description
- [ ] 0/1/2 assignees + checklist + due/reminder
- [ ] archive/restore
- [ ] image compression/private upload
- [ ] realtime
- [ ] repetitive templates/manual reuse
- [ ] tests
**Gate:** reliable shared two-user task workflow.

## Phase 3 — Meals & Recipes
- [ ] recipe CRUD/ingredients/image
- [ ] meal from recipe / new meal
- [ ] materialized meal ingredients
- [ ] independent per-meal `have`
- [ ] realtime/tests

## Phase 4 — Shopping
- [ ] next 2 meals, grouped, missing strings
- [ ] no aggregation/normalization
- [ ] general shopping CRUD/check
- [ ] realtime/tests

## Phase 5 — Calendar
- [ ] event CRUD + 0/1/2 assignees
- [ ] date/time/all-day/location/description
- [ ] reminders + recurrence-ready storage
- [ ] archive/realtime/tests

## Phase 6 — Expenses
- [ ] categories + CRUD
- [ ] paid_by/shared/EUR
- [ ] optional compressed receipt
- [ ] archive
- [ ] month total/category breakdown/who-paid-what
- [ ] realtime/tests

## Phase 7 — Search / Archive / Home
- [ ] global search specified entities, excluding shopping history
- [ ] archive access
- [ ] Today/Attention/Next meal
- [ ] task/shopping/expense summaries
- [ ] recent activity + storage warning

## Phase 8 — Notifications / FCM
- [ ] Android FCM client + device tokens
- [ ] trusted server send path
- [ ] notification records/rules
- [ ] no self-push
- [ ] shopping grouping
- [ ] deep links
- [ ] in-app history
- [ ] tests where practical

## Phase 9 — Backup / Settings / Polish
- [ ] versioned JSON export without images/secrets
- [ ] import validation as agreed
- [ ] storage counters/warnings + manual cleanup if included
- [ ] notification prefs
- [ ] theme/profile/category polish
- [ ] empty/loading/error states
- [ ] smoke tests + format/analyze/tests
- [ ] final REVIEW.md

## Deferred
Automatic scheduled repetitive tasks; automatic image cleanup; offline-first editing; pantry inventory; ingredient aggregation; bank/OCR features; advanced budgeting; advanced recurrence UI; Play Store distribution.
