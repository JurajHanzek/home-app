create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(49);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('90000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'expense-a@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('90000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'expense-b@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('a0000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'expense-c@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('a0000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'expense-d@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
select private.provision_household('Expense household A', '90000000-0000-0000-0000-000000000001', 'Expense A', 'EA',
  '90000000-0000-0000-0000-000000000002', 'Expense B', 'EB');
select private.provision_household('Expense household B', 'a0000000-0000-0000-0000-000000000001', 'Expense C', 'EC',
  'a0000000-0000-0000-0000-000000000002', 'Expense D', 'ED');

insert into public.expenses(
  id, household_id, amount, title, category_id, paid_by, shared, expense_date,
  created_by, updated_by
)
values
  ('90000000-0000-0000-0000-000000000010',
    (select household_id from public.profiles where id='90000000-0000-0000-0000-000000000001'),
    12.50, 'Household A coffee',
    (select id from public.expense_categories where household_id=(select household_id from public.profiles where id='90000000-0000-0000-0000-000000000001') and name='Groceries'),
    '90000000-0000-0000-0000-000000000001', true, current_date,
    '90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001'),
  ('a0000000-0000-0000-0000-000000000010',
    (select household_id from public.profiles where id='a0000000-0000-0000-0000-000000000001'),
    40.00, 'Household B item',
    (select id from public.expense_categories where household_id=(select household_id from public.profiles where id='a0000000-0000-0000-0000-000000000001') and name='Other'),
    'a0000000-0000-0000-0000-000000000001', false, current_date,
    'a0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001');

select ok((select relrowsecurity from pg_class where oid='public.expense_categories'::regclass), 'categories enable RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.expense_categories'::regclass), 'categories force RLS');
select ok((select relrowsecurity from pg_class where oid='public.expenses'::regclass), 'expenses enable RLS');
select ok((select relforcerowsecurity from pg_class where oid='public.expenses'::regclass), 'expenses force RLS');
select ok(not has_table_privilege('anon', 'public.expense_categories', 'select'), 'anon cannot read categories');
select ok(not has_table_privilege('anon', 'public.expenses', 'select'), 'anon cannot read expenses');
select ok(not has_table_privilege('authenticated', 'public.expenses', 'delete'), 'members cannot hard-delete expenses');
select ok(not has_column_privilege('authenticated', 'public.expenses', 'household_id', 'update'), 'members cannot move expenses');
select ok(not has_column_privilege('authenticated', 'public.expense_categories', 'household_id', 'update'), 'members cannot move categories');
select is((select public from storage.buckets where id='household-media'), false, 'household media bucket remains private');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='expense_categories'), 1, 'categories are in realtime publication');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='expenses'), 1, 'expenses are in realtime publication');
select is((select count(*)::integer from pg_class where oid = any(array[
  'public.households'::regclass, 'public.profiles'::regclass, 'public.user_devices'::regclass,
  'public.household_settings'::regclass,
  'public.task_categories'::regclass, 'public.tasks'::regclass, 'public.task_assignees'::regclass,
  'public.task_checklist_items'::regclass, 'public.task_images'::regclass, 'public.task_templates'::regclass,
  'public.task_template_assignees'::regclass, 'public.task_template_checklist_items'::regclass,
  'public.recipes'::regclass, 'public.recipe_ingredients'::regclass, 'public.meals'::regclass,
  'public.meal_ingredients'::regclass, 'public.shopping_general'::regclass,
  'public.events'::regclass, 'public.event_assignees'::regclass
]) and relrowsecurity and relforcerowsecurity), 19, 'all earlier household tables still force RLS');
select is((select count(*)::integer from pg_policies where schemaname='storage' and tablename='objects' and policyname='expense_receipt_read'), 1, 'receipt reads have a private storage policy');

-- Preserve foreign IDs before switching into household-limited visibility.
select set_config('test.foreign_household', (select household_id::text from public.profiles where id='a0000000-0000-0000-0000-000000000001'), true);
select set_config('test.foreign_category', (select id::text from public.expense_categories where household_id=current_setting('test.foreign_household')::uuid and name='Other'), true);
select set_config('test.own_household', (select household_id::text from public.profiles where id='90000000-0000-0000-0000-000000000001'), true);
insert into storage.objects(bucket_id, name) values ('household-media', current_setting('test.foreign_household') || '/expenses/a0000000-0000-0000-0000-000000000010/11111111-1111-4111-8111-111111111111.jpg');

set local role authenticated;
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.expense_categories), 7, 'household has all seven initial categories');
select is((select count(*)::integer from public.expenses), 1, 'member sees only household expenses');
select is((select currency from public.expenses where id='90000000-0000-0000-0000-000000000010'), 'EUR', 'initial currency is EUR');
select is((select receipt_path from public.expenses where id='90000000-0000-0000-0000-000000000010'), null::text, 'receipt is optional');
select is((with changed as (update public.expenses set title='Foreign edit', updated_by='90000000-0000-0000-0000-000000000001' where id='a0000000-0000-0000-0000-000000000010' returning id) select count(*)::integer from changed), 0, 'member cannot edit another household expense');
select lives_ok($$insert into public.expenses(amount, title, category_id, paid_by, expense_date, created_by, updated_by)
  values (8.25, 'Allowed expense', (select id from public.expense_categories where name='Home'),
  '90000000-0000-0000-0000-000000000001', current_date,
  '90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001')$$,
  'member can create a household expense');
