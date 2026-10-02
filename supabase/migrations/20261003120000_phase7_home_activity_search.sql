-- Phase 7: durable, server-authored activity and RLS-invoker search.
create table public.activity_log (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references public.households(id) on delete cascade,
  actor_user_id uuid not null references public.profiles(id),
  action text not null check (action in ('created','changed','completed','reopened','archived','restored','planned')),
  entity_type text not null check (entity_type in ('task','recipe','meal','event','expense','shopping')),
  entity_id uuid not null,
  metadata jsonb not null default '{}'::jsonb check (metadata = '{}'::jsonb),
  created_at timestamptz not null default clock_timestamp()
);
create index activity_log_household_recent_idx on public.activity_log(household_id, created_at desc, id desc);
alter table public.activity_log enable row level security;
alter table public.activity_log force row level security;
revoke all on public.activity_log from public, anon, authenticated;
grant select on public.activity_log to authenticated;
create policy activity_household_read on public.activity_log for select to authenticated
using (household_id = (select private.current_household_id()));
alter publication supabase_realtime add table public.activity_log;

create function private.log_household_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  current_row jsonb := to_jsonb(new);
  previous_row jsonb;
  verb text := 'changed';
  kind text := tg_argv[0];
begin
  -- Administrative/import writes without an authenticated actor are not attributed.
  if actor is null then return new; end if;
  if new.household_id is distinct from private.current_household_id()
     or not exists (select 1 from public.profiles p where p.id=actor and p.household_id=new.household_id) then
    raise exception 'Activity actor must belong to the entity household' using errcode='42501';
  end if;
  if tg_op = 'INSERT' then
    verb := case when kind='meal' then 'planned' else 'created' end;
  else
    previous_row := to_jsonb(old);
    -- Timestamp/updater-only writes and identical form saves are not activity.
    if (current_row - array['updated_at','updated_by','completed_at'])
       = (previous_row - array['updated_at','updated_by','completed_at']) then return new; end if;
    if (current_row->>'archived_at') is not null and (previous_row->>'archived_at') is null then verb := 'archived';
    elsif (current_row->>'archived_at') is null and (previous_row->>'archived_at') is not null then verb := 'restored';
    elsif kind='task' and current_row->>'status'='archived' and previous_row->>'status'<>'archived' then verb := 'archived';
    elsif kind='task' and current_row->>'status'<>'archived' and previous_row->>'status'='archived' then verb := 'restored';
    elsif kind='task' and current_row->>'status'='done' and previous_row->>'status'<>'done' then verb := 'completed';
    elsif kind='task' and current_row->>'status'<>'done' and previous_row->>'status'='done' then verb := 'reopened';
    elsif kind='shopping' and current_row->>'is_done'='true' and previous_row->>'is_done'='false' then verb := 'completed';
    elsif kind='shopping' and current_row->>'is_done'='false' and previous_row->>'is_done'='true' then verb := 'reopened';
    end if;
  end if;
  insert into public.activity_log(household_id, actor_user_id, action, entity_type, entity_id)
    values(new.household_id, actor, verb, kind, new.id);
  return new;
end;
$$;
revoke all on function private.log_household_activity() from public, anon, authenticated;
create trigger tasks_activity after insert or update on public.tasks for each row execute function private.log_household_activity('task');
create trigger recipes_activity after insert or update on public.recipes for each row execute function private.log_household_activity('recipe');
create trigger meals_activity after insert or update on public.meals for each row execute function private.log_household_activity('meal');
create trigger events_activity after insert or update on public.events for each row execute function private.log_household_activity('event');
create trigger expenses_activity after insert or update on public.expenses for each row execute function private.log_household_activity('expense');
create trigger shopping_activity after insert or update on public.shopping_general for each row execute function private.log_household_activity('shopping');

-- No shopping union. No caller-provided household. Every branch runs under RLS.
-- strpos implements literal substring matching (%, _ and commas are not operators).
create function public.search_household_entities(query_text text default '', archived_only boolean default false, page_offset integer default 0)
returns table(entity_type text, entity_id uuid, title text, archived boolean)
language sql stable security invoker set search_path = '' as $$
  with entities as (
    select 'task'::text as kind, id, title as label, description as detail,
      (archived_at is not null or status='archived') as is_archived from public.tasks
    union all select 'recipe', id, name, instructions, archived_at is not null from public.recipes
    union all select 'meal', id, name, notes, archived_at is not null from public.meals
    union all select 'event', id, title, description, archived_at is not null from public.events
    union all select 'expense', id, title, note, archived_at is not null from public.expenses
  )
  select kind, id, label, is_archived from entities
  where (not archived_only or is_archived)
    and (archived_only or length(btrim(coalesce(query_text,''))) > 0)
    and (strpos(lower(label),lower(btrim(coalesce(query_text,'')))) > 0
      or strpos(lower(coalesce(detail,'')),lower(btrim(coalesce(query_text,'')))) > 0)
  order by kind, lower(label), id
  limit 100 offset greatest(coalesce(page_offset,0),0);
$$;
revoke all on function public.search_household_entities(text,boolean,integer) from public, anon;
grant execute on function public.search_household_entities(text,boolean,integer) to authenticated;
