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

Append future durable decisions; do not rewrite history.
