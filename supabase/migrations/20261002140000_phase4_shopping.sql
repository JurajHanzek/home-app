-- Phase 4: simple household General shopping list.
-- Meal-derived shopping stays in meal_ingredients and is never duplicated here.

create table public.shopping_general (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id()
    references public.households(id) on delete cascade,
  label text not null check (
    char_length(label) between 1 and 200 and char_length(btrim(label)) > 0
  ),
  note text,
  is_done boolean not null default false,
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id)
);

create index shopping_general_household_active_idx
  on public.shopping_general(household_id, is_done, created_at)
  where archived_at is null;
create index shopping_general_household_archived_idx
  on public.shopping_general(household_id, archived_at)
  where archived_at is not null;

create trigger shopping_general_set_updated_at
before update on public.shopping_general
for each row execute function private.set_updated_at();

alter table public.shopping_general enable row level security;
alter table public.shopping_general force row level security;
revoke all on public.shopping_general from anon, authenticated;

grant select, insert on public.shopping_general to authenticated;
grant update (label, note, is_done, updated_by, archived_at)
  on public.shopping_general to authenticated;

create policy shopping_general_member_select
on public.shopping_general for select to authenticated
using (household_id = (select private.current_household_id()));

create policy shopping_general_member_insert
on public.shopping_general for insert to authenticated
with check (
  household_id = (select private.current_household_id())
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
);

create policy shopping_general_member_update
on public.shopping_general for update to authenticated
using (household_id = (select private.current_household_id()))
with check (
  household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
);

alter publication supabase_realtime add table public.shopping_general;
