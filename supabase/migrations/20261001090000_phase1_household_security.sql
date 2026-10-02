-- Phase 1: household identity, member profiles, device rows and settings.
-- Public signup is disabled in supabase/config.toml; profiles are provisioned
-- only by the private administrator-only function below.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

alter default privileges for role postgres in schema public
  revoke all on tables from anon, authenticated;
alter default privileges for role postgres in schema private
  revoke execute on functions from public, anon, authenticated, service_role;

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 1 and 80),
  created_at timestamptz not null default now()
);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  household_id uuid not null references public.households (id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 1 and 60),
  initials text not null check (char_length(btrim(initials)) between 1 and 4),
  avatar_path text,
  accent_color text not null default '#68794D'
    check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id)
);

create index profiles_household_id_idx on public.profiles (household_id);

create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  fcm_token text not null unique check (char_length(fcm_token) between 1 and 4096),
  platform text not null check (platform = 'android'),
  updated_at timestamptz not null default now(),
  disabled_at timestamptz
);

create index user_devices_user_id_idx on public.user_devices (user_id);

create table public.household_settings (
  household_id uuid primary key references public.households (id) on delete cascade,
  default_theme text not null default 'dark'
    check (default_theme in ('dark', 'flower')),
  notification_preferences jsonb not null default '{}'::jsonb
    check (jsonb_typeof(notification_preferences) = 'object'),
  storage_warning_settings jsonb not null
    default '{"task_image_count":100,"storage_budget_bytes":null}'::jsonb
    check (jsonb_typeof(storage_warning_settings) = 'object'),
  updated_at timestamptz not null default now()
);

create function private.current_household_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select profile.household_id
  from public.profiles as profile
  where profile.id = (select auth.uid())
  limit 1;
$$;

revoke all on function private.current_household_id() from public, anon;
grant execute on function private.current_household_id() to authenticated;

create function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated, service_role;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function private.set_updated_at();

create trigger user_devices_set_updated_at
before update on public.user_devices
for each row execute function private.set_updated_at();

create trigger household_settings_set_updated_at
before update on public.household_settings
for each row execute function private.set_updated_at();

-- This function is intentionally outside exposed API schemas and executable
-- only by the database owner through trusted provisioning tooling.
create function private.provision_household(
  p_name text,
  p_user_a uuid,
  p_display_name_a text,
  p_initials_a text,
  p_user_b uuid,
  p_display_name_b text,
  p_initials_b text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  household_uuid uuid;
begin
  if p_user_a is null or p_user_b is null or p_user_a = p_user_b then
    raise exception using errcode = '22023', message = 'Two distinct auth users are required';
  end if;

  if char_length(btrim(coalesce(p_name, ''))) not between 1 and 80
     or char_length(btrim(coalesce(p_display_name_a, ''))) not between 1 and 60
     or char_length(btrim(coalesce(p_display_name_b, ''))) not between 1 and 60
     or char_length(btrim(coalesce(p_initials_a, ''))) not between 1 and 4
     or char_length(btrim(coalesce(p_initials_b, ''))) not between 1 and 4 then
    raise exception using errcode = '22023', message = 'Household and display names are required';
  end if;

  if not exists (select 1 from auth.users where id = p_user_a)
     or not exists (select 1 from auth.users where id = p_user_b) then
    raise exception using errcode = '22023', message = 'Both auth users must exist before provisioning';
  end if;

  if exists (select 1 from public.profiles where id in (p_user_a, p_user_b)) then
    raise exception using errcode = '23505', message = 'An auth user is already linked to a household';
  end if;

  insert into public.households (name)
  values (btrim(p_name))
  returning id into household_uuid;

  insert into public.profiles (id, household_id, display_name, initials)
  values
    (p_user_a, household_uuid, btrim(p_display_name_a), upper(btrim(p_initials_a))),
    (p_user_b, household_uuid, btrim(p_display_name_b), upper(btrim(p_initials_b)));

  insert into public.household_settings (household_id)
  values (household_uuid);

  return household_uuid;
end;
$$;

revoke all on function private.provision_household(text, uuid, text, text, uuid, text, text)
  from public, anon, authenticated, service_role;

alter table public.households enable row level security;
alter table public.households force row level security;
alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.user_devices enable row level security;
alter table public.user_devices force row level security;
alter table public.household_settings enable row level security;
alter table public.household_settings force row level security;

revoke all on public.households, public.profiles, public.user_devices,
  public.household_settings from anon, authenticated;

grant select on public.households to authenticated;
grant update (name) on public.households to authenticated;
grant select on public.profiles to authenticated;
grant update (display_name, initials, avatar_path, accent_color)
  on public.profiles to authenticated;
grant select, insert, update, delete on public.user_devices to authenticated;
grant select on public.household_settings to authenticated;
grant update (default_theme, notification_preferences, storage_warning_settings)
  on public.household_settings to authenticated;

create policy households_member_read
on public.households for select to authenticated
using (id = (select private.current_household_id()));

create policy households_member_rename
on public.households for update to authenticated
using (id = (select private.current_household_id()))
with check (id = (select private.current_household_id()));

create policy profiles_household_read
on public.profiles for select to authenticated
using (household_id = (select private.current_household_id()));

create policy profiles_self_update
on public.profiles for update to authenticated
using (id = (select auth.uid()))
with check (
  id = (select auth.uid())
  and household_id = (select private.current_household_id())
);

create policy user_devices_self_select
on public.user_devices for select to authenticated
using (user_id = (select auth.uid()));

create policy user_devices_self_insert
on public.user_devices for insert to authenticated
with check (user_id = (select auth.uid()));

create policy user_devices_self_update
on public.user_devices for update to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

create policy user_devices_self_delete
on public.user_devices for delete to authenticated
using (user_id = (select auth.uid()));

create policy household_settings_member_read
on public.household_settings for select to authenticated
using (household_id = (select private.current_household_id()));

create policy household_settings_member_update
on public.household_settings for update to authenticated
using (household_id = (select private.current_household_id()))
with check (household_id = (select private.current_household_id()));
