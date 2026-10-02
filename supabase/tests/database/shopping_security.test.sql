create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(21);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('50000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'shopping-a@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('50000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'shopping-b@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('60000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'shopping-c@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('60000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'shopping-d@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
select private.provision_household('Shopping household A', '50000000-0000-0000-0000-000000000001', 'Shop A', 'SA',
  '50000000-0000-0000-0000-000000000002', 'Shop B', 'SB');
select private.provision_household('Shopping household B', '60000000-0000-0000-0000-000000000001', 'Shop C', 'SC',
  '60000000-0000-0000-0000-000000000002', 'Shop D', 'SD');

insert into public.shopping_general(id, household_id, label, created_by, updated_by)
values
  ('50000000-0000-0000-0000-000000000010', (select household_id from public.profiles where id='50000000-0000-0000-0000-000000000001'), 'Bread', '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001'),
  ('60000000-0000-0000-0000-000000000010', (select household_id from public.profiles where id='60000000-0000-0000-0000-000000000001'), 'Other household', '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001');
insert into public.meals(id, household_id, planned_date, planned_time, name, created_by, updated_by)
values
  ('50000000-0000-0000-0000-000000000020', (select household_id from public.profiles where id='50000000-0000-0000-0000-000000000001'), current_date + 1, null, 'Meal A one', '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001'),
  ('50000000-0000-0000-0000-000000000021', (select household_id from public.profiles where id='50000000-0000-0000-0000-000000000001'), current_date + 2, null, 'Meal A two', '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001'),
  ('60000000-0000-0000-0000-000000000020', (select household_id from public.profiles where id='60000000-0000-0000-0000-000000000001'), current_date + 1, null, 'Meal B', '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001');
insert into public.meal_ingredients(id, household_id, meal_id, label, sort_order)
values
  ('50000000-0000-0000-0000-000000000030', (select household_id from public.profiles where id='50000000-0000-0000-0000-000000000001'), '50000000-0000-0000-0000-000000000020', 'rice', 0),
  ('50000000-0000-0000-0000-000000000031', (select household_id from public.profiles where id='50000000-0000-0000-0000-000000000001'), '50000000-0000-0000-0000-000000000021', 'rice', 0),
  ('60000000-0000-0000-0000-000000000030', (select household_id from public.profiles where id='60000000-0000-0000-0000-000000000001'), '60000000-0000-0000-0000-000000000020', 'rice', 0);

select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.shopping_general'::regclass), 'General shopping forces RLS');
select ok(not has_table_privilege('anon', 'public.shopping_general', 'select'), 'anon cannot read General shopping');
select ok(not has_table_privilege('authenticated', 'public.shopping_general', 'delete'), 'members cannot hard-delete list items');
select ok(not has_column_privilege('authenticated', 'public.shopping_general', 'household_id', 'update'), 'members cannot move list items between households');
select is((select count(*)::integer from pg_class where oid = any(array[
  'public.households'::regclass, 'public.profiles'::regclass, 'public.user_devices'::regclass,
  'public.household_settings'::regclass,
  'public.task_categories'::regclass, 'public.tasks'::regclass, 'public.task_assignees'::regclass,
  'public.task_checklist_items'::regclass, 'public.task_images'::regclass, 'public.task_templates'::regclass,
  'public.task_template_assignees'::regclass, 'public.task_template_checklist_items'::regclass,
  'public.recipes'::regclass, 'public.recipe_ingredients'::regclass, 'public.meals'::regclass,
  'public.meal_ingredients'::regclass
]) and relrowsecurity and relforcerowsecurity), 16, 'existing Phase 1, 2, and 3 household tables still force RLS');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='shopping_general'), 1, 'General shopping is in the realtime publication');

set local role authenticated;
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.shopping_general), 1, 'member sees only own household list items');
select is((select count(*)::integer from public.meals), 2, 'meal-derived shopping sees only household meals');
select is((select count(*)::integer from public.meal_ingredients), 2, 'meal-derived shopping sees only household ingredients');
select is((with changed as (update public.shopping_general set label='Cross-household edit', updated_by='50000000-0000-0000-0000-000000000001' where id='60000000-0000-0000-0000-000000000010' returning id) select count(*)::integer from changed), 0, 'member cannot update another household list item');
select throws_ok($$insert into public.shopping_general(household_id, label, created_by, updated_by)
  values ((select household_id from public.profiles where id='60000000-0000-0000-0000-000000000001'), 'Foreign',
  '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot create a list item in another household');
select lives_ok($$insert into public.shopping_general(label, created_by, updated_by)
  values (' rice ', '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001')$$,
  'member can add an item while preserving entered whitespace');
select lives_ok($$update public.shopping_general set is_done=true, updated_by='50000000-0000-0000-0000-000000000001'
  where id='50000000-0000-0000-0000-000000000010'$$, 'member can check a household list item');
select is((select is_done from public.shopping_general where id='50000000-0000-0000-0000-000000000010'), true, 'General checked state persists independently');
select is((select label from public.shopping_general where label=' rice '), ' rice ', 'General labels are not normalized');
select is((select count(*)::integer from public.meal_ingredients where label='rice'), 2, 'identical meal ingredients remain separate rows');
select is((with changed as (update public.meal_ingredients set have=true where id='60000000-0000-0000-0000-000000000030' returning id) select count(*)::integer from changed), 0, 'member cannot change another household meal ingredient');
select is((with changed as (update public.meal_ingredients set have=true where id='50000000-0000-0000-0000-000000000030' returning id) select count(*)::integer from changed), 1, 'checking an ingredient updates only its selected row');
select is((select have from public.meal_ingredients where id='50000000-0000-0000-0000-000000000030'), true, 'selected meal ingredient is checked');
select is((select have from public.meal_ingredients where id='50000000-0000-0000-0000-000000000031'), false, 'same label in another meal stays unchanged');
select is((select is_done from public.shopping_general where id='50000000-0000-0000-0000-000000000010'), true, 'checking a meal ingredient does not alter General shopping');
reset role;

select * from extensions.finish();
rollback;
