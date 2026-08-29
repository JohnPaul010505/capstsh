-- nutrition_foods: verified reference table for Filipino / common dishes
-- Seeded manually from DOST-FNRI PhilFCT lookup tool (see nutrition_foods_template.xlsx)

create table if not exists public.nutrition_foods (
  id uuid primary key default gen_random_uuid(),
  food_name text not null,
  aliases text[] default '{}',
  category text not null default '',
  serving_label text not null default '',
  serving_size_g numeric not null,
  calories_kcal numeric not null,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  source text not null default 'DOST-FNRI PhilFCT',
  created_at timestamptz not null default now()
);

create index if not exists idx_nutrition_foods_name on public.nutrition_foods(food_name);
create index if not exists idx_nutrition_foods_category on public.nutrition_foods(category);

-- Anyone can read reference nutrition data; admins can manage it
create policy "Authenticated users can read nutrition_foods"
  on public.nutrition_foods for select
  to authenticated
  using (true);

create policy "Anon can read nutrition_foods"
  on public.nutrition_foods for select
  to anon
  using (true);

create policy "Admins can insert nutrition_foods"
  on public.nutrition_foods for insert
  with check (public.is_admin());

create policy "Admins can update nutrition_foods"
  on public.nutrition_foods for update
  using (public.is_admin());

create policy "Admins can delete nutrition_foods"
  on public.nutrition_foods for delete
  using (public.is_admin());

alter table public.nutrition_foods enable row level security;


-- food_identification_logs: optional accuracy / correction tracking (step 7)
create table if not exists public.food_identification_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references public.profiles(id) on delete cascade,
  photo_url text not null,
  ai_candidates jsonb not null,
  selected_food text not null,
  member_edited boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_food_identification_logs_member on public.food_identification_logs(member_id);
create index if not exists idx_food_identification_logs_created on public.food_identification_logs(created_at);

create policy "Users can insert own food_identification_logs"
  on public.food_identification_logs for insert
  with check (auth.uid() = member_id);

create policy "Users can read own food_identification_logs"
  on public.food_identification_logs for select
  using (auth.uid() = member_id);

create policy "Admins can read all food_identification_logs"
  on public.food_identification_logs for select
  using (public.is_admin());

alter table public.food_identification_logs enable row level security;
