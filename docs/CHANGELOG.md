# HomeHub — Changelog

## Unreleased — v0.0.1
Planned: private two-user Android app; Dark/Flower themes; shared tasks + repetitive templates; meals/recipes; next-two-meals + general shopping; calendar; expenses; realtime; FCM; global search/archive; JSON backup.

## 2026-10-03 — Phase 7 Home, Search, Archive and Activity
- Replaced basic Home with compact Today, actionable Attention, Next Meal, Tasks/Shopping/current-month Expenses and Recent Activity sections, sharing existing feature providers and semantic theme colors.
- Added explicit-submit, grouped household Search and Unified Archive, paginated in batches of 100, with archive labels and existing detail/restore behavior. Kept all five bottom destinations and Home access to Expenses.
- Added standalone entity detail routes reusing original feature widgets/editors/repositories, with unavailable-record states and back navigation.
- Added an additive, forced-RLS Activity table, trusted database mutation logging and invoker-authorized Search RPC; no client-write privilege for activity and no Shopping search.
- Added dashboard model/layout tests, all-five-entity navigation tests, Archive/restore and repository/state coverage, plus an authored pgTAP isolation suite. Hosted deployment, runtime pgTAP and the separately reviewed production APK remain pending. Phase 8 has not started.
- Verification: formatting and analysis passed; all 80 Flutter tests passed (55 existing and 25 new). The 42 Phase 7 pgTAP assertions remain unexecuted because Docker's engine is unavailable. No APK build, hosted deployment or destructive database command was run.

## 2026-10-03 — Flower navigation and Tasks filter UX
- Added original vector flowering vines around the bottom navigation in Flower Mode, with a finite 1.6-second bloom on entry/tab changes and reduced-motion support. Reserved edge space keeps the five destinations clear; decorations ignore gestures and semantics.
- Replaced the always-visible filter panel with an on-demand Filters dialog, matching Expenses. Only applied status/category selections appear as removable chips; Clear all restores the unfiltered list. Kept category actions and archive access in the toolbar. Updated interaction coverage for apply, cancel and clearing.

## 2026-10-02 — Phase 6 Expenses checkpoint
- Softened Flower cards and the Tasks filter panel by removing outlines. Flower task cards now use a pale botanical surface, a subtle floral watermark, inset rounded status markers and borderless pill badges; Dark styling is preserved.
- Fixed Task/Event/Expense editor padding with explicit dialog insets, scroll-edge space for floating labels and 14-pixel field gaps. Deepened Flower greens and expanded botanical clusters. Increased Calendar markers to 7 pixels with event-day rings/tints and theme-adjusted color contrast; tasks now use wider status strips and bordered status badges.
- Redesigned Flower Mode with mint, ivory, forest green and sage, lilac/blush botanical details, soft rounded controls and original vector corner illustrations. Added a brief reduced-motion-aware bloom entrance, isolated from content repainting and touch handling.
- Refined Dark Mode globally to AMOLED black with neutral layered surfaces, subtle card outlines, a muted cool-blue accent, flat navigation/buttons, rounded filled fields and cleaner typography. Flower Mode remains unchanged for its separate design pass.
- Added on-demand month, category, payer and shared/personal filters, applied-only removable chips, Clear all, matching totals and a filtered-empty state. Added matching and apply/cancel/clear interaction coverage.
- Adjusted Expenses spacing after device review: consistent 16-pixel outer padding, 12-pixel gaps between summary/ledger cards, roomier card content, and safe-area spacing for the add action.
- Continued the previous session's four Expenses Flutter files, router integration, additive migration and security suite without restarting the feature or discarding Calendar work.
- Completed the Home-accessible household ledger with create/edit/detail, EUR amounts, categories, separate payer/creator, informational shared flag, date/note, archive/restore, and current-month total/category/payer summaries.
- Retained on-device receipt compression and private household Storage; corrected filenames to UUIDs, added standalone screen/back navigation, and fixed analyzer findings. Receipts support preview, replacement/removal and temporary signed URLs.
- Preserved forced household RLS and composite category/payer foreign keys; tightened insert grants and receipt-path validation. Expanded the security suite from 35 to 49 authored assertions.
- Added Expenses model, widget and mocked-HTTP repository coverage. Formatting, analysis, all 48 Flutter tests and Android debug APK build passed. Local database execution remains pending because Docker's engine is unavailable. Hosted deployment remains owner-managed; Phase 7 has not started.

## 2026-10-01 — Phase 0 foundation
- Created the Android Flutter app scaffold and feature-oriented base structure.
- Added Riverpod state, go_router navigation, Material 3 Dark/Flower themes, and Home access to Expenses.
- Added optional client-safe Supabase bootstrap, reusable async loading/error UI, and widget tests.
- Verified formatting, analysis, widget tests, and Android debug APK build.

## Phase 1 — Auth / Household / Security (hosted flow verified; local database check pending)
- Added email/password sign-in without public account creation, protected routing, and household membership loading.
- Added signups-disabled Supabase local config, owner-only household provisioning, and migrations for households, profiles, devices, and settings with forced RLS and narrow client grants.
- Added a 27-assertion pgTAP isolation/security suite. Execution remains pending because the local Supabase CLI and Docker database runtime are unavailable in this environment.
- Recorded approved product decisions D-013 through D-018 and updated product, database, and architecture requirements.

