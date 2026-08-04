alter table enrollments drop column if exists emergency_contact_name;
alter table enrollments drop column if exists emergency_contact_phone;
alter table enrollments drop column if exists emergency_contact_relation;
alter table enrollments add column if not exists state_updated_at timestamptz default now();

create table if not exists addresses (
  member_id uuid primary key references profiles(id) on delete cascade,
  line1 text not null default '',
  line2 text,
  city text not null default '',
  state text not null default '',
  postal_code text not null default '',
  country text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table addresses enable row level security;

create policy "Users can read own address"
  on addresses for select
  using (auth.uid() = member_id);

create policy "Users can insert own address"
  on addresses for insert
  with check (auth.uid() = member_id);

create policy "Users can update own address"
  on addresses for update
  using (auth.uid() = member_id);

create policy "Trainers can read assigned member addresses"
  on addresses for select
  using (
    exists (
      select 1 from trainer_assignments
      where trainer_assignments.member_id = addresses.member_id
        and trainer_assignments.trainer_id = auth.uid()
        and trainer_assignments.status = 'active'
    )
  );

create policy "Admins all access addresses"
  on addresses for all
  using (public.is_admin());
