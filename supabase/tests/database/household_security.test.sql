create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(27);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('10000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   'phase1-a@example.test', 'not-a-login-password', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('10000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
   'phase1-b@example.test', 'not-a-login-password', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('20000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated',
   'phase1-c@example.test', 'not-a-login-password', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('20000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated',
   'phase1-d@example.test', 'not-a-login-password', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

select private.provision_household(
  'Household A',
  '10000000-0000-0000-0000-000000000001', 'User A', 'UA',
  '10000000-0000-0000-0000-000000000002', 'User B', 'UB'
);
select private.provision_household(
  'Household B',
  '20000000-0000-0000-0000-000000000001', 'User C', 'UC',
  '20000000-0000-0000-0000-000000000002', 'User D', 'UD'
);
insert into public.user_devices (user_id, fcm_token, platform)
values ('20000000-0000-0000-0000-000000000001', 'test-device-token-c', 'android');

select ok((select relrowsecurity from pg_class where oid = 'public.households'::regclass), 'households has RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid = 'public.households'::regclass), 'households forces RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profiles has RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profiles forces RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.user_devices'::regclass), 'devices has RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid = 'public.user_devices'::regclass), 'devices forces RLS');
select ok((select relrowsecurity from pg_class where oid = 'public.household_settings'::regclass), 'settings has RLS enabled');
select ok((select relforcerowsecurity from pg_class where oid = 'public.household_settings'::regclass), 'settings forces RLS');
select ok(not has_function_privilege('anon', 'private.provision_household(text,uuid,text,text,uuid,text,text)', 'execute'), 'anon cannot provision households');
select ok(not has_function_privilege('authenticated', 'private.provision_household(text,uuid,text,text,uuid,text,text)', 'execute'), 'authenticated cannot provision households');
select ok(not has_function_privilege('service_role', 'private.provision_household(text,uuid,text,text,uuid,text,text)', 'execute'), 'service_role cannot provision households');
select ok(not has_table_privilege('anon', 'public.profiles', 'select'), 'anon has no profile table grant');
select ok(not has_table_privilege('authenticated', 'public.households', 'insert'), 'members cannot create households');
select ok(not has_table_privilege('authenticated', 'public.profiles', 'insert'), 'members cannot create profiles');
select ok(not has_column_privilege('authenticated', 'public.profiles', 'household_id', 'update'), 'members cannot change profile household');

set local role authenticated;
select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.households), 1, 'member sees only own household');
select is((select count(*)::integer from public.profiles), 2, 'member sees both profiles in own household');
select is((select count(*)::integer from public.household_settings), 1, 'member sees only own household settings');
select is((with changed as (
  update public.profiles set display_name = 'Updated User A'
  where id = '10000000-0000-0000-0000-000000000001' returning id
) select count(*)::integer from changed), 1, 'member can update their own safe profile fields');
select is((with changed as (
  update public.profiles set display_name = 'Attempted edit'
  where id = '20000000-0000-0000-0000-000000000001' returning id
) select count(*)::integer from changed), 0, 'member cannot update another household profile');
select is((with changed as (
  update public.household_settings
  set storage_warning_settings = '{"task_image_count":100,"storage_budget_bytes":5000000000}'::jsonb
  where household_id = (select private.current_household_id()) returning household_id
) select count(*)::integer from changed), 1, 'member can update own household settings');
select is((with changed as (
  update public.households set name = 'Renamed Household A'
  where id = (select private.current_household_id()) returning id
) select count(*)::integer from changed), 1, 'member can rename own household');
select is((with changed as (
  update public.households set name = 'Attempted Household B edit'
  where id = '20000000-0000-0000-0000-000000000001' returning id
) select count(*)::integer from changed), 0, 'member cannot rename another household');
select is((with changed as (
  update public.household_settings
  set storage_warning_settings = '{"task_image_count":1}'::jsonb
  where household_id = '20000000-0000-0000-0000-000000000001' returning household_id
) select count(*)::integer from changed), 0, 'member cannot update another household settings');
select is((select count(*)::integer from public.user_devices), 1, 'member sees only their own device');
select lives_ok($$insert into public.user_devices (user_id, fcm_token, platform)
  values ('10000000-0000-0000-0000-000000000001', 'test-device-token-a', 'android')$$,
  'member can register their own Android device');
select throws_ok($$insert into public.user_devices (user_id, fcm_token, platform)
  values ('20000000-0000-0000-0000-000000000001', 'test-device-token-c', 'android')$$,
  '42501', null, 'member cannot register a device for another user');
reset role;

select * from extensions.finish();
rollback;
