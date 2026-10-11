-- Role marker codes include the member/trainer join month in Manila time.
alter table public.trainer_assignments
  add column if not exists ended_at timestamptz;

-- Preserve each existing sequence while changing the displayed role prefix.
update public.profiles
set code = to_char(created_at at time zone 'Asia/Manila', 'YYYY-MM')
           || '-M' || lpad((substring(code from '([0-9]+)$')::bigint)::text, 3, '0')
where role = 'member'
  and code ~ '^(M[0-9]+|[0-9]{4}-[0-9]{2}-([0-9]+|M[0-9]+))$';

update public.profiles
set code = to_char(created_at at time zone 'Asia/Manila', 'YYYY-MM')
           || '-T' || lpad((substring(code from '([0-9]+)$')::bigint)::text, 4, '0')
where role = 'trainer'
  and code ~ '^(T[0-9]+|[0-9]{4}-[0-9]{2}-([0-9]+|T[0-9]+))$';

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
      new.code := to_char(coalesce(new.created_at, now()) at time zone 'Asia/Manila', 'YYYY-MM')
                  || '-T' || lpad(nextval('uid_trainer_seq')::text, 4, '0');
    when 'member' then
      new.code := to_char(coalesce(new.created_at, now()) at time zone 'Asia/Manila', 'YYYY-MM')
                  || '-M' || lpad(nextval('uid_member_seq')::text, 3, '0');
  end case;
  return new;
end;
$$;

-- Continue each role's sequence after the largest identifier already in use.
select setval(
  'uid_member_seq',
  greatest(
    coalesce((select max(substring(code from '([0-9]+)$')::bigint)
              from public.profiles where role = 'member'), 0),
    (select last_value from uid_member_seq)
  ),
  true
);

select setval(
  'uid_trainer_seq',
  greatest(
    coalesce((select max(substring(code from '([0-9]+)$')::bigint)
              from public.profiles where role = 'trainer'), 0),
    (select last_value from uid_trainer_seq)
  ),
  true
);
