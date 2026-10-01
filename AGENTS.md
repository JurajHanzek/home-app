# HomeHub — Agent Instructions

## Mission
Build HomeHub v0.0.1 as a private Android-only household app for two users.

`docs/PRODUCT_SPEC.md` is the product source of truth. Read all files in `docs/` before substantial work.

## Rules
- Flutter/Dart + Material 3, Android only.
- Supabase: Auth, Postgres, RLS, Realtime, Storage, Edge Functions where needed.
- Firebase Cloud Messaging only for Android push delivery; no Firestore/Firebase Auth/Firebase Storage.
- No public signup UI.
- Never expose service-role/database/FCM server secrets in Flutter.
- Enforce household isolation with RLS, not client filtering.
- Prefer simple typed maintainable code; feature-oriented structure; avoid god services/widgets.
- Keep migrations reproducible and the app runnable at phase boundaries.
- v0.0.1 is online-required. Concurrent edits are last-write-wins.
- Prefer archive/restore over destructive deletion.
- Do not silently change product requirements or implement deferred features.

## Before work
Read PRODUCT_SPEC, ARCHITECTURE, DATABASE, DECISIONS and the current ROADMAP phase; inspect existing code/config before changing it.

## Quality gate
After meaningful changes run as applicable:
`dart format .`, `flutter analyze`, relevant tests and database/RLS validation. Fix errors introduced by the change.

## Documentation
At each phase checkpoint update ROADMAP, CHANGELOG and REVIEW. Update architecture/database docs if legitimately changed. Record approved deviations in DECISIONS.

## Autonomy
Proceed autonomously when the specification determines behavior. For minor implementation choices choose the simplest maintainable option and document it.

Stop for human review only when:
- two interpretations materially change visible behavior;
- security would be weakened;
- a destructive migration/data-loss risk exists;
- a new paid/external service is required;
- implementation conflicts with the product specification.

Implement phases in ROADMAP order. End each phase at a clean Git-review point.
