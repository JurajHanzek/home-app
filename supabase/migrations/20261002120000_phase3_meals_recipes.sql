-- Phase 3: reusable recipes and independent planned meal ingredients.
-- Additive only. Does not modify existing household, task, auth, or settings rows.

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id()
    references public.households(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 120),
  instructions text not null default '',
  image_path text,
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id),
  check (image_path is null or image_path like household_id::text || '/recipes/' || id::text || '/%')
);

create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id(),
  recipe_id uuid not null,
  label text not null check (char_length(btrim(label)) between 1 and 200),
  quantity text,
  unit text,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (household_id, recipe_id)
    references public.recipes(household_id, id) on delete cascade
);

create table public.meals (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id()
    references public.households(id) on delete cascade,
  planned_date date not null,
  planned_time time,
  meal_slot text check (meal_slot is null or meal_slot in ('breakfast','lunch','dinner','snack')),
  name text not null check (char_length(btrim(name)) between 1 and 120),
  recipe_id uuid,
  servings integer not null default 2 check (servings between 1 and 100),
  notes text not null default '',
  created_by uuid not null references public.profiles(id),
  updated_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  archived_at timestamptz,
  unique (household_id, id),
  foreign key (household_id, recipe_id) references public.recipes(household_id, id)
);

create table public.meal_ingredients (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null default private.current_household_id(),
  meal_id uuid not null,
  label text not null check (char_length(btrim(label)) between 1 and 200),
  quantity text,
  unit text,
  have boolean not null default false,
  sort_order integer not null default 0 check (sort_order >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (household_id, meal_id)
    references public.meals(household_id, id) on delete cascade
);

create index recipes_household_archive_name_idx
  on public.recipes(household_id, archived_at, name);
create index recipe_ingredients_recipe_order_idx
  on public.recipe_ingredients(household_id, recipe_id, sort_order);
create index meals_household_planned_idx
  on public.meals(household_id, planned_date, planned_time) where archived_at is null;
create index meals_household_recipe_idx
  on public.meals(household_id, recipe_id) where recipe_id is not null;
create index meal_ingredients_missing_idx
  on public.meal_ingredients(household_id, meal_id, sort_order) where have = false;

create trigger recipes_set_updated_at before update on public.recipes
for each row execute function private.set_updated_at();
create trigger recipe_ingredients_set_updated_at before update on public.recipe_ingredients
for each row execute function private.set_updated_at();
create trigger meals_set_updated_at before update on public.meals
for each row execute function private.set_updated_at();
create trigger meal_ingredients_set_updated_at before update on public.meal_ingredients
for each row execute function private.set_updated_at();

do $$
declare table_name text;
begin
  foreach table_name in array array['recipes','recipe_ingredients','meals','meal_ingredients'] loop
    execute format('alter table public.%I enable row level security', table_name);
    execute format('alter table public.%I force row level security', table_name);
    execute format('revoke all on public.%I from anon, authenticated', table_name);
  end loop;
end $$;

grant select, insert on public.recipes to authenticated;
grant update (name, instructions, image_path, updated_by, archived_at)
  on public.recipes to authenticated;
grant select, insert, delete on public.recipe_ingredients to authenticated;
grant update (label, quantity, unit, sort_order) on public.recipe_ingredients to authenticated;
grant select, insert on public.meals to authenticated;
grant update (planned_date, planned_time, meal_slot, name, recipe_id, servings, notes, updated_by, archived_at)
  on public.meals to authenticated;
grant select, insert, delete on public.meal_ingredients to authenticated;
grant update (label, quantity, unit, have, sort_order) on public.meal_ingredients to authenticated;

create policy recipes_member_all on public.recipes for all to authenticated
using (household_id = (select private.current_household_id()))
with check (
  household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
  and exists (select 1 from public.profiles p where p.id = created_by
    and p.household_id = (select private.current_household_id()))
);

create policy recipe_ingredients_parent_household on public.recipe_ingredients for all to authenticated
using (exists (
  select 1 from public.recipes r where r.id = recipe_id
    and r.household_id = recipe_ingredients.household_id
    and r.household_id = (select private.current_household_id())
))
with check (exists (
  select 1 from public.recipes r where r.id = recipe_id
    and r.household_id = recipe_ingredients.household_id
    and r.household_id = (select private.current_household_id())
));

create policy meals_member_all on public.meals for all to authenticated
using (household_id = (select private.current_household_id()))
with check (
  household_id = (select private.current_household_id())
  and updated_by = (select auth.uid())
  and exists (select 1 from public.profiles p where p.id = created_by
    and p.household_id = (select private.current_household_id()))
);

create policy meal_ingredients_parent_household on public.meal_ingredients for all to authenticated
using (exists (
  select 1 from public.meals m where m.id = meal_id
    and m.household_id = meal_ingredients.household_id
    and m.household_id = (select private.current_household_id())
))
with check (exists (
  select 1 from public.meals m where m.id = meal_id
    and m.household_id = meal_ingredients.household_id
    and m.household_id = (select private.current_household_id())
));

-- Create a planned meal and its ingredient snapshot in one caller-authorized
-- transaction. Recipe ingredients are copied from the RLS-visible recipe;
-- every copy receives a new meal_ingredients row with have=false.
create function public.create_planned_meal(
  p_name text,
  p_planned_date date,
  p_planned_time time,
  p_meal_slot text,
  p_servings integer,
  p_notes text,
  p_recipe_id uuid,
  p_ingredients jsonb
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_household_id uuid := (select private.current_household_id());
  v_name text := p_name;
  v_recipe_name text;
  v_ingredients jsonb := coalesce(p_ingredients, '[]'::jsonb);
  v_meal_id uuid;
begin
  if v_household_id is null then
    raise exception using errcode = '42501', message = 'Household membership required';
  end if;
  if p_recipe_id is not null then
    select r.name,
      coalesce(jsonb_agg(jsonb_build_object(
        'label', ri.label, 'quantity', ri.quantity, 'unit', ri.unit, 'sort_order', ri.sort_order
      ) order by ri.sort_order, ri.id) filter (where ri.id is not null), '[]'::jsonb)
      into v_recipe_name, v_ingredients
    from public.recipes r
    left join public.recipe_ingredients ri on ri.recipe_id = r.id
      and ri.household_id = r.household_id
    where r.id = p_recipe_id and r.household_id = v_household_id
    group by r.id, r.name;
    if not found then
      raise exception using errcode = '42501', message = 'Recipe is unavailable';
    end if;
    v_name := coalesce(nullif(btrim(p_name), ''), v_recipe_name);
  elsif char_length(btrim(coalesce(p_name, ''))) not between 1 and 120 then
    raise exception using errcode = '22023', message = 'Meal name is required';
  end if;

  insert into public.meals(household_id, planned_date, planned_time, meal_slot, name, recipe_id,
    servings, notes, created_by, updated_by)
  values (v_household_id, p_planned_date, p_planned_time, p_meal_slot, v_name, p_recipe_id,
    p_servings, coalesce(p_notes, ''), (select auth.uid()), (select auth.uid()))
  returning id into v_meal_id;

  if jsonb_typeof(v_ingredients) <> 'array' then
    raise exception using errcode = '22023', message = 'Ingredients must be an array';
  end if;
  insert into public.meal_ingredients(household_id, meal_id, label, quantity, unit, have, sort_order)
  select v_household_id, v_meal_id, btrim(item->>'label'), nullif(item->>'quantity', ''),
    nullif(item->>'unit', ''), false, coalesce((item->>'sort_order')::integer, ordinality::integer - 1)
  from jsonb_array_elements(v_ingredients) with ordinality as ingredient(item, ordinality)
  where char_length(btrim(coalesce(item->>'label', ''))) > 0;

  return v_meal_id;
end;
$$;
revoke all on function public.create_planned_meal(text, date, time, text, integer, text, uuid, jsonb)
  from public, anon, authenticated;
grant execute on function public.create_planned_meal(text, date, time, text, integer, text, uuid, jsonb)
  to authenticated;

-- Recipe media shares the existing private household-media bucket. These
-- policies are scoped to recipes and do not change the task media policies.
create policy recipe_media_read on storage.objects for select to authenticated
using (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'recipes'
  and exists (select 1 from public.recipes r where r.id::text = (storage.foldername(name))[3]
    and r.household_id = (select private.current_household_id()))
);
create policy recipe_media_insert on storage.objects for insert to authenticated
with check (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'recipes'
  and exists (select 1 from public.recipes r where r.id::text = (storage.foldername(name))[3]
    and r.household_id = (select private.current_household_id()))
);
create policy recipe_media_update on storage.objects for update to authenticated
using (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'recipes'
  and exists (select 1 from public.recipes r where r.id::text = (storage.foldername(name))[3]
    and r.household_id = (select private.current_household_id()))
)
with check (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'recipes'
  and exists (select 1 from public.recipes r where r.id::text = (storage.foldername(name))[3]
    and r.household_id = (select private.current_household_id()))
);
create policy recipe_media_delete on storage.objects for delete to authenticated
using (
  bucket_id = 'household-media'
  and (storage.foldername(name))[1] = (select private.current_household_id())::text
  and (storage.foldername(name))[2] = 'recipes'
  and exists (select 1 from public.recipes r where r.id::text = (storage.foldername(name))[3]
    and r.household_id = (select private.current_household_id()))
);

alter publication supabase_realtime add table public.recipes, public.recipe_ingredients,
  public.meals, public.meal_ingredients;
