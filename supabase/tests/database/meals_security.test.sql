create extension if not exists pgtap with schema extensions;

begin;
select extensions.plan(29);

insert into auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
values
  ('50000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'meals-a@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('50000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'meals-b@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('60000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'meals-c@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('60000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'meals-d@example.test', 'x', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());
select private.provision_household('Meals household A', '50000000-0000-0000-0000-000000000001', 'Meals user A', 'MA',
  '50000000-0000-0000-0000-000000000002', 'Meals user B', 'MB');
select private.provision_household('Meals household B', '60000000-0000-0000-0000-000000000001', 'Meals user C', 'MC',
  '60000000-0000-0000-0000-000000000002', 'Meals user D', 'MD');
select set_config('test.meals_household_a', (select household_id::text from public.profiles where id='50000000-0000-0000-0000-000000000001'), true);
select set_config('test.meals_household_b', (select household_id::text from public.profiles where id='60000000-0000-0000-0000-000000000001'), true);

insert into public.recipes(id, household_id, name, created_by, updated_by)
values
 ('50000000-0000-0000-0000-000000000010', current_setting('test.meals_household_a')::uuid, 'Soup', '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001'),
 ('60000000-0000-0000-0000-000000000010', current_setting('test.meals_household_b')::uuid, 'Other recipe', '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001');
insert into public.recipe_ingredients(id, household_id, recipe_id, label, sort_order)
values
 ('50000000-0000-0000-0000-000000000011', current_setting('test.meals_household_a')::uuid, '50000000-0000-0000-0000-000000000010', 'Rice', 0),
 ('50000000-0000-0000-0000-000000000012', current_setting('test.meals_household_a')::uuid, '50000000-0000-0000-0000-000000000010', 'crveni luk', 1),
 ('60000000-0000-0000-0000-000000000011', current_setting('test.meals_household_b')::uuid, '60000000-0000-0000-0000-000000000010', 'Foreign ingredient', 0);
insert into public.meals(id, household_id, planned_date, planned_time, name, recipe_id, created_by, updated_by)
values
 ('50000000-0000-0000-0000-000000000020', current_setting('test.meals_household_a')::uuid, current_date + 1, '18:00', 'Soup', '50000000-0000-0000-0000-000000000010', '50000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001'),
 ('60000000-0000-0000-0000-000000000020', current_setting('test.meals_household_b')::uuid, current_date + 1, '18:00', 'Other meal', '60000000-0000-0000-0000-000000000010', '60000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001');
insert into public.meal_ingredients(id, household_id, meal_id, label, sort_order)
values
 ('50000000-0000-0000-0000-000000000021', current_setting('test.meals_household_a')::uuid, '50000000-0000-0000-0000-000000000020', 'Rice', 0),
 ('60000000-0000-0000-0000-000000000021', current_setting('test.meals_household_b')::uuid, '60000000-0000-0000-0000-000000000020', 'Foreign ingredient', 0);

select is((select count(*)::integer from pg_class where oid = any(array[
  'public.recipes'::regclass, 'public.recipe_ingredients'::regclass,
  'public.meals'::regclass, 'public.meal_ingredients'::regclass
]) and relrowsecurity and relforcerowsecurity), 4, 'all meals and recipes tables force RLS');
select ok(not has_table_privilege('anon', 'public.recipes', 'select'), 'anon cannot read recipes');
select ok(not has_table_privilege('anon', 'public.meals', 'select'), 'anon cannot read meals');
select ok(not has_column_privilege('authenticated', 'public.recipes', 'household_id', 'update'), 'members cannot move recipes across households');
select ok(not has_column_privilege('authenticated', 'public.meals', 'household_id', 'update'), 'members cannot move meals across households');
select ok(not has_column_privilege('authenticated', 'public.recipe_ingredients', 'id', 'update'), 'members cannot change recipe ingredient ids');
select ok(not has_column_privilege('authenticated', 'public.meal_ingredients', 'household_id', 'update'), 'members cannot move meal ingredients across households');
select ok(has_function_privilege('authenticated', 'public.create_planned_meal(text,date,time,text,integer,text,uuid,jsonb)', 'execute'), 'members can call the caller-authorized meal creation function');
select ok(not has_function_privilege('anon', 'public.create_planned_meal(text,date,time,text,integer,text,uuid,jsonb)', 'execute'), 'anon cannot call the meal creation function');
select is((select count(*)::integer from pg_policies where schemaname='storage' and tablename='objects'
  and policyname like 'recipe_media_%' and roles @> array['authenticated']::name[]),
  4, 'private recipe storage has select/insert/update/delete policies');

set local role authenticated;
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', true);
select is((select count(*)::integer from public.recipes), 1, 'member sees only household recipes');
select is((select count(*)::integer from public.recipe_ingredients), 2, 'member sees own recipe ingredients only');
select is((select count(*)::integer from public.meals), 1, 'member sees only household meals');
select is((select count(*)::integer from public.meal_ingredients), 1, 'member sees own meal ingredients only');
select is((with changed as (update public.meal_ingredients set have=true
  where id='60000000-0000-0000-0000-000000000021' returning id) select count(*)::integer from changed), 0,
  'member cannot change another household meal ingredient');
select throws_ok($$insert into public.recipes(household_id,name,created_by,updated_by)
  values(current_setting('test.meals_household_b')::uuid,'Foreign recipe',
    '50000000-0000-0000-0000-000000000001','50000000-0000-0000-0000-000000000001')$$,
  '42501', null, 'member cannot create a recipe for another household');
select throws_ok($$insert into public.recipe_ingredients(household_id,recipe_id,label)
  values(current_setting('test.meals_household_b')::uuid,
    '60000000-0000-0000-0000-000000000010','Foreign child')$$,
  '42501', null, 'member cannot add a child under another household recipe');
select throws_ok($$insert into public.meal_ingredients(household_id,meal_id,label)
  values(current_setting('test.meals_household_b')::uuid,
    '60000000-0000-0000-0000-000000000020','Foreign child')$$,
  '42501', null, 'member cannot add a child under another household meal');
select throws_ok($$select public.create_planned_meal('Foreign',current_date,null,'dinner',2,'',
  '60000000-0000-0000-0000-000000000010','[]'::jsonb)$$,
  '42501', null, 'meal creation cannot read a recipe from another household');

select set_config('test.meal_one', public.create_planned_meal('Soup A', current_date+2, '18:00', 'dinner', 2, '',
  '50000000-0000-0000-0000-000000000010', '[]'::jsonb)::text, true);
select set_config('test.meal_two', public.create_planned_meal('Soup B', current_date+3, null, 'lunch', 3, '',
  '50000000-0000-0000-0000-000000000010', '[]'::jsonb)::text, true);
select is((select count(*)::integer from public.meals where id in
  (current_setting('test.meal_one')::uuid,current_setting('test.meal_two')::uuid)), 2,
  'two planned meals are independently created from one recipe');
select is((select count(*)::integer from public.meal_ingredients where meal_id in
  (current_setting('test.meal_one')::uuid,current_setting('test.meal_two')::uuid)
  and label in ('Rice','crveni luk') and not have), 4,
  'each meal gets an unchanged, unchecked ingredient snapshot');
select lives_ok($$update public.meal_ingredients set have=true
  where meal_id=current_setting('test.meal_one')::uuid and label='Rice'$$,
  'member can set availability for an ingredient in one meal');
select is((select have from public.meal_ingredients where meal_id=current_setting('test.meal_one')::uuid and label='Rice'), true,
  'availability changes for the selected meal');
select is((select have from public.meal_ingredients where meal_id=current_setting('test.meal_two')::uuid and label='Rice'), false,
  'the same ingredient in another meal is unchanged');
select lives_ok($$update public.recipe_ingredients set label='Brown rice'
  where id='50000000-0000-0000-0000-000000000011'$$,
  'member can edit a reusable recipe ingredient');
select is((select label from public.meal_ingredients where meal_id=current_setting('test.meal_one')::uuid and sort_order=0), 'Rice',
  'editing a recipe does not rewrite a planned meal ingredient snapshot');
select set_config('test.custom_meal', public.create_planned_meal('Custom dinner', current_date+4, null, null, 4,
  'No recipe needed', null, '[{"label":"luk","quantity":"2","unit":"pcs"}]'::jsonb)::text, true);
select is((select recipe_id from public.meals where id=current_setting('test.custom_meal')::uuid), null::uuid,
  'custom meal does not require a recipe');
select is((select label from public.meal_ingredients where meal_id=current_setting('test.custom_meal')::uuid), 'luk',
  'custom meal preserves its original ingredient string');
select is((select quantity || ' ' || unit from public.meal_ingredients where meal_id=current_setting('test.custom_meal')::uuid), '2 pcs',
  'custom meal supports ingredient quantity and unit');
reset role;

select * from extensions.finish();
rollback;
