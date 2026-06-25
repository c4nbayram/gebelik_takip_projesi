-- ============================================================================
-- Gebelik Takip — "Araçlar" (Tools) feature tables: kick counter, contraction
-- timer, weight tracking, water intake, journal and baby names.
--
-- Run AFTER 0001_init.sql, in the Supabase SQL Editor.
-- Per-user RLS + realtime, same pattern as the core tables.
-- ============================================================================

-- Kick counter sessions ------------------------------------------------------
create table if not exists public.kick_sessions (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references auth.users(id) on delete cascade,
  started_at       timestamptz not null default now(),
  ended_at         timestamptz,
  kick_count       int not null default 0,
  duration_seconds int not null default 0,
  created_at       timestamptz not null default now()
);
create index if not exists kick_sessions_user_idx
  on public.kick_sessions (user_id, started_at desc);

-- Contraction timer entries (intervals computed client-side) -----------------
create table if not exists public.contraction_logs (
  id               bigint generated always as identity primary key,
  user_id          uuid not null references auth.users(id) on delete cascade,
  started_at       timestamptz not null,
  duration_seconds int not null default 0,
  created_at       timestamptz not null default now()
);
create index if not exists contraction_logs_user_idx
  on public.contraction_logs (user_id, started_at desc);

-- Weight tracking ------------------------------------------------------------
create table if not exists public.weight_entries (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  recorded_on date not null default current_date,
  weight_kg   double precision not null,
  week_no     int,
  note        text,
  created_at  timestamptz not null default now(),
  unique (user_id, recorded_on)
);
create index if not exists weight_entries_user_idx
  on public.weight_entries (user_id, recorded_on);

-- Daily water intake ---------------------------------------------------------
create table if not exists public.water_logs (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  day        date not null default current_date,
  glasses    int not null default 0,
  goal       int not null default 8,
  created_at timestamptz not null default now(),
  unique (user_id, day)
);

-- Mood / journal -------------------------------------------------------------
create table if not exists public.journal_entries (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  mood       text,
  note       text,
  created_at timestamptz not null default now()
);
create index if not exists journal_entries_user_idx
  on public.journal_entries (user_id, created_at desc);

-- Favourite baby names -------------------------------------------------------
create table if not exists public.baby_names (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  gender      text,
  is_favorite boolean not null default false,
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists baby_names_user_idx
  on public.baby_names (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- RLS
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'kick_sessions','contraction_logs','weight_entries',
    'water_logs','journal_entries','baby_names'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format('drop policy if exists %I_rw on public.%I;', t, t);
    execute format(
      'create policy %I_rw on public.%I for all using (auth.uid() = user_id) with check (auth.uid() = user_id);',
      t, t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- Realtime
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'kick_sessions','contraction_logs','weight_entries',
    'water_logs','journal_entries','baby_names'
  ]
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I;', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
