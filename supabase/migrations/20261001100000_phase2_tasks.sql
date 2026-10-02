-- Phase 2: household tasks, categories, reusable templates, and private images.
-- Additive only: Phase 1 household/auth tables are not altered or removed.

create table public.task_categories (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id() references public.households(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 40),
  color text not null default '#68794D' check (color ~ '^#[0-9A-Fa-f]{6}$'),
  icon text,
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (household_id, id),
  unique (household_id, name)
);

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id() references public.households(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text not null default '',
  status text not null default 'to_do' check (status in ('to_do','in_progress','done','archived')),
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  category_id uuid,
  due_at timestamptz,
  reminder_at timestamptz,
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  source_template_id uuid,
  unique (household_id, id),
  foreign key (household_id, category_id)
    references public.task_categories(household_id, id),
  check ((status = 'archived') = (archived_at is not null))
);

create table public.task_assignees (
  household_id uuid not null default private.current_household_id(),
  task_id uuid not null,
  user_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (task_id, user_id),
  foreign key (household_id, task_id) references public.tasks(household_id, id) on delete cascade,
  foreign key (household_id, user_id) references public.profiles(household_id, id) on delete cascade
);

create table public.task_checklist_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id(),
  task_id uuid not null,
  label text not null check (char_length(btrim(label)) between 1 and 200),
  is_done boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (household_id, task_id) references public.tasks(household_id, id) on delete cascade
);

create table public.task_templates (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id() references public.households(id) on delete cascade,
  title text not null check (char_length(btrim(title)) between 1 and 120),
  description text not null default '',
  category_id uuid,
  priority text not null default 'normal' check (priority in ('low','normal','high','urgent')),
  enabled boolean not null default true,
  due_offset_days integer check (due_offset_days is null or due_offset_days between -36500 and 36500),
  reminder_offset_minutes integer check (reminder_offset_minutes is null or reminder_offset_minutes between -5256000 and 5256000),
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id),
  foreign key (household_id, category_id) references public.task_categories(household_id, id)
);

create table public.task_template_assignees (
  household_id uuid not null default private.current_household_id(),
  template_id uuid not null,
  user_id uuid not null,
  primary key (template_id, user_id),
  foreign key (household_id, template_id) references public.task_templates(household_id, id) on delete cascade,
  foreign key (household_id, user_id) references public.profiles(household_id, id) on delete cascade
);

create table public.task_template_checklist_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id(),
  template_id uuid not null,
  label text not null check (char_length(btrim(label)) between 1 and 200),
  sort_order integer not null default 0,
  foreign key (household_id, template_id) references public.task_templates(household_id, id) on delete cascade
);

-- source_template_id FK is installed after task_templates exists.
alter table public.tasks add constraint tasks_source_template_fk
  foreign key (household_id, source_template_id)
  references public.task_templates(household_id, id);
create table public.task_images (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id(),
  task_id uuid not null,
  storage_path text not null unique,
  size_bytes bigint not null check (size_bytes > 0),
  width integer,
  height integer,
  created_by uuid not null,
  created_at timestamptz not null default now(),
  removed_at timestamptz,
  foreign key (household_id, task_id) references public.tasks(household_id, id) on delete cascade,
  foreign key (household_id, created_by) references public.profiles(household_id, id),
  check (storage_path like household_id::text || '/tasks/' || task_id::text || '/%')
);

create index tasks_household_status_idx on public.tasks(household_id, status, due_at);
create index tasks_household_updated_idx on public.tasks(household_id, updated_at desc);
create index task_assignees_user_idx on public.task_assignees(household_id, user_id);
create index task_checklist_task_idx on public.task_checklist_items(household_id, task_id, sort_order);
create index task_images_task_idx on public.task_images(household_id, task_id) where removed_at is null;
create index task_templates_household_idx on public.task_templates(household_id, archived_at, title);

insert into public.task_categories(household_id, name)
select id, category from public.households cross join (values ('Outdoor'), ('Indoor')) as seed(category);

create trigger task_categories_set_updated_at before update on public.task_categories
for each row execute function private.set_updated_at();
create trigger tasks_set_updated_at before update on public.tasks
for each row execute function private.set_updated_at();
create trigger task_checklist_set_updated_at before update on public.task_checklist_items
for each row execute function private.set_updated_at();
create trigger task_templates_set_updated_at before update on public.task_templates
for each row execute function private.set_updated_at();

do $$
declare table_name text;
begin
  foreach table_name in array array['task_categories','tasks','task_assignees','task_checklist_items',
    'task_images','task_templates','task_template_assignees','task_template_checklist_items'] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on public.%I from anon, authenticated', table_name);
  end loop;
end $$;

grant select, insert on public.task_categories to authenticated;
grant update (name, color, icon, archived_at) on public.task_categories to authenticated;
grant select, insert on public.tasks to authenticated;
grant update (title, description, status, priority, category_id, due_at, reminder_at, updated_by, archived_at, source_template_id)
  on public.tasks to authenticated;
