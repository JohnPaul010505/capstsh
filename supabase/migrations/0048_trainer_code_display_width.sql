-- Trainer codes use a three-digit minimum suffix (for example, T002).
-- Keep existing identifiers unique while removing the redundant leading zero.
update public.profiles
set code = to_char(created_at at time zone 'Asia/Manila', 'YYYY-MM')
           || '-T' || case
                when substring(code from '([0-9]+)$')::bigint < 1000
                  then lpad((substring(code from '([0-9]+)$')::bigint)::text, 3, '0')
                else (substring(code from '([0-9]+)$')::bigint)::text
              end
where role = 'trainer'
  and code ~ '^[0-9]{4}-[0-9]{2}-T[0-9]+$';

-- New trainers must receive codes in the same format as existing trainers.
create or replace function public.generate_uid()
returns trigger
language plpgsql
security definer
as $$
declare
  trainer_number bigint;
begin
  case new.role
    when 'admin' then
      new.code := 'A' || lpad(nextval('uid_admin_seq')::text, 3, '0');
    when 'trainer' then
      trainer_number := nextval('uid_trainer_seq');
      new.code := to_char(coalesce(new.created_at, now()) at time zone 'Asia/Manila', 'YYYY-MM')
                  || '-T' || case
                       when trainer_number < 1000 then lpad(trainer_number::text, 3, '0')
                       else trainer_number::text
                     end;
    when 'member' then
      new.code := to_char(coalesce(new.created_at, now()) at time zone 'Asia/Manila', 'YYYY-MM')
                  || '-M' || lpad(nextval('uid_member_seq')::text, 3, '0');
  end case;
  return new;
end;
$$;
