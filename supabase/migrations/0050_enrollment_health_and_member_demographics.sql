alter table public.enrollments
  add column if not exists civil_status text,
  add column if not exists religion text,
  add column if not exists religion_other text,
  add column if not exists health_background jsonb not null default '{}'::jsonb;

alter table public.profiles
  add column if not exists civil_status text,
  add column if not exists religion text,
  add column if not exists religion_other text;

create table if not exists public.member_health_background (
  member_id uuid primary key references public.profiles(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.member_health_background enable row level security;

drop policy if exists "Admins can manage member health background"
  on public.member_health_background;
create policy "Admins can manage member health background"
  on public.member_health_background
  for all
  using (public.is_admin())
  with check (public.is_admin());
