create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(21);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('30000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'tasks-a@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('30000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'tasks-b@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('40000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'tasks-c@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('40000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'tasks-d@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
select private.provision_household('Tasks household A', '30000000-0000-0000-0000-000000000001', 'Task user A', 'TA',
  '30000000-0000-0000-0000-000000000002', 'Task user B', 'TB');
select private.provision_household('Tasks household B', '40000000-0000-0000-0000-000000000001', 'Task user C', 'TC',
  '40000000-0000-0000-0000-000000000002', 'Task user D', 'TD');

insert into public.tasks(id, household_id, title, created_by, updated_by)
values
 ('30000000-0000-0000-0000-000000000010', (select household_id from public.profiles where id='30000000-0000-0000-0000-000000000001'), 'Own task', '30000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000010', (select household_id from public.profiles where id='40000000-0000-0000-0000-000000000001'), 'Other task', '40000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001');
insert into public.task_templates(id, household_id, title, created_by, updated_by)
values
 ('30000000-0000-0000-0000-000000000020', (select household_id from public.profiles where id='30000000-0000-0000-0000-000000000001'), 'Own template', '30000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001'),
 ('40000000-0000-0000-0000-000000000020', (select household_id from public.profiles where id='40000000-0000-0000-0000-000000000001'), 'Other template', '40000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001');
select set_config('test.household_b', (select household_id::text from public.profiles where id='40000000-0000-0000-0000-000000000001'), true);

select is((select count(*)::integer from pg_class where oid = any(array[
  'public.task_categories'::regclass,'public.tasks'::regclass,'public.task_assignees'::regclass,
  'public.task_checklist_items'::regclass,'public.task_images'::regclass,'public.task_templates'::regclass,
  'public.task_template_assignees'::regclass,'public.task_template_checklist_items'::regclass
]) and relrowsecurity and relforcerowsecurity), 8, 'all task tables force RLS');
select ok(not has_table_privilege('anon', 'public.tasks', 'select'), 'anon cannot read tasks');
select ok(not has_table_privilege('anon', 'public.task_templates', 'select'), 'anon cannot read task templates');
select ok(not has_column_privilege('authenticated', 'public.tasks', 'household_id', 'update'), 'members cannot move tasks across households');
select ok(not has_column_privilege('authenticated', 'public.task_categories', 'id', 'update'), 'members cannot change category ids');
select ok(not has_column_privilege('authenticated', 'public.task_images', 'storage_path', 'update'), 'members cannot rewrite stored image paths');
select is((select count(*)::integer from pg_policies where schemaname='storage' and tablename='objects'
  and policyname like 'task_media_%' and roles @> array['authenticated']::name[]),
  4, 'private task storage has select/insert/update/delete member policies');

set local role authenticated;
select set_config('request.jwt.claim.sub', '30000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.task_categories), 2, 'household starts with Outdoor and Indoor categories');
select is((select count(*)::integer from public.tasks), 1, 'member sees only household tasks');
select is((select count(*)::integer from public.task_templates), 1, 'member sees only household templates');
select is((with changed as (update public.tasks set title='Cross-household edit', updated_by='30000000-0000-0000-0000-000000000001'
  where id='40000000-0000-0000-0000-000000000010' returning id) select count(*)::integer from changed), 0, 'member cannot edit another household task');
select throws_ok($$insert into public.task_categories(household_id,name)
  values (current_setting('test.household_b')::uuid,'Foreign category')$$,
  '42501', null, 'member cannot create category for another household');
select throws_ok($$insert into public.tasks(household_id,title,created_by,updated_by)
  values (current_setting('test.household_b')::uuid, 'Cross household',
  '30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot insert a task into another household');
select lives_ok($$insert into public.tasks(title,created_by,updated_by)
  values ('Member-created task','30000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001')$$,
  'member can create task in own household');
select lives_ok($$insert into public.task_checklist_items(task_id,label,sort_order)
  values ('30000000-0000-0000-0000-000000000010','Own checklist item',0)$$,
  'member can create child row for own task');
select throws_ok($$insert into public.task_checklist_items(household_id,task_id,label)
  values (current_setting('test.household_b')::uuid,
  '40000000-0000-0000-0000-000000000010','Cross-household checklist')$$,
  '42501', null, 'member cannot create child row for another household task');
select lives_ok($$insert into public.task_assignees(task_id,user_id)
  values ('30000000-0000-0000-0000-000000000010','30000000-0000-0000-0000-000000000002')$$,
  'member can assign household partner');
select throws_ok($$insert into public.task_assignees(household_id,task_id,user_id)
  values (current_setting('test.household_b')::uuid,
  '40000000-0000-0000-0000-000000000010','40000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot assign a user from another household');
select throws_ok($$insert into public.task_images(household_id,task_id,storage_path,size_bytes,created_by)
  values (current_setting('test.household_b')::uuid,
  '40000000-0000-0000-0000-000000000010',current_setting('test.household_b') || '/tasks/40000000-0000-0000-0000-000000000010/file.jpg',100,'30000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot add image metadata under another household task');
select throws_ok($$insert into public.task_template_checklist_items(household_id,template_id,label)
  values (current_setting('test.household_b')::uuid,'40000000-0000-0000-0000-000000000020','Foreign template item')$$,
  '42501', null, 'member cannot add child row under another household template');
select lives_ok($$update public.tasks set status='done', updated_by='30000000-0000-0000-0000-000000000001'
  where id='30000000-0000-0000-0000-000000000010'$$, 'task can transition to Done without auto-archiving');
reset role;

select * from extensions.finish();
rollback;
