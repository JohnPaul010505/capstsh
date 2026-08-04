-- Add code column to profiles (idempotent)
alter table profiles add column if not exists code text;
create unique index if not exists idx_profiles_code on profiles(code);

-- Sequences for auto-incrementing UIDs per role
create sequence if not exists uid_admin_seq start with 1 increment by 1;
create sequence if not exists uid_trainer_seq start with 1 increment by 1;
create sequence if not exists uid_member_seq start with 1 increment by 1;

-- Trigger function to auto-assign UID on insert
create or replace function public.generate_uid()
returns trigger
language plpgsql
security definer
as $$
begin
  case new.role
    when 'admin' then
      new.code := 'A' || lpad(nextval('uid_admin_seq')::text, 3, '0');
    when 'trainer' then
      new.code := 'T' || lpad(nextval('uid_trainer_seq')::text, 3, '0');
    when 'member' then
      new.code := 'M' || lpad(nextval('uid_member_seq')::text, 3, '0');
  end case;
  return new;
end;
$$;

-- Fire on insert when code isn't manually provided
create trigger auto_uid_trigger
  before insert on profiles
  for each row
  when (new.code is null)
  execute function public.generate_uid();
