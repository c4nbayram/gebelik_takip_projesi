-- ============================================================================
-- Gebelik Takip — Supabase schema, RLS, triggers and the dataset-driven
-- maternal risk classifier (KNN over the verified UCI Maternal Health set).
--
-- Run order:
--   1) This file (0001_init.sql)              -> schema + policies + functions
--   2) ../seed/maternal_reference_seed.sql    -> verified dataset + refresh_model_stats()
--
-- Safe to re-run (idempotent where practical).
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Tables
-- ----------------------------------------------------------------------------

create table if not exists public.profiles (
  id                 uuid primary key references auth.users(id) on delete cascade,
  name               text not null default '',
  email              text not null default '',
  age                int,
  medical_history    text,
  caregiver_role     text,
  baby_name          text,
  city               text,
  baby_birth_date    date,
  last_period_start  date,
  estimated_due_date date,
  planning_baby      boolean not null default false,
  maternal_chronic   text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table if not exists public.week_entries (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  week_no     int not null,
  systolic    double precision,
  diastolic   double precision,
  blood_sugar double precision,
  body_temp   double precision,
  bmi         double precision,
  heart_rate  double precision,
  risk_score  double precision,
  risk_label  text,
  knn_k       int,
  knn_high    int,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, week_no)
);
create index if not exists week_entries_user_idx on public.week_entries (user_id, week_no);

create table if not exists public.appointments (
  id             bigint generated always as identity primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  title          text not null,
  appointment_at timestamptz not null,
  notes          text,
  created_at     timestamptz not null default now()
);
create index if not exists appointments_user_idx on public.appointments (user_id, appointment_at);

create table if not exists public.medications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  name       text not null,
  dosage     text,
  frequency  text,
  start_date date,
  end_date   date,
  times      jsonb not null default '[]'::jsonb,
  notes      text,
  created_at timestamptz not null default now()
);
create index if not exists medications_user_idx on public.medications (user_id);

create table if not exists public.chat_messages (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  message    text not null,
  from_user  boolean not null,
  created_at timestamptz not null default now()
);
create index if not exists chat_messages_user_idx on public.chat_messages (user_id, created_at);

-- The verified reference dataset (UCI Maternal Health Risk; seeded separately).
-- Stored in the app's own units: blood_sugar mg/dL, body_temp Celsius.
create table if not exists public.maternal_reference (
  id          bigint generated always as identity primary key,
  age         double precision not null,
  systolic    double precision not null,
  diastolic   double precision not null,
  blood_sugar double precision not null,
  body_temp   double precision not null,
  heart_rate  double precision not null,
  risk_level  text not null check (risk_level in ('low','mid','high'))
);

-- Single-row table holding normalization stats + class priors derived from the
-- reference set. Recomputed by refresh_model_stats() — this is how the model
-- "re-learns" whenever the verified dataset grows.
create table if not exists public.model_stats (
  id            int primary key default 1,
  feature_means jsonb not null default '{}'::jsonb,
  feature_stds  jsonb not null default '{}'::jsonb,
  class_counts  jsonb not null default '{}'::jsonb,
  sample_size   int not null default 0,
  updated_at    timestamptz not null default now(),
  constraint model_stats_singleton check (id = 1)
);

-- ----------------------------------------------------------------------------
-- Generic helpers / triggers
-- ----------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_profiles_updated on public.profiles;
create trigger trg_profiles_updated before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists trg_week_entries_updated on public.week_entries;
create trigger trg_week_entries_updated before update on public.week_entries
  for each row execute function public.set_updated_at();

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.email, '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- Model: stats refresh + KNN classifier over the verified dataset
-- ----------------------------------------------------------------------------

create or replace function public.refresh_model_stats()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_means  jsonb;
  v_stds   jsonb;
  v_counts jsonb;
  v_n      int;
begin
  select count(*) into v_n from public.maternal_reference;

  select jsonb_build_object(
    'age',         avg(age),
    'systolic',    avg(systolic),
    'diastolic',   avg(diastolic),
    'blood_sugar', avg(blood_sugar),
    'body_temp',   avg(body_temp),
    'heart_rate',  avg(heart_rate)
  ) into v_means from public.maternal_reference;

  -- nullif(...,0) so a degenerate (zero-variance) feature can't divide by zero.
  select jsonb_build_object(
    'age',         nullif(stddev_pop(age), 0),
    'systolic',    nullif(stddev_pop(systolic), 0),
    'diastolic',   nullif(stddev_pop(diastolic), 0),
    'blood_sugar', nullif(stddev_pop(blood_sugar), 0),
    'body_temp',   nullif(stddev_pop(body_temp), 0),
    'heart_rate',  nullif(stddev_pop(heart_rate), 0)
  ) into v_stds from public.maternal_reference;

  select jsonb_object_agg(risk_level, c) into v_counts
  from (select risk_level, count(*) c from public.maternal_reference group by risk_level) t;

  insert into public.model_stats (id, feature_means, feature_stds, class_counts, sample_size, updated_at)
  values (1, coalesce(v_means,'{}'::jsonb), coalesce(v_stds,'{}'::jsonb), coalesce(v_counts,'{}'::jsonb), v_n, now())
  on conflict (id) do update set
    feature_means = excluded.feature_means,
    feature_stds  = excluded.feature_stds,
    class_counts  = excluded.class_counts,
    sample_size   = excluded.sample_size,
    updated_at    = now();
end;
$$;