select throws_ok($$insert into public.expenses(household_id, amount, title, category_id, paid_by, expense_date, created_by, updated_by)
  values (current_setting('test.foreign_household')::uuid,
  9.50, 'Foreign expense', gen_random_uuid(), '90000000-0000-0000-0000-000000000001', current_date,
  '90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot create an expense in another household');
select lives_ok($$insert into public.expense_categories(name, created_by, updated_by)
  values ('Pets', '90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001')$$,
  'members can add categories');
select throws_ok($$insert into public.expense_categories(name, created_by, updated_by)
  values ('groceries', '90000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001')$$,
  '23505', null, 'category names are unique without case sensitivity per household');
select lives_ok($$update public.expense_categories set name='Pets and care', color='#68794D', updated_by='90000000-0000-0000-0000-000000000001'
  where name='Pets'$$, 'member can edit a category');
select lives_ok($$update public.expense_categories set archived_at=now(), updated_by='90000000-0000-0000-0000-000000000001'
  where name='Pets and care'$$, 'member can archive a category');
select ok((select archived_at is not null from public.expense_categories where name='Pets and care'), 'category archive state is recorded');
select lives_ok($$update public.expense_categories set archived_at=null, updated_by='90000000-0000-0000-0000-000000000001'
  where name='Pets and care'$$, 'member can restore a category');
select ok((select archived_at is null from public.expense_categories where name='Pets and care'), 'category is restored');
select lives_ok($$update public.expenses set amount=13.00, updated_by='90000000-0000-0000-0000-000000000001'
  where id='90000000-0000-0000-0000-000000000010'$$, 'member can update own expense');
select lives_ok($$update public.expenses set archived_at=now(), updated_by='90000000-0000-0000-0000-000000000001'
  where id='90000000-0000-0000-0000-000000000010'$$, 'member can archive own expense');
select ok((select archived_at is not null from public.expenses where id='90000000-0000-0000-0000-000000000010'), 'expense archive state is recorded');
select lives_ok($$update public.expenses set archived_at=null, updated_by='90000000-0000-0000-0000-000000000001'
  where id='90000000-0000-0000-0000-000000000010'$$, 'member can restore own expense');
select ok((select archived_at is null from public.expenses where id='90000000-0000-0000-0000-000000000010'), 'expense is restored');
select throws_ok($$update public.expenses set paid_by='a0000000-0000-0000-0000-000000000001', updated_by=auth.uid()
  where id='90000000-0000-0000-0000-000000000010'$$, '23503', null, 'cross-household paid_by is rejected');
select throws_ok($$update public.expenses set category_id=current_setting('test.foreign_category')::uuid, updated_by=auth.uid()
  where id='90000000-0000-0000-0000-000000000010'$$, '23503', null, 'cross-household category is rejected');
select lives_ok($$update public.expenses set paid_by='90000000-0000-0000-0000-000000000002', shared=false, updated_by=auth.uid()
  where id='90000000-0000-0000-0000-000000000010'$$, 'other household member can be payer independently of creator');
select is((select created_by::text from public.expenses where id='90000000-0000-0000-0000-000000000010'), '90000000-0000-0000-0000-000000000001', 'changing payer preserves creator');
select lives_ok($$update public.expense_categories set archived_at=now(), updated_by=auth.uid() where name='Groceries'$$, 'referenced category can be archived');
select is((select count(*)::integer from public.expenses where id='90000000-0000-0000-0000-000000000010'), 1, 'archiving a category preserves historical expense');
select lives_ok($$insert into storage.objects(bucket_id, name) values ('household-media', current_setting('test.own_household') || '/expenses/90000000-0000-0000-0000-000000000010/11111111-1111-4111-8111-111111111111.jpg')$$, 'member can upload receipt for own household expense');
select is((select count(*)::integer from storage.objects where bucket_id='household-media' and name like '%/expenses/%'), 1, 'foreign household receipt is hidden');
select throws_ok($$insert into storage.objects(bucket_id, name) values ('household-media', current_setting('test.foreign_household') || '/expenses/a0000000-0000-0000-0000-000000000010/22222222-2222-4222-8222-222222222222.jpg')$$, '42501', null, 'cannot upload foreign household receipt');
select throws_ok($$insert into storage.objects(bucket_id, name) values ('household-media', current_setting('test.own_household') || '/expenses/a0000000-0000-0000-0000-000000000010/22222222-2222-4222-8222-222222222222.jpg')$$, '42501', null, 'own folder cannot bypass foreign expense ownership');
select throws_ok($$update public.expenses set receipt_path=current_setting('test.foreign_household') || '/expenses/a0000000-0000-0000-0000-000000000010/11111111-1111-4111-8111-111111111111.jpg', updated_by=auth.uid() where id='90000000-0000-0000-0000-000000000010'$$, '23514', null, 'receipt path must belong to its expense');
select lives_ok($$update public.expenses set receipt_path=current_setting('test.own_household') || '/expenses/90000000-0000-0000-0000-000000000010/11111111-1111-4111-8111-111111111111.jpg', updated_by=auth.uid() where id='90000000-0000-0000-0000-000000000010'$$, 'stable receipt path can be attached');
select ok(not has_column_privilege('authenticated', 'public.expenses', 'created_by', 'update'), 'creator is immutable for clients');
select ok(not has_column_privilege('authenticated', 'public.expenses', 'created_at', 'insert'), 'clients cannot forge creation timestamps');
select set_config('request.jwt.claim.sub', '90000000-0000-0000-0000-000000000002', true);
select is((select count(*)::integer from public.expenses), 2, 'the second household user sees the shared ledger');
select set_config('request.jwt.claim.sub', 'a0000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.expenses), 1, 'the other household cannot read this ledger');
reset role;

select * from extensions.finish();
rollback;
