create extension if not exists pgtap with schema extensions;
begin;
select extensions.plan(42);

insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select id::uuid,'authenticated','authenticated',email,'x',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()
from (values
 ('91000000-0000-0000-0000-000000000001','phase7-a@example.test'),
 ('91000000-0000-0000-0000-000000000002','phase7-b@example.test'),
 ('92000000-0000-0000-0000-000000000001','phase7-c@example.test'),
 ('92000000-0000-0000-0000-000000000002','phase7-d@example.test')) as u(id,email);
select private.provision_household('Phase7 A','91000000-0000-0000-0000-000000000001','Alice','A','91000000-0000-0000-0000-000000000002','Bob','B');
select private.provision_household('Phase7 B','92000000-0000-0000-0000-000000000001','Carol','C','92000000-0000-0000-0000-000000000002','Dan','D');

select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid='public.activity_log'::regclass),'activity forces RLS');
select ok(has_table_privilege('authenticated','public.activity_log','select'),'members can read activity');
select ok(not has_table_privilege('authenticated','public.activity_log','insert'),'no client activity insert');
select ok(not has_table_privilege('authenticated','public.activity_log','update'),'no client activity update');
select ok(not has_table_privilege('authenticated','public.activity_log','delete'),'no client activity delete');
select ok(not has_table_privilege('anon','public.activity_log','select'),'no anonymous activity');
select ok(not has_function_privilege('authenticated','private.log_household_activity()','execute'),'trigger function cannot be called by clients');
select ok(not has_function_privilege('anon','public.search_household_entities(text,boolean,integer)','execute'),'no anonymous search');
select ok((select not prosecdef from pg_proc where oid='public.search_household_entities(text,boolean,integer)'::regprocedure),'search is security invoker');
select is((select count(*)::integer from pg_publication_tables where pubname='supabase_realtime' and tablename='activity_log'),1,'activity is realtime published');

set local role authenticated;
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
insert into public.tasks(title,description,created_by,updated_by) values('Foreign orchid','private','92000000-0000-0000-0000-000000000001','92000000-0000-0000-0000-000000000001');
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000001',true);
select is((select count(*)::integer from public.activity_log),0,'foreign activity hidden');
insert into public.tasks(id,title,description,created_by,updated_by) values('91000000-0000-0000-0000-000000000010','Orchid task','Hidden needle','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000001');
select is((select count(*)::integer from public.activity_log),1,'creation logs once');
select is((select actor_user_id from public.activity_log limit 1),'91000000-0000-0000-0000-000000000001'::uuid,'actor is authenticated user');
select is((select household_id from public.activity_log limit 1),(select household_id from public.profiles where id=auth.uid()),'household comes from entity');
select is((select metadata from public.activity_log limit 1),'{}'::jsonb,'no descriptions or full snapshots');
select throws_ok($$insert into public.activity_log(household_id,actor_user_id,action,entity_type,entity_id) values(private.current_household_id(),auth.uid(),'created','task',gen_random_uuid())$$,'42501',null,'cannot forge activity');
select throws_ok($$update public.activity_log set actor_user_id='91000000-0000-0000-0000-000000000002'$$,'42501',null,'cannot rewrite actor');
select throws_ok($$delete from public.activity_log$$,'42501',null,'cannot delete activity');
update public.tasks set title=title,updated_by=auth.uid() where id='91000000-0000-0000-0000-000000000010';
select is((select count(*)::integer from public.activity_log),1,'no-op saves are silent');
update public.tasks set status='done',updated_by=auth.uid() where id='91000000-0000-0000-0000-000000000010';
select is((select action from public.activity_log order by created_at desc limit 1),'completed','task completion logged');
update public.tasks set status='archived',archived_at=now(),updated_by=auth.uid() where id='91000000-0000-0000-0000-000000000010';
select is((select action from public.activity_log order by created_at desc limit 1),'archived','archive logged');
select is((select count(*)::integer from public.search_household_entities('ORCHID')),1,'case-insensitive title search isolates household and includes archived tasks');
select is((select count(*)::integer from public.search_household_entities('needle')),1,'task description search');
select ok((select archived from public.search_household_entities('needle') limit 1),'archived state returned');
update public.tasks set status='to_do',archived_at=null,updated_by=auth.uid() where id='91000000-0000-0000-0000-000000000010';
select is((select action from public.activity_log order by created_at desc limit 1),'restored','restore logged');

insert into public.recipes(name,created_by,updated_by,archived_at) values('Orchid recipe',auth.uid(),auth.uid(),now());
insert into public.meals(name,planned_date,created_by,updated_by,archived_at) values('Orchid meal',current_date,auth.uid(),auth.uid(),now());
insert into public.events(title,starts_at,ends_at,created_by,updated_by,archived_at) values('Orchid event',now(),now(),auth.uid(),auth.uid(),now());
insert into public.expenses(title,amount,paid_by,category_id,expense_date,created_by,updated_by,archived_at)
values('Orchid expense',12.34,auth.uid(),(select id from public.expense_categories where name='Other' limit 1),current_date,auth.uid(),auth.uid(),now());
insert into public.shopping_general(label,created_by,updated_by) values('Orchid shopping',auth.uid(),auth.uid());
select is((select count(*)::integer from public.search_household_entities('orchid') where entity_type='recipe'),1,'search finds recipes');
select is((select count(*)::integer from public.search_household_entities('orchid') where entity_type='meal'),1,'search finds meals');
select is((select count(*)::integer from public.search_household_entities('orchid') where entity_type='event'),1,'search finds events');
select is((select count(*)::integer from public.search_household_entities('orchid') where entity_type='expense'),1,'search finds expenses');
select is((select count(*)::integer from public.search_household_entities('orchid')),5,'shopping excluded');
select is((select count(*)::integer from public.search_household_entities('')),0,'empty search returns no rows');
select is((select count(*)::integer from public.search_household_entities('%')),0,'percent is literal not wildcard');
select is((select count(*)::integer from public.search_household_entities('',true)),4,'archive includes four archived domains');
update public.tasks set status='archived',archived_at=now(),updated_by=auth.uid() where id='91000000-0000-0000-0000-000000000010';
select is((select count(distinct entity_type)::integer from public.search_household_entities('',true)),5,'archive groups all five supported types');
select is((select count(*)::integer from public.search_household_entities('orchid',false,4)),1,'search pagination advances');
select is((select count(*)::integer from public.activity_log where entity_type='meal' and action='planned'),1,'meal planning logged');
select is((select count(*)::integer from public.activity_log where entity_type='shopping'),1,'meaningful General creation logged');
select set_config('request.jwt.claim.sub','91000000-0000-0000-0000-000000000002',true);
select is((select count(*)::integer from public.search_household_entities('orchid')),5,'second household member sees same entities');
update public.tasks set status='to_do',archived_at=null,updated_by=auth.uid() where id='91000000-0000-0000-0000-000000000010';
select is((select actor_user_id from public.activity_log order by created_at desc limit 1),auth.uid(),'second actor attributed correctly');
select set_config('request.jwt.claim.sub','92000000-0000-0000-0000-000000000001',true);
select is((select count(*)::integer from public.activity_log),1,'other household sees only its own activity');
select is((select count(*)::integer from public.search_household_entities('orchid')),1,'modified client cannot search other household');
select is((select count(*)::integer from public.search_household_entities('',true)),0,'other household archive stays isolated');
reset role;
select * from extensions.finish();
rollback;
