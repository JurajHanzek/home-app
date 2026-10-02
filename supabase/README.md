# Supabase setup and deployment

## Local database

Start Docker Desktop's Linux engine, then run the repository-local Supabase CLI from the project root:

```powershell
.\node_modules\.bin\supabase.cmd start
.\node_modules\.bin\supabase.cmd db reset
.\node_modules\.bin\supabase.cmd test db
```

`db reset` recreates the local database from `supabase/migrations`. The pgTAP
test creates disposable auth users inside a transaction and rolls all test data
back. Do not use a service-role key in Flutter or commit production credentials.

## Private household provisioning

The app has no signup screen, and local Auth email signups are disabled in
`config.toml`. For a hosted project, also disable signups in the Supabase Auth
settings. A trusted project administrator creates/invites the two Auth users
through the Supabase Dashboard, then runs the following from the SQL Editor as
the database owner. Replace the UUIDs with the users' Auth IDs:

```sql
select private.provision_household(
  'Home',
  '00000000-0000-0000-0000-000000000001', 'User A', 'UA',
  '00000000-0000-0000-0000-000000000002', 'User B', 'UB'
);
```

This private function creates the household, both profiles, and household
settings atomically. It is not executable by `anon`, `authenticated`, or
`service_role`, and its schema is not exposed through the Data API. No passwords
or service keys are involved in provisioning. Do not create profiles with
client-side SQL or grant the app a privileged key.

After provisioning, run the app with the project URL and publishable key:

```powershell
flutter run --dart-define=SUPABASE_URL=https://your-project.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

## Applying additive feature migrations to the hosted project

This workspace contains the Supabase CLI at `node_modules/.bin/supabase.cmd` and is linked to the hosted project. Check the remote migration history before deployment:

```powershell
.\node_modules\.bin\supabase.cmd migration list
.\node_modules\.bin\supabase.cmd db push --dry-run
```

When the dry run lists only the reviewed additive feature migrations, deploy with:

```powershell
.\node_modules\.bin\supabase.cmd db push
```

The Phase 3 migration creates new recipe/meal tables, indexes, RLS policies, recipe Storage policies, and a caller-authorized meal creation function. It does not modify or delete existing household, Auth, or task data. The last confirmed remote history in the Phase 3 checkpoint showed Phase 1 and Phase 2 applied and Phase 3 pending. The product owner has said they will apply Phase 3 manually; this workspace has not received confirmation that deployment completed.

The Phase 4 migration `20261002140000_phase4_shopping.sql` adds only `shopping_general`, its indexes, forced RLS policies, narrow grants, updated-at trigger, and Realtime publication entry. It does not modify or delete existing household, Auth, task, recipe, meal, or ingredient data. Apply Phase 3 first, then review the dry run for Phase 4 before deploying. If both migrations remain pending, the dry run will list both; inspect each migration before using `db push`. No hosted Phase 4 migration has been applied from this workspace. Alternatively, the project owner can run the full migration SQL in order through the hosted SQL Editor.

The Phase 5 migration `20261002160000_phase5_calendar.sql` adds only `events`, `event_assignees`, their indexes/trigger, forced RLS policies, narrow grants, the two-assignee enforcement trigger, and Realtime publication entries. It does not alter existing tables or rows. Review the linked migration history and dry run, then apply pending feature migrations in timestamp order. The owner may run their full SQL contents in order through the hosted SQL Editor. This workspace did not deploy Phase 5.

The Phase 6 migration `20261002180000_phase6_expenses.sql` continues the existing additive Expenses implementation. It creates categories/expenses with forced household RLS, narrow column grants, same-household category/payer foreign keys, seven seeded categories, realtime entries and parent-authorized private receipt Storage policies. It preserves earlier security policies and does not delete existing data. The owner handles hosted deployment manually, in timestamp order after checking pending migrations. Phase 6 was not deployed by this agent. Its 49-assertion security suite is authored but has not run because the local Docker engine is unavailable.

Run the database/pgTAP suites with the local Supabase stack after Docker Desktop's Linux engine is running:

Phase 7 adds `20261003120000_phase7_home_activity_search.sql` after all Phase 1–6 prerequisites. It creates forced-RLS, client-read-only Activity, trusted parent-mutation logging triggers, Realtime publication and the security-invoker Search/Archive RPC. Review and manually apply it using the owner workflow above. Activity starts at deployment; no historical actions are backfilled. Search, Archive and Activity require this migration and a current PostgREST schema cache. Its 42-assertion `phase7_security.test.sql` is authored but unexecuted. No Phase 7 hosted deployment or database reset was run by this agent.

Use `test db` against the local stack when available. The reset command below is an optional destructive local rebuild, not a Phase 7 instruction and never a hosted operation.

```powershell
.\node_modules\.bin\supabase.cmd start
.\node_modules\.bin\supabase.cmd db reset
.\node_modules\.bin\supabase.cmd test db
```

Do not rerun the owner-only Phase 1 provisioning function for users who already have profiles.