grant select, insert, delete on public.task_assignees to authenticated;
grant select, insert, delete on public.task_checklist_items to authenticated;
grant update (label, is_done, sort_order) on public.task_checklist_items to authenticated;
grant select, insert on public.task_images to authenticated;
grant update (removed_at) on public.task_images to authenticated;
grant select, insert on public.task_templates to authenticated;
grant update (title, description, category_id, priority, enabled, due_offset_days, reminder_offset_minutes, updated_by, archived_at)
  on public.task_templates to authenticated;
grant select, insert, delete on public.task_template_assignees to authenticated;
grant select, insert, delete on public.task_template_checklist_items to authenticated;
grant update (label, sort_order) on public.task_template_checklist_items to authenticated;

create policy task_categories_member_all on public.task_categories for all to authenticated
using (household_id = (select private.current_household_id()))
with check (household_id = (select private.current_household_id()));
create policy tasks_member_all on public.tasks for all to authenticated
using (household_id = (select private.current_household_id()))
with check (household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
  and exists (select 1 from public.profiles p where p.id = created_by
    and p.household_id = (select private.current_household_id())));
create policy task_assignees_member_all on public.task_assignees for all to authenticated
using (household_id = (select private.current_household_id()))
with check (household_id = (select private.current_household_id()));
create policy task_checklist_member_all on public.task_checklist_items for all to authenticated
using (exists (select 1 from public.tasks t where t.id = task_id
  and t.household_id = task_checklist_items.household_id and t.household_id = (select private.current_household_id())))
with check (exists (select 1 from public.tasks t where t.id = task_id
  and t.household_id = task_checklist_items.household_id and t.household_id = (select private.current_household_id())));
create policy task_images_member_all on public.task_images for all to authenticated
using (exists (select 1 from public.tasks t where t.id = task_id
  and t.household_id = task_images.household_id and t.household_id = (select private.current_household_id())))
with check (exists (select 1 from public.tasks t where t.id = task_id
  and t.household_id = task_images.household_id and t.household_id = (select private.current_household_id())));
create policy task_templates_member_all on public.task_templates for all to authenticated
using (household_id = (select private.current_household_id()))
with check (household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
  and exists (select 1 from public.profiles p where p.id = created_by
    and p.household_id = (select private.current_household_id())));
create policy task_template_assignees_member_all on public.task_template_assignees for all to authenticated
using (household_id = (select private.current_household_id()))
with check (household_id = (select private.current_household_id()));
create policy task_template_checklist_member_all on public.task_template_checklist_items for all to authenticated
using (exists (select 1 from public.task_templates t where t.id = template_id
  and t.household_id = task_template_checklist_items.household_id and t.household_id = (select private.current_household_id())))
with check (exists (select 1 from public.task_templates t where t.id = template_id
  and t.household_id = task_template_checklist_items.household_id and t.household_id = (select private.current_household_id())));

-- Task assignment cap is enforced in the database for every client.
create function private.enforce_task_assignee_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.task_assignees a where a.task_id = new.task_id) > 2 then
    raise exception using errcode = '22023', message = 'A task may have at most two assignees';
  end if;
  return null;
end $$;
revoke all on function private.enforce_task_assignee_limit() from public, anon, authenticated, service_role;
create constraint trigger task_assignee_limit after insert or update on public.task_assignees
deferrable initially deferred for each row execute function private.enforce_task_assignee_limit();

create function private.enforce_template_assignee_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.task_template_assignees a where a.template_id = new.template_id) > 2 then
    raise exception using errcode = '22023', message = 'A task template may have at most two assignees';
  end if;
  return null;
end $$;
revoke all on function private.enforce_template_assignee_limit() from public, anon, authenticated, service_role;
create constraint trigger task_template_assignee_limit after insert or update on public.task_template_assignees
deferrable initially deferred for each row execute function private.enforce_template_assignee_limit();

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('household-media', 'household-media', false, 10485760, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = false;

create policy task_media_read on storage.objects for select to authenticated
using (bucket_id = 'household-media' and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'tasks'
  and exists (select 1 from public.tasks t where t.id::text = (storage.foldername(name))[3]
    and t.household_id = (select private.current_household_id())));
create policy task_media_insert on storage.objects for insert to authenticated
with check (bucket_id = 'household-media' and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'tasks'
  and exists (select 1 from public.tasks t where t.id::text = (storage.foldername(name))[3]
    and t.household_id = (select private.current_household_id())));
create policy task_media_update on storage.objects for update to authenticated
using (bucket_id = 'household-media' and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'tasks'
  and exists (select 1 from public.tasks t where t.id::text = (storage.foldername(name))[3]
    and t.household_id = (select private.current_household_id())))
with check (bucket_id = 'household-media' and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'tasks'
  and exists (select 1 from public.tasks t where t.id::text = (storage.foldername(name))[3]
    and t.household_id = (select private.current_household_id())));
create policy task_media_delete on storage.objects for delete to authenticated
using (bucket_id = 'household-media' and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'tasks'
  and exists (select 1 from public.tasks t where t.id::text = (storage.foldername(name))[3]
    and t.household_id = (select private.current_household_id())));

alter publication supabase_realtime add table public.task_categories, public.tasks,
  public.task_assignees, public.task_checklist_items, public.task_images,
  public.task_templates, public.task_template_assignees, public.task_template_checklist_items;
