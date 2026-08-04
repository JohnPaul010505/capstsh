create or replace function public.get_email_by_code(p_code text)
returns text
language sql
security definer
stable
as $$
  select email from public.profiles where code = p_code;
$$;

grant execute on function public.get_email_by_code(text) to anon, authenticated;

create policy "Anon can read profile codes"
  on profiles for select
  using (true);
