-- Phase 6: household expenses and manageable categories.
-- Additive only; does not modify earlier feature tables or household records.

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id()
    references public.households(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 60),
  color text not null default '#68794D'
    check (color ~ '^#[0-9A-Fa-f]{6}$'),
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id)
);

create unique index expense_categories_household_name_key
  on public.expense_categories(household_id, lower(name));
create index expense_categories_household_active_idx
  on public.expense_categories(household_id, name) where archived_at is null;

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id()
    references public.households(id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  currency text not null default 'EUR' check (currency = 'EUR'),
  title text not null check (char_length(btrim(title)) between 1 and 160),
  category_id uuid not null,
  paid_by uuid not null,
  shared boolean not null default true,
  expense_date date not null default current_date,
  note text not null default '',
  receipt_path text,
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id),
  foreign key (household_id, category_id)
    references public.expense_categories(household_id, id),
  foreign key (household_id, paid_by)
    references public.profiles(household_id, id),
  check (
    receipt_path is null or
    receipt_path ~ ('^' || household_id::text || '/expenses/' || id::text ||
      '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}[.]jpg$')
  )
);

create index expenses_household_date_active_idx
  on public.expenses(household_id, expense_date desc) where archived_at is null;
create index expenses_household_category_active_idx
  on public.expenses(household_id, category_id, expense_date desc)
  where archived_at is null;
create index expenses_household_archive_idx
  on public.expenses(household_id, archived_at)
  where archived_at is not null;

create trigger expense_categories_set_updated_at
before update on public.expense_categories
for each row execute function private.set_updated_at();
create trigger expenses_set_updated_at
before update on public.expenses
for each row execute function private.set_updated_at();

-- Seed existing households and future owner-provisioned households.
create function private.seed_expense_categories()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.expense_categories(household_id, name, color, created_by, updated_by)
  select new.household_id, category.name, category.color, profile.id, profile.id
  from public.profiles profile
  cross join (values
    ('Groceries', '#718B54'), ('Home', '#A27B57'), ('Bills', '#657A9D'),
    ('Transport', '#B06D43'), ('Health', '#648A7B'), ('Leisure', '#92739C'),
    ('Other', '#73777B')
  ) as category(name, color)
  where profile.household_id = new.household_id
  order by profile.created_at, profile.id
  limit 7
  on conflict do nothing;
  return new;
end;
$$;
revoke all on function private.seed_expense_categories() from public, anon, authenticated, service_role;
create trigger profiles_seed_expense_categories
after insert on public.profiles
for each row execute function private.seed_expense_categories();

insert into public.expense_categories(household_id, name, color, created_by, updated_by)
select household.id, category.name, category.color, profile.id, profile.id
from public.households household
join lateral (
  select p.id from public.profiles p
  where p.household_id = household.id
  order by p.created_at, p.id limit 1
) profile on true
cross join (values
  ('Groceries', '#718B54'), ('Home', '#A27B57'), ('Bills', '#657A9D'),
  ('Transport', '#B06D43'), ('Health', '#648A7B'), ('Leisure', '#92739C'),
  ('Other', '#73777B')
) as category(name, color)
on conflict do nothing;

alter table public.expense_categories enable row level security;
alter table public.expense_categories force row level security;
alter table public.expenses enable row level security;
alter table public.expenses force row level security;
revoke all on public.expense_categories, public.expenses from anon, authenticated;

grant select on public.expense_categories to authenticated;
grant insert (id, household_id, name, color, created_by, updated_by, archived_at)
  on public.expense_categories to authenticated;
grant update (name, color, updated_by, archived_at)
  on public.expense_categories to authenticated;
grant select on public.expenses to authenticated;
grant insert (
  id, household_id, amount, currency, title, category_id, paid_by, shared,
  expense_date, note, receipt_path, created_by, updated_by, archived_at
) on public.expenses to authenticated;
grant update (
  amount, currency, title, category_id, paid_by, shared, expense_date,
  note, receipt_path, updated_by, archived_at
) on public.expenses to authenticated;

create policy expense_categories_member_select
on public.expense_categories for select to authenticated
using (household_id = (select private.current_household_id()));
-- Only the trusted database owner needs to seed categories while the owner-only
-- household provisioning function inserts new profiles. This grants no client access.
create policy expense_categories_provisioning
on public.expense_categories for all to postgres
using (true) with check (true);
create policy expense_categories_member_insert
on public.expense_categories for insert to authenticated
with check (
  household_id = (select private.current_household_id())
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
);
create policy expense_categories_member_update
on public.expense_categories for update to authenticated
using (household_id = (select private.current_household_id()))
with check (
  household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
);

create policy expenses_member_select
on public.expenses for select to authenticated
using (household_id = (select private.current_household_id()));
create policy expenses_member_insert
on public.expenses for insert to authenticated
with check (
  household_id = (select private.current_household_id())
  and created_by = (select auth.uid())
  and updated_by = (select auth.uid())
);
create policy expenses_member_update
on public.expenses for update to authenticated
using (household_id = (select private.current_household_id()))
with check (
  household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
);

-- Receipts use private household media, authorized through the parent expense.
create policy expense_receipt_read on storage.objects for select to authenticated
using (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'expenses'
  and exists (
    select 1 from public.expenses e
    where e.id::text = (storage.foldername(name))[3]
      and e.household_id = (select private.current_household_id())
  )
);
create policy expense_receipt_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'expenses'
  and exists (
    select 1 from public.expenses e
    where e.id::text = (storage.foldername(name))[3]
      and e.household_id = (select private.current_household_id())
  )
);
create policy expense_receipt_update on storage.objects for update to authenticated
using (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'expenses'
  and exists (
    select 1 from public.expenses e
    where e.id::text = (storage.foldername(name))[3]
      and e.household_id = (select private.current_household_id())
  )
)
with check (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'expenses'
  and exists (
    select 1 from public.expenses e
    where e.id::text = (storage.foldername(name))[3]
      and e.household_id = (select private.current_household_id())
  )
);
create policy expense_receipt_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'expenses'
  and exists (
    select 1 from public.expenses e
    where e.id::text = (storage.foldername(name))[3]
      and e.household_id = (select private.current_household_id())
  )
);

alter publication supabase_realtime add table public.expense_categories, public.expenses;