## 2026-10-01 — Phase 2 Tasks implementation checkpoint
- Replaced the Tasks placeholder with a mobile status board, task create/edit/detail flows, category management, checklist progress, assignees, priorities, due dates and explicit opt-in reminders.
- Added task archive/restore, reusable repetitive-task templates and manual instance creation. Template edits are opt-in, and instances do not copy task images.
- Added an additive Phase 2 migration for household categories, tasks, assignees, ordered checklist items, templates, template children and task image metadata; all tables force RLS and use narrow authenticated grants.
- Added private task image storage policies, Android document-picker image resizing/compression, stable Storage paths and short-lived signed display URLs.
- Added realtime subscriptions and pgTAP household-isolation coverage for task tables, plus typed task mapping tests.
- Hosted deployment and local database execution are pending: this environment has no Supabase CLI, local PostgreSQL tooling or project link.

## 2026-10-01 — Tasks UX revision
- Replaced status-by-status task board navigation with a compact Unified Task List showing all active tasks by default. Added clearable status filters, independent category filters and a separate archived view.
- Added semantic blue/yellow/gray To Do / In Progress / Done indicators with mode-specific Dark and Flower theme tokens.
- Added global Small/Normal/Large font sizing, Normal by default, applied through global Flutter text scaling and persisted using Android app-private preferences.
- Recorded product decisions D-019 and D-020 and aligned the product, architecture and roadmap documents.

## 2026-10-01 — Tasks list usability and save refresh
- Grouped status/category filters in a consistent filter card, placed category actions beside the category heading, and removed the duplicate empty-state New task action.
- Clear active filters after creating a task and refetch after save errors so partially persisted tasks are surfaced.
- Fixed task-card infinite-height rendering reported in Android logs and added a widget regression test.

## 2026-10-02 — Phase 3 Meals & Recipes checkpoint
- Added an upcoming-first Meals screen, separate recipe library, custom/from-recipe meal flows, meal detail ingredient availability, and past/archive views.
- Added recipe CRUD, ordered ingredient quantity/unit fields, archive/restore, and private compressed recipe images using stable Storage paths and temporary signed URLs.
- Added additive RLS migration and 29 pgTAP assertions for tenant isolation, child-row authorization, independent ingredient state, recipe snapshot behavior, and custom meals.
- Added household realtime subscriptions and typed model/repository/widget coverage. Flutter tests and Android debug build pass.
- The linked hosted project reports Phase 1 and Phase 2 applied. Phase 3 is pending: dry-run showed only the additive Phase 3 migration, but automatic approval review rejected the hosted push. Local pgTAP execution also awaits a running Docker engine.

## 2026-10-02 — Recipe image UX revision
- Added recipe image preview, replacement, and removal to recipe creation/editing and to custom meals explicitly saved as reusable recipes.
- Planned meals display their linked recipe's current image without copying media. Recipe-library images are more prominent, with a theme-aware placeholder when no image is available.
- Recipe images remain protected private household media; explicit replacement/removal updates the database path and attempts best-effort deletion of the old object. Added widget coverage for image selection/removal and image display.
- Verified formatting, analysis, all 20 Flutter tests, and the Android debug APK build. Phase 4 remains unstarted.

## 2026-10-02 — Phase 4 Shopping checkpoint
- Replaced the Shopping placeholder with two clear sections: Next 2 meals and General.
- Derived the next two active upcoming meals chronologically and displayed each meal's unchecked ingredient rows independently, preserving exact labels and duplicates. Checking an ingredient updates only its `meal_ingredients` row.
- Added a fast shared General list with exact-text add/edit, check/uncheck, archive/restore, realtime, and collapsed completed items.
- Added additive `shopping_general` migration with forced household RLS, narrow grants, indexes, Realtime publication, and 21 pgTAP security/isolation assertions.
- Added typed model/repository, chronological and ingredient behavior tests, and Shopping interaction tests. Verified formatting, analysis, all 24 Flutter tests, and Android debug build. Local pgTAP could not run because the Docker engine is unavailable. Phase 5 remains unstarted.

## 2026-10-02 — Phase 5 Calendar checkpoint
- Replaced the Calendar placeholder with a compact shared agenda for Today and Upcoming, plus separate Past and Archived views.
- Added event create/edit/detail/archive/restore for title, description, date/time, all-day, location, optional category/color, up to two household assignees, and explicitly enabled reminder timestamps.
- Added recurrence-ready JSON metadata without automatic event generation or notification delivery.
- Added additive event schema with forced household RLS, parent-scoped assignee policies, narrow grants, max-two trigger, indexes, and Realtime publication entries; authored 31 pgTAP assertions.
- Added typed models/repository and agenda/editor/widget coverage. Formatting, analysis, all 29 Flutter tests, and Android debug build passed. Local pgTAP remains unexecuted because Docker is unavailable. Phase 6 remains unstarted.

## 2026-10-02 — Calendar loading diagnosis
- Added a bounded Calendar query wait with a retryable timeout state instead of an indefinite loading indicator.
- Missing Phase 5 tables/relationships now show a clear migration and schema-cache setup hint. Added widget coverage for the missing-schema case.

## 2026-10-02 — Calendar Month UX revision
- Added a Month | Agenda selector with Month as the default. Month uses a compact Monday-first grid, colored event dots capped at three, selected-day chronological cards, and previous/next/Today controls.
- New events opened in Month use the selected date. Agenda, Past, Archived, event details and existing event lifecycle behavior remain available.
- Added widget coverage for navigation, selection, event dots, Today reset, selected-day events/details and new-event date prefill.
