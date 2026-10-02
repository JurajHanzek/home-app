-- Phase 5: shared household calendar events and bounded assignees.
-- Additive only; no existing household/task/meal/shopping rows are changed.

create table public.events (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id()
    references public.households(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text not null default '',
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  all_day boolean not null default false,
  location text,
  category text check (category is null or char_length(category) <= 80),
  color text not null default '#68794D'
    check (color ~ '^#[0-9A-Fa-f]{6}$'),
  reminder_at timestamptz,
  recurrence jsonb check (recurrence is null or jsonb_typeof(recurrence) = 'object'),
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id),
  check (ends_at >= starts_at)
);

create table public.event_assignees (
  household_id uuid not null default private.current_household_id(),
  event_id uuid not null,
  user_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id),
  foreign key (household_id, event_id)
    references public.events(household_id, id) on delete cascade,
  foreign key (household_id, user_id)
    references public.profiles(household_id, id) on delete cascade
);

create index events_household_start_active_idx
  on public.events(household_id, starts_at) where archived_at is null;
create index events_household_archive_idx
  on public.events(household_id, archived_at) where archived_at is not null;
create index event_assignees_household_user_idx
  on public.event_assignees(household_id, user_id, event_id);

create trigger events_set_updated_at
before update on public.events
for each row execute function private.set_updated_at();

create function private.enforce_event_assignee_limit()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  current_count integer;
begin
  -- Serialize assignments for one event so concurrent inserts cannot exceed 2.
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext(new.event_id::text));
  select count(*) into current_count
  from public.event_assignees ea
  where ea.event_id = new.event_id;

  if current_count >= 2 then
    raise exception using errcode = '23514', message = 'An event can have at most two assignees';
  end if;
  return new;
end;
$$;
revoke all on function private.enforce_event_assignee_limit() from public, anon, authenticated, service_role;

create trigger event_assignees_at_most_two
before insert on public.event_assignees
for each row execute function private.enforce_event_assignee_limit();

alter table public.events enable row level security;
alter table public.events force row level security;
alter table public.event_assignees enable row level security;
alter table public.event_assignees force row level security;
revoke all on public.events, public.event_assignees from anon, authenticated;

grant select, insert on public.events to authenticated;
grant update (
  title, description, starts_at, ends_at, all_day, location, category,
  color, reminder_at, recurrence, updated_by, archived_at
) on public.events to authenticated;
grant select, insert, delete on public.event_assignees to authenticated;

create policy events_member_select on public.events for select to authenticated
using (household_id = (select private.current_household_id()));

create policy events_member_insert on public.events for insert to authenticated
with check (
  household_id = (select private.current_household_id())
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
);

create policy events_member_update on public.events for update to authenticated
using (household_id = (select private.current_household_id()))
with check (
  household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
);

create policy event_assignees_member_select on public.event_assignees for select to authenticated
using (
  household_id = (select private.current_household_id())
  and exists (
    select 1 from public.events e
    where e.id = event_id and e.household_id = event_assignees.household_id
  )
);

create policy event_assignees_member_insert on public.event_assignees for insert to authenticated
with check (
  household_id = (select private.current_household_id())
  and exists (
    select 1 from public.events e
    where e.id = event_id and e.household_id = event_assignees.household_id
  )
  and exists (
    select 1 from public.profiles p
    where p.id = user_id and p.household_id = event_assignees.household_id
  )
);

create policy event_assignees_member_delete on public.event_assignees for delete to authenticated
using (
  household_id = (select private.current_household_id())
  and exists (
    select 1 from public.events e
    where e.id = event_id and e.household_id = event_assignees.household_id
  )
);

alter publication supabase_realtime add table public.events, public.event_assignees;