-- KNN classifier: z-score-normalized Euclidean distance over the 6 features
-- shared with the UCI dataset (age + 5 vitals). Returns label, calibrated
-- score (0..1) and the neighbour breakdown for transparency.
create or replace function public.classify_maternal_risk(
  p_age        double precision,
  p_systolic   double precision,
  p_diastolic  double precision,
  p_bs         double precision,
  p_body_temp  double precision,
  p_heart_rate double precision,
  p_k          int default 15
)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_stds   jsonb;
  v_high   int;
  v_mid    int;
  v_low    int;
  v_total  int;
  v_avg    double precision;
  v_score  double precision;
  v_label  text;
begin
  select feature_stds into v_stds from public.model_stats where id = 1;
  if v_stds is null or v_stds = '{}'::jsonb then
    perform public.refresh_model_stats();
    select feature_stds into v_stds from public.model_stats where id = 1;
  end if;

  with s as (
    select
      coalesce((v_stds->>'age')::float, 1)         as s_age,
      coalesce((v_stds->>'systolic')::float, 1)    as s_sys,
      coalesce((v_stds->>'diastolic')::float, 1)   as s_dia,
      coalesce((v_stds->>'blood_sugar')::float, 1) as s_bs,
      coalesce((v_stds->>'body_temp')::float, 1)   as s_bt,
      coalesce((v_stds->>'heart_rate')::float, 1)  as s_hr
  ),
  neighbors as (
    select r.risk_level,
      sqrt(
        power((r.age         - p_age)        / s.s_age, 2) +
        power((r.systolic    - p_systolic)   / s.s_sys, 2) +
        power((r.diastolic   - p_diastolic)  / s.s_dia, 2) +
        power((r.blood_sugar - p_bs)         / s.s_bs , 2) +
        power((r.body_temp   - p_body_temp)  / s.s_bt , 2) +
        power((r.heart_rate  - p_heart_rate) / s.s_hr , 2)
      ) as dist
    from public.maternal_reference r cross join s
    order by dist asc
    limit greatest(coalesce(p_k, 15), 1)
  )
  select
    count(*) filter (where risk_level = 'high'),
    count(*) filter (where risk_level = 'mid'),
    count(*) filter (where risk_level = 'low'),
    count(*),
    avg(dist)
  into v_high, v_mid, v_low, v_total, v_avg
  from neighbors;

  if coalesce(v_total, 0) = 0 then
    return jsonb_build_object(
      'risk_label','low','risk_score',0.05,'k',0,
      'high_count',0,'mid_count',0,'low_count',0,'avg_distance',0
    );
  end if;

  -- Calibrated severity: high=1.0, mid=0.5, low=0.0 averaged over the k neighbours.
  v_score := (v_high * 1.0 + v_mid * 0.5 + v_low * 0.0) / v_total::float;
  v_score := least(greatest(v_score, 0.02), 0.98);

  if v_high >= v_mid and v_high >= v_low then
    v_label := 'high';
  elsif v_mid >= v_low then
    v_label := 'mid';
  else
    v_label := 'low';
  end if;

  return jsonb_build_object(
    'risk_label',   v_label,
    'risk_score',   round(v_score::numeric, 4),
    'k',            v_total,
    'high_count',   v_high,
    'mid_count',    v_mid,
    'low_count',    v_low,
    'avg_distance', round(coalesce(v_avg, 0)::numeric, 4)
  );
end;
$$;

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

alter table public.profiles          enable row level security;
alter table public.week_entries      enable row level security;
alter table public.appointments      enable row level security;
alter table public.medications       enable row level security;
alter table public.chat_messages     enable row level security;
alter table public.maternal_reference enable row level security;
alter table public.model_stats       enable row level security;

-- profiles: a user owns the row whose id == their auth uid
drop policy if exists profiles_rw on public.profiles;
create policy profiles_rw on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- per-user data tables
drop policy if exists week_entries_rw on public.week_entries;
create policy week_entries_rw on public.week_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists appointments_rw on public.appointments;
create policy appointments_rw on public.appointments
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists medications_rw on public.medications;
create policy medications_rw on public.medications
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists chat_messages_rw on public.chat_messages;
create policy chat_messages_rw on public.chat_messages
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- reference + stats: read-only to signed-in users (writes only via SECURITY DEFINER fns)
drop policy if exists reference_read on public.maternal_reference;
create policy reference_read on public.maternal_reference
  for select using (auth.uid() is not null);

drop policy if exists model_stats_read on public.model_stats;
create policy model_stats_read on public.model_stats
  for select using (auth.uid() is not null);

-- ----------------------------------------------------------------------------
-- Grants
-- ----------------------------------------------------------------------------

grant execute on function public.classify_maternal_risk(
  double precision, double precision, double precision,
  double precision, double precision, double precision, int
) to anon, authenticated;

grant execute on function public.refresh_model_stats() to authenticated;

-- ----------------------------------------------------------------------------
-- Realtime: let clients subscribe to their own rows changing live.
-- ----------------------------------------------------------------------------

do $$
begin
  alter publication supabase_realtime add table public.week_entries;
exception when duplicate_object then null; end $$;
do $$
begin
  alter publication supabase_realtime add table public.appointments;
exception when duplicate_object then null; end $$;
do $$
begin
  alter publication supabase_realtime add table public.medications;
exception when duplicate_object then null; end $$;
do $$
begin
  alter publication supabase_realtime add table public.chat_messages;
exception when duplicate_object then null; end $$;
