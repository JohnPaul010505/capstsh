-- Add fitness_goal column to profiles
alter table profiles add column if not exists fitness_goal text;

-- Enrollments table for QR-based member enrollment
create table if not exists enrollments (
  id uuid primary key default uuid_generate_v4(),
  full_name text not null,
  email text not null,
  phone text,
  date_of_birth date,
  gender text,
  address text,
  emergency_contact_name text,
  emergency_contact_phone text,
  emergency_contact_relation text,
  status text not null default 'pending',
  confirmed_at timestamptz,
  confirmed_by uuid references profiles(id),
  created_at timestamptz not null default now()
);

-- RLS
alter table enrollments enable row level security;

create policy "Anyone can insert enrollments"
  on enrollments for insert
  with check (true);

create policy "Admins can read all enrollments"
  on enrollments for select
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins can update enrollments"
  on enrollments for update
  using (auth.uid() in (select id from profiles where role = 'admin'));

-- Index
create index if not exists idx_enrollments_status on enrollments(status);
