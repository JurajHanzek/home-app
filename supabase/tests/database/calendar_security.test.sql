create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(31);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('70000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'calendar-a@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('70000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'calendar-b@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('80000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'calendar-c@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('80000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'calendar-d@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
select private.provision_household('Calendar household A', '70000000-0000-0000-0000-000000000001', 'Calendar A', 'CA',
  '70000000-0000-0000-0000-000000000002', 'Calendar B', 'CB');
select private.provision_household('Calendar household B', '80000000-0000-0000-0000-000000000001', 'Calendar C', 'CC',
  '80000000-0000-0000-0000-000000000002', 'Calendar D', 'CD');

insert into public.events(id, household_id, title, starts_at, ends_at, recurrence, created_by, updated_by)
values
  ('70000000-0000-0000-0000-000000000010', (select household_id from public.profiles where id='70000000-0000-0000-0000-000000000001'), 'Household A event', now() + interval '1 day', now() + interval '1 day 1 hour', '{"frequency":"weekly"}', '70000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001'),
  ('80000000-0000-0000-0000-000000000010', (select household_id from public.profiles where id='80000000-0000-0000-0000-000000000001'), 'Household B event', now() + interval '1 day', now() + interval '1 day 1 hour', null, '80000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001');
insert into public.event_assignees(household_id, event_id, user_id)
values ((select household_id from public.profiles where id='80000000-0000-0000-0000-000000000001'),
  '80000000-0000-0000-0000-000000000010', '80000000-0000-0000-0000-000000000001');

select ok((select relrowsecurity from pg_class where oid='public.events'::regclass), 'events enables RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.events'::regclass), 'events forces RLS');
select ok((select relrowsecurity from pg_class where oid='public.event_assignees'::regclass), 'event assignees enable RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.event_assignees'::regclass), 'event assignees force RLS');
select ok(not has_table_privilege('anon', 'public.events', 'select'), 'anon cannot read events');
select ok(not has_table_privilege('anon', 'public.event_assignees', 'select'), 'anon cannot read event assignments');
select ok(not has_table_privilege('authenticated', 'public.events', 'delete'), 'members cannot hard-delete events');
select ok(not has_column_privilege('authenticated', 'public.events', 'household_id', 'update'), 'members cannot move events across households');
select ok(not has_column_privilege('authenticated', 'public.event_assignees', 'household_id', 'update'), 'members cannot move assignments across households');
select ok(not has_table_privilege('authenticated', 'public.event_assignees', 'update'), 'assignments are changed through controlled insert/archive flows');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='events'), 1, 'events are in the realtime publication');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='event_assignees'), 1, 'event assignees are in the realtime publication');
select is((select count(*)::integer from pg_class where oid = any(array[
  'public.households'::regclass, 'public.profiles'::regclass, 'public.user_devices'::regclass,
  'public.household_settings'::regclass,
  'public.task_categories'::regclass, 'public.tasks'::regclass, 'public.task_assignees'::regclass,
  'public.task_checklist_items'::regclass, 'public.task_images'::regclass, 'public.task_templates'::regclass,
  'public.task_template_assignees'::regclass, 'public.task_template_checklist_items'::regclass,
  'public.recipes'::regclass, 'public.recipe_ingredients'::regclass, 'public.meals'::regclass,
  'public.meal_ingredients'::regclass, 'public.shopping_general'::regclass
]) and relrowsecurity and relforcerowsecurity), 17, 'all pre-Calendar household tables still force RLS');

set local role authenticated;
select set_config('request.jwt.claim.sub', '70000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.events), 1, 'member sees only household events');
select is((select recurrence from public.events where id='70000000-0000-0000-0000-000000000010'), '{"frequency":"weekly"}'::jsonb, 'recurrence-ready metadata is stored unchanged');
select is((select count(*)::integer from public.event_assignees), 0, 'an event may have no assignees');
select is((with changed as (update public.events set title='Cross-household change', updated_by='70000000-0000-0000-0000-000000000001' where id='80000000-0000-0000-0000-000000000010' returning id) select count(*)::integer from changed), 0, 'member cannot change another household event');
select lives_ok($$insert into public.events(title, starts_at, ends_at, created_by, updated_by)
  values ('New household event', now() + interval '3 days', now() + interval '3 days 1 hour',
  '70000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001')$$,
  'member can create an event for their household');
select throws_ok($$insert into public.events(household_id, title, starts_at, ends_at, created_by, updated_by)
  values ((select household_id from public.profiles where id='80000000-0000-0000-0000-000000000001'), 'Foreign event',
  now() + interval '3 days', now() + interval '3 days 1 hour',
  '70000000-0000-0000-0000-000000000001', '70000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot create an event in another household');
select throws_ok($$insert into public.event_assignees(event_id, user_id)
  values ('70000000-0000-0000-0000-000000000010', '80000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot assign an event to a user outside the household');
select lives_ok($$insert into public.event_assignees(event_id, user_id)
  values ('70000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000001')$$,
  'member can assign an event to themself');
select is((select count(*)::integer from public.event_assignees where event_id='70000000-0000-0000-0000-000000000010'), 1, 'one assignee is supported');
select lives_ok($$insert into public.event_assignees(event_id, user_id)
  values ('70000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000002')$$,
  'member can assign the second household user');
select is((select count(*)::integer from public.event_assignees where event_id='70000000-0000-0000-0000-000000000010'), 2, 'two assignees are supported');
select throws_ok($$insert into public.event_assignees(event_id, user_id)
  values ('70000000-0000-0000-0000-000000000010', '70000000-0000-0000-0000-000000000001')$$,
  '23514', null, 'database enforces the maximum of two assignees');
select lives_ok($$update public.events set starts_at=starts_at + interval '1 hour', updated_by='70000000-0000-0000-0000-000000000001'
  where id='70000000-0000-0000-0000-000000000010'$$, 'member can update own event schedule');
select is((select reminder_at from public.events where id='70000000-0000-0000-0000-000000000010'), null::timestamptz, 'event reminder remains unset unless explicitly enabled');
select lives_ok($$update public.events set archived_at=now(), updated_by='70000000-0000-0000-0000-000000000001'
  where id='70000000-0000-0000-0000-000000000010'$$, 'member can archive own event');
select ok((select archived_at is not null from public.events where id='70000000-0000-0000-0000-000000000010'), 'archive state is recorded');
select lives_ok($$update public.events set archived_at=null, updated_by='70000000-0000-0000-0000-000000000001'
  where id='70000000-0000-0000-0000-000000000010'$$, 'member can restore an archived event');
select ok((select archived_at is null from public.events where id='70000000-0000-0000-0000-000000000010'), 'restored event is active again');
reset role;

select * from extensions.finish();
rollback;
