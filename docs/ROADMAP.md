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
- [x] reproducible migrations and local Supabase Auth configuration
- [x] households/profiles/devices/settings
- [x] private sign-in-only auth flow, no public signup
- [x] restrictive RLS policies and household-isolation pgTAP cases authored
- [x] hosted Auth, household provisioning, login and household-gated routing manually verified by product owner
- [!] execute the migration and RLS suite against local Supabase/Postgres
**Gate:** Approved to proceed for feature development based on hosted verification. Local pgTAP execution remains a required v0.0.1 production-readiness check; it does not block Phase 2 development.

## Phase 2 — Tasks
- [x] additive database migration for Outdoor/Indoor + household-managed categories
- [x] CRUD + mobile Unified Task List + independent filters + detail/shared description
- [x] Product-owner Tasks UX revision + global persisted Small/Normal/Large font preference
- [x] 0/1/2 assignees + ordered checklist + due/reminder
- [x] archive/restore
- [x] on-device image resize/compression + private Storage paths
- [x] realtime synchronization
- [x] repetitive templates/manual reuse
- [x] Flutter and pgTAP security tests authored
- [x] apply hosted migration (verified in linked migration history)
- [!] execute local pgTAP/RLS verification
**Gate:** Product owner approved the Tasks UX checkpoint and Phase 3 start. Local database security execution remains a v0.0.1 readiness check and does not block Phase 3.

## Phase 3 — Meals & Recipes
- [x] additive RLS migration for recipes, recipe ingredients, meals and meal ingredients
- [x] recipe CRUD, ordered ingredients and private compressed images
- [x] upcoming meals, recipe library and custom/from-recipe creation flows
- [x] materialized ingredient snapshots and independent per-meal `have`
- [x] realtime and Flutter/pgTAP tests authored
- [!] apply hosted migration and execute local pgTAP/RLS verification
**Gate:** Product owner approved Phase 3 and will handle its pending hosted migration manually. Application of that migration has not been confirmed in this workspace; local database security execution awaits a running Docker daemon. This no longer blocks Phase 4 implementation.

## Phase 4 — Shopping
- [x] additive household-RLS migration for the independent General list
- [x] next two active upcoming meals, chronological and grouped by meal, showing only `have=false`
- [x] preserve exact ingredient strings and duplicates; checking updates only that meal ingredient row
- [x] fast General add, check/uncheck, edit, archive/restore, and a collapsed completed-items section
- [x] realtime for General items, meals, and meal-ingredient changes
- [x] typed models/repository, empty/loading/error/retry states, and behavioral/widget/pgTAP tests authored
- [!] execute the database/pgTAP suite when the local Supabase database is available
- [x] formatting, analysis, Flutter tests, Android debug build, and phase documentation
**Gate:** Phase 4 implementation checkpoint is complete. The migration is additive and prepared for owner deployment after Phase 3 is applied. Local pgTAP execution remains outstanding. Phase 5 proceeded after product-owner approval.

## Phase 5 — Calendar
- [x] additive event and event-assignee migration with household RLS and 0/1/2 assignee enforcement
- [x] Month-first Calendar UX with Monday-first event-dot grid, selected-day event list, and Month/Agenda modes
- [x] event create/edit/detail/archive/restore in the agenda, with separate Past and Archived views
- [x] date/time/all-day/location/description/category/color fields
- [x] reminder opt-in defaults off; recurrence-ready metadata stored without automatic generation
- [x] household realtime for events and assignees
- [x] typed models/repository, Flutter behavior/widget tests, and 31 pgTAP security assertions authored
- [!] execute the database/pgTAP suite when the local Supabase database is available
- [x] formatting, analysis, Flutter tests, Android debug build, and phase documentation
**Gate:** Phase 5 Calendar and the Month-view UX revision were approved by the product owner. Phase 6 continued the existing unfinished implementation. Local pgTAP execution remains outstanding.

## Phase 6 — Expenses
- [x] seven seeded categories with create/edit/archive/restore; historical references retained
- [x] expense create/edit/detail with separate paid_by/created_by, informational shared flag and EUR
- [x] optional compressed private receipt, stable UUID path and temporary signed display URLs
- [x] archive/restore
- [x] active current-month total/category breakdown/paid_by totals using integer cents
- [x] household realtime, typed repository/models and loading/error/empty states
- [x] Flutter model/repository/widget tests and 49 pgTAP assertions authored
- [x] formatting, analysis, Flutter tests, Android debug APK and checkpoint documentation
- [!] local pgTAP execution and owner-managed hosted migration deployment
**Gate:** Phase 6 approved by the product owner. Phase 7 proceeded with existing features preserved; hosted migration deployment and database security execution remain owner-managed/pending.

## Phase 7 — Search / Archive / Home
- [x] global RLS-protected search of five specified entities, excluding Shopping
- [x] unified Archive with existing detail/restore behavior and back navigation
- [x] compact Today/Attention/Next Meal and task/shopping/current-month expense summaries
- [x] durable household Activity foundation, server-authored mutations and recent activity
- [x] compose existing realtime providers; keep five bottom destinations
- [x] Flutter model/repository/widget and additive pgTAP coverage authored
- [x] formatting, clean analysis, all 80 Flutter tests and checkpoint documentation
- [!] owner-managed hosted migration and runtime pgTAP verification
Storage warnings remain in Phase 9 Settings; no speculative warning system was introduced. Phase 8 Notifications/FCM and the final production APK are outside this checkpoint.
**Gate:** Phase 7 implementation checkpoint complete for owner review. The 42-assertion pgTAP suite is authored but unexecuted because Docker's engine is unavailable. No hosted migration, destructive database action, or APK build was performed in Phase 7. Stop here; Phase 8 has not started.

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
