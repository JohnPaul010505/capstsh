create extension if not exists pg_trgm;

create table met_exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null,
  met_value numeric not null,
  is_ai_estimated boolean not null default false,
  is_verified boolean not null default false,
  confidence numeric,
  created_at timestamptz not null default now(),
  verified_by uuid references profiles(id),
  verified_at timestamptz
);

create index met_exercises_name_trgm_idx
  on met_exercises using gin (name gin_trgm_ops);

alter table met_exercises enable row level security;

create policy "Authenticated users can read met_exercises"
  on met_exercises for select
  using (auth.uid() is not null);

create policy "Admins and trainers can verify met_exercises"
  on met_exercises for update
  using (
    auth.uid() in (
      select id from profiles where role in ('admin', 'trainer')
    )
  );

-- Supabase RPC for similarity search
create or replace function search_met_exercises(
  search_query text,
  similarity_threshold float default 0.4,
  match_limit int default 10
)
returns table (
  id uuid,
  name text,
  category text,
  met_value numeric,
  is_ai_estimated boolean,
  is_verified boolean,
  confidence numeric,
  similarity float
)
language sql stable
as $$
  -- exact/word boundary match
  with exact as (
    select
      id, name, category, met_value,
      is_ai_estimated, is_verified, confidence,
      1.0 as similarity
    from met_exercises
    where name % search_query
       or lower(name) like lower('%' || search_query || '%')
    limit match_limit
  ),
  -- similarity match
  sim as (
    select
      id, name, category, met_value,
      is_ai_estimated, is_verified, confidence,
      similarity(name, search_query) as similarity
    from met_exercises
    where similarity(name, search_query) >= similarity_threshold
      and name not in (select name from exact)
    order by similarity desc
    limit match_limit
  )
  select * from exact
  union all
  select * from sim
  order by similarity desc
  limit match_limit;
$$;