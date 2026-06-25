-- GEBELIK TAKIP - COMPLETE SUPABASE SETUP
-- Run this file once from top to bottom in Supabase SQL Editor.

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0001_init.sql
-- ============================================================================
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


-- END FILE: supabase/migrations/0001_init.sql

-- ============================================================================
-- BEGIN FILE: supabase/seed/maternal_reference_seed.sql
-- ============================================================================
-- Auto-generated from UCI Maternal Health Risk Data Set (n=1012, dropped=2).
-- Source: https://archive.ics.uci.edu/dataset/863/maternal+health+risk
-- Unit conversions applied to match the app's units:
--   blood_sugar: mmol/L -> mg/dL (x18.0182)
--   body_temp:   Fahrenheit -> Celsius ((F-32)*5/9)
-- Cleaning: rows with heart_rate < 30 bpm removed (data-entry errors).
-- Run this AFTER 0001_init.sql.

truncate table public.maternal_reference;

insert into public.maternal_reference
  (age, systolic, diastolic, blood_sugar, body_temp, heart_rate, risk_level)
values
(25,130,80,270,36.7,86,'high'),
(35,140,90,234,36.7,70,'high'),
(29,90,70,144,37.8,80,'high'),
(30,140,85,126,36.7,70,'high'),
(35,120,60,110,36.7,76,'low'),
(23,140,80,126,36.7,70,'high'),
(23,130,70,126,36.7,78,'mid'),
(35,85,60,198,38.9,86,'high'),
(32,120,90,124,36.7,70,'mid'),
(42,130,80,324,36.7,70,'high'),
(23,90,60,126,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(25,110,89,126,36.7,77,'low'),
(20,120,75,126,37.8,70,'mid'),
(48,120,80,198,36.7,88,'mid'),
(15,120,80,126,36.7,70,'low'),
(50,140,90,270,36.7,90,'high'),
(25,140,100,126,36.7,80,'high'),
(30,120,80,124,38.3,76,'mid'),
(10,70,50,124,36.7,70,'low'),
(40,140,100,324,36.7,90,'high'),
(50,140,80,121,36.7,70,'mid'),
(21,90,65,135,36.7,76,'low'),
(18,90,60,135,36.7,70,'low'),
(21,120,80,135,36.7,76,'low'),
(16,100,70,130,36.7,80,'low'),
(19,120,75,130,36.7,66,'low'),
(22,100,65,130,36.7,70,'low'),
(49,120,90,130,36.7,77,'low'),
(28,90,60,130,36.7,82,'low'),
(20,100,90,128,36.7,88,'low'),
(23,100,85,128,36.7,66,'low'),
(22,120,90,128,36.7,82,'low'),
(21,120,80,128,36.7,77,'low'),
(21,75,50,110,36.7,70,'low'),
(12,95,60,110,38.9,60,'low'),
(60,120,80,110,36.7,75,'low'),
(55,100,65,110,36.7,66,'low'),
(45,120,95,110,36.7,66,'low'),
(35,100,70,110,36.7,66,'low'),
(22,120,85,110,36.7,88,'low'),
(23,120,90,110,36.7,60,'low'),
(25,90,70,110,36.7,80,'low'),
(30,120,80,110,36.7,70,'low'),
(23,120,90,110,36.7,70,'low'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(23,90,60,135,36.7,76,'low'),
(15,76,49,135,36.7,77,'low'),
(15,120,80,126,36.7,70,'low'),
(25,120,80,126,36.7,66,'low'),
(22,100,65,126,36.7,80,'low'),
(35,100,70,126,36.7,60,'low'),
(19,120,85,126,36.7,60,'low'),
(60,90,65,126,36.7,77,'low'),
(23,120,90,121,36.7,70,'low'),
(32,120,90,115,36.7,70,'low'),
(42,120,80,115,36.7,70,'low'),
(23,90,60,115,36.7,76,'low'),
(15,76,49,115,36.7,77,'low'),
(15,120,80,130,36.7,70,'low'),
(15,80,60,126,36.7,80,'low'),
(12,95,60,130,36.7,77,'low'),
(29,90,70,121,36.7,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,121,36.7,78,'mid'),
(17,85,60,162,38.9,86,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,110,60,126,37.8,70,'mid'),
(32,120,65,108,38.3,76,'mid'),
(26,85,60,108,38.3,86,'mid'),
(29,130,70,139,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(54,130,70,216,36.7,67,'mid'),
(44,120,90,288,36.7,80,'mid'),
(23,130,70,124,36.7,70,'mid'),
(22,85,60,124,36.7,76,'mid'),
(55,120,90,216,36.7,70,'mid'),
(35,120,80,124,36.7,78,'mid'),
(21,90,60,124,36.7,86,'mid'),
(16,90,65,124,36.7,76,'mid'),
(33,115,65,126,36.7,70,'mid'),
(12,95,60,124,36.7,65,'mid'),
(28,120,90,124,36.7,70,'mid'),
(21,90,65,124,36.7,76,'mid'),
(18,90,60,124,36.7,70,'mid'),
(21,120,80,124,36.7,76,'mid'),
(16,100,70,124,36.7,80,'mid'),
(19,120,75,124,36.7,66,'mid'),
(23,100,85,124,36.7,66,'mid'),
(22,120,90,141,36.7,82,'mid'),
(60,120,85,270,36.7,60,'mid'),
(13,90,65,141,38.3,80,'mid'),
(23,120,90,141,36.7,60,'mid'),
(28,115,60,141,38.3,86,'mid'),
(50,120,80,141,36.7,70,'mid'),
(29,130,70,141,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(19,120,85,141,36.7,60,'mid'),
(60,90,65,123,36.7,77,'mid'),
(55,120,90,123,36.7,66,'mid'),
(25,120,80,123,36.7,66,'mid'),
(48,140,90,270,36.7,90,'high'),
(25,140,100,123,36.7,80,'high'),
(23,140,90,123,36.7,70,'high'),
(34,85,60,198,38.9,86,'high'),
(50,140,90,270,36.7,90,'high'),
(25,140,100,123,36.7,80,'high'),
(42,140,100,324,36.7,90,'high'),
(32,140,100,142,36.7,78,'high'),
(50,140,95,306,36.7,60,'high'),
(38,135,60,142,38.3,86,'high'),
(39,90,70,162,36.7,80,'high'),
(30,140,100,270,36.7,70,'high'),
(63,140,90,270,36.7,90,'high'),
(25,140,100,142,36.7,80,'high'),
(30,120,80,142,38.3,76,'high'),
(55,140,100,324,36.7,90,'high'),
(32,140,100,142,36.7,78,'high'),
(30,140,100,270,36.7,70,'high'),
(48,120,80,198,36.7,88,'high'),
(49,140,90,270,36.7,90,'high'),
(25,140,100,135,36.7,80,'high'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(35,140,100,135,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(55,140,95,342,36.7,77,'high'),
(29,120,70,162,36.7,80,'high'),
(48,120,80,198,36.7,88,'high'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(35,140,100,135,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(22,90,60,135,38.9,60,'high'),
(40,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'high'),
(18,120,80,124,38.9,76,'mid'),
(32,140,100,124,36.7,78,'high'),
(17,90,60,124,38.3,76,'mid'),
(17,90,63,124,38.3,70,'mid'),
(25,120,90,121,38.3,80,'mid'),
(17,120,80,121,38.9,76,'mid'),
(14,90,65,126,38.3,70,'high'),
(15,80,60,121,36.7,80,'low'),
(15,100,65,121,36.7,76,'low'),
(12,95,60,121,36.7,77,'low'),
(37,120,90,198,36.7,88,'high'),
(18,100,70,121,36.7,76,'low'),
(21,100,85,121,36.7,70,'low'),
(17,110,75,216,38.3,76,'high'),
(25,120,90,135,36.7,80,'low'),
(23,85,65,135,36.7,70,'low'),
(12,95,60,135,36.7,65,'low'),
(28,120,90,135,36.7,70,'low'),
(40,120,90,216,36.7,80,'high'),
(55,129,85,135,36.7,88,'low'),
(25,100,90,135,36.7,76,'low'),
(35,120,80,135,36.7,80,'low'),
(21,90,65,135,36.7,76,'low'),
(18,90,60,135,36.7,70,'low'),
(21,120,80,135,36.7,76,'low'),
(16,100,70,130,36.7,80,'low'),
(19,120,75,130,36.7,66,'low'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(22,100,65,130,36.7,70,'low'),
(49,120,90,130,36.7,77,'low'),
(28,90,60,130,36.7,82,'low'),
(12,90,60,142,38.9,66,'high'),
(20,100,90,128,36.7,88,'low'),
(23,100,85,128,36.7,66,'low'),
(22,120,90,128,36.7,82,'low'),
(21,120,80,128,36.7,77,'low'),
(35,140,100,144,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(21,75,50,110,36.7,70,'low'),
(12,95,60,110,38.9,60,'low'),
(60,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'high'),
(60,120,80,110,36.7,75,'low'),
(55,100,65,110,36.7,66,'low'),
(45,120,95,110,36.7,66,'low'),
(35,100,70,110,36.7,66,'low'),
(22,120,85,110,36.7,88,'low'),
(13,90,65,142,38.3,80,'mid'),
(23,120,90,110,36.7,60,'low'),
(17,90,65,110,39.4,67,'high'),
(28,83,60,144,38.3,86,'high'),
(50,120,80,270,36.7,70,'high'),
(25,90,70,110,36.7,80,'low'),
(30,120,80,110,36.7,70,'low'),
(31,120,60,110,36.7,76,'mid'),
(23,120,90,110,36.7,70,'low'),
(29,130,70,110,36.7,78,'mid'),
(17,85,60,162,38.9,86,'high'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(23,90,60,135,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,135,36.7,77,'low'),
(33,120,75,180,36.7,70,'high'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,126,36.7,70,'low'),
(25,120,80,126,36.7,66,'low'),
(22,100,65,126,36.7,80,'low'),
(50,140,95,306,36.7,60,'high'),
(35,100,70,126,36.7,60,'low'),
(19,120,85,126,36.7,60,'low'),
(60,90,65,126,36.7,77,'low'),
(28,85,60,162,38.3,86,'mid'),
(50,140,80,121,36.7,70,'mid'),
(29,90,70,121,36.7,80,'mid'),
(30,140,100,270,36.7,70,'high'),
(31,120,60,110,36.7,76,'mid'),
(23,120,90,121,36.7,70,'low'),
(29,130,70,121,36.7,78,'mid'),
(17,85,60,162,38.9,86,'mid'),
(32,120,90,115,36.7,70,'low'),
(42,120,80,115,36.7,70,'low'),
(23,90,60,115,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,115,36.7,77,'low'),
(29,120,75,130,37.8,70,'high'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,130,36.7,70,'low'),
(50,140,90,270,36.7,77,'high'),
(25,140,100,130,36.7,80,'high'),
(55,140,80,130,38.3,76,'high'),
(20,110,60,126,37.8,70,'mid'),
(40,140,100,324,36.7,77,'high'),
(28,120,80,162,38.9,76,'high'),
(32,140,100,144,36.7,70,'high'),
(17,90,60,198,38.3,78,'high'),
(17,90,63,144,38.3,70,'high'),
(25,120,90,216,38.3,80,'high'),
(17,120,80,126,38.9,76,'high'),
(19,90,65,198,38.3,70,'high'),
(15,80,60,126,36.7,80,'low'),
(32,120,65,108,38.3,76,'mid'),
(12,95,60,130,36.7,77,'low'),
(37,120,90,198,36.7,88,'high'),
(18,100,70,123,36.7,76,'low'),
(21,100,85,124,36.7,70,'low'),
(17,110,75,234,38.3,76,'high'),
(25,120,90,270,36.7,80,'high'),
(10,85,65,124,36.7,70,'low'),
(12,95,60,124,36.7,65,'low'),
(28,120,90,124,36.7,70,'low'),
(40,120,90,124,36.7,80,'low'),
(55,110,85,124,36.7,88,'low'),
(25,100,90,124,36.7,76,'low'),
(35,120,80,124,36.7,80,'low'),
(21,90,65,124,36.7,76,'low'),
(18,90,60,124,36.7,70,'low'),
(21,120,80,124,36.7,76,'low'),
(16,100,70,124,36.7,80,'low'),
(19,120,75,124,36.7,66,'low'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(22,100,65,124,36.7,70,'low'),
(49,120,90,124,36.7,77,'low'),
(28,90,60,124,36.7,82,'low'),
(12,90,60,144,38.9,66,'high'),
(20,100,90,126,36.7,88,'low'),
(23,100,85,126,36.7,66,'low'),
(22,120,90,126,36.7,82,'low'),
(21,120,80,126,36.7,77,'low'),
(35,140,100,162,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(21,75,50,139,36.7,60,'low'),
(12,90,60,198,38.9,60,'high'),
(60,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,76,'high'),
(60,120,80,139,36.7,75,'low'),
(55,100,65,139,36.7,66,'low'),
(45,120,95,139,36.7,66,'low'),
(35,100,70,139,36.7,66,'low'),
(22,120,85,139,36.7,88,'low'),
(13,90,65,162,38.3,80,'high'),
(23,120,90,139,36.7,60,'low'),
(17,90,65,139,39.4,67,'high'),
(26,85,60,108,38.3,86,'mid'),
(50,120,80,139,36.7,70,'low'),
(19,90,70,139,36.7,80,'low'),
(30,120,80,139,36.7,70,'low'),
(31,120,60,110,36.7,76,'low'),
(23,120,80,139,36.7,70,'low'),
(29,130,70,139,36.7,78,'mid'),
(17,85,60,114,38.9,86,'high'),
(32,120,90,139,36.7,70,'low'),
(42,120,80,139,36.7,70,'low'),
(23,90,60,139,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,75,49,139,36.7,77,'low'),
(40,120,75,139,36.7,70,'high'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,139,36.7,70,'low'),
(25,120,80,139,36.7,66,'low'),
(22,100,65,124,36.7,80,'low'),
(12,120,95,124,36.7,60,'low'),
(35,100,70,124,36.7,60,'low'),
(19,120,85,124,36.7,60,'low'),
(60,90,65,124,36.7,77,'low'),
(55,120,90,124,36.7,76,'low'),
(35,90,65,124,36.7,75,'low'),
(51,85,60,124,36.7,66,'low'),
(62,120,80,124,36.7,66,'low'),
(25,90,70,124,36.7,66,'low'),
(21,120,80,124,36.7,88,'low'),
(22,120,60,270,36.7,80,'high'),
(55,120,90,324,36.7,60,'high'),
(54,130,70,216,36.7,67,'mid'),
(35,85,60,342,36.7,86,'high'),
(43,120,90,324,36.7,70,'high'),
(12,120,80,124,36.7,80,'low'),
(65,90,60,124,36.7,70,'low'),
(60,120,80,124,36.7,76,'low'),
(25,120,90,124,36.7,70,'low'),
(22,90,65,124,36.7,78,'low'),
(66,85,60,124,36.7,86,'low'),
(56,120,80,234,36.7,70,'high'),
(35,90,70,124,36.7,70,'low'),
(43,120,80,270,36.7,76,'high'),
(35,120,60,124,36.7,70,'low'),
(44,120,90,288,36.7,80,'mid'),
(23,130,70,124,36.7,70,'mid'),
(22,85,60,124,36.7,76,'mid'),
(55,120,90,216,36.7,70,'mid'),
(35,120,80,124,36.7,78,'mid'),
(21,90,60,124,36.7,86,'mid'),
(45,120,80,124,39.4,70,'low'),
(70,85,60,124,38.9,70,'low'),
(65,120,90,124,39.4,76,'low'),
(55,120,80,124,38.9,80,'low'),
(45,90,60,324,38.3,70,'high'),
(22,120,80,124,39.4,76,'low'),
(16,90,65,124,36.7,76,'mid'),
(12,95,60,124,36.7,77,'low'),
(37,120,90,198,36.7,88,'high'),
(18,100,70,124,36.7,76,'low'),
(21,100,85,124,36.7,70,'low'),
(17,110,75,124,38.3,76,'high'),
(25,120,90,124,36.7,80,'low'),
(33,115,65,126,36.7,70,'mid'),
(12,95,60,124,36.7,65,'mid'),
(28,120,90,124,36.7,70,'mid'),
(40,120,90,124,36.7,80,'high'),
(55,110,85,124,36.7,88,'high'),
(25,100,90,124,36.7,76,'high'),
(35,120,80,124,36.7,80,'high'),
(21,90,65,124,36.7,76,'mid'),
(18,90,60,124,36.7,70,'mid'),
(21,120,80,124,36.7,76,'mid'),
(16,100,70,124,36.7,80,'mid'),
(19,120,75,124,36.7,66,'mid'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(23,100,85,124,36.7,66,'mid'),
(22,120,90,141,36.7,82,'mid'),
(21,120,80,141,36.7,77,'low'),
(35,140,100,141,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(21,75,50,141,36.7,60,'low'),
(12,90,60,141,38.9,60,'high'),
(60,120,85,270,36.7,60,'mid'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'high'),
(60,120,80,141,36.7,75,'high'),
(55,100,65,141,36.7,66,'low'),
(45,120,95,141,36.7,66,'low'),
(35,100,70,141,36.7,66,'low'),
(22,120,85,141,36.7,88,'low'),
(13,90,65,141,38.3,80,'mid'),
(23,120,90,141,36.7,60,'mid'),
(17,90,65,141,39.4,67,'high'),
(28,115,60,141,38.3,86,'mid'),
(50,120,80,141,36.7,70,'mid'),
(19,90,70,141,36.7,80,'low'),
(30,120,80,141,36.7,70,'low'),
(31,120,60,110,36.7,76,'low'),
(23,120,70,141,36.7,70,'low'),
(29,130,70,141,36.7,78,'mid'),
(17,85,69,141,38.9,86,'high'),
(32,120,90,141,36.7,70,'low'),
(42,120,80,141,36.7,70,'low'),
(23,90,60,141,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,141,36.7,77,'low'),
(20,120,75,141,36.7,70,'low'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,141,36.7,70,'low'),
(25,120,80,141,36.7,66,'low'),
(22,100,65,141,36.7,80,'low'),
(12,120,95,141,36.7,60,'low'),
(35,100,70,141,36.7,60,'low'),
(19,120,85,141,36.7,60,'mid'),
(60,90,65,123,36.7,77,'mid'),
(55,120,90,123,36.7,66,'mid'),
(25,120,80,123,36.7,66,'mid'),
(22,100,65,123,36.7,88,'low'),
(12,120,95,123,36.7,60,'mid'),
(35,100,70,123,36.7,60,'mid'),
(19,120,90,123,36.7,60,'mid'),
(60,90,65,123,36.7,77,'mid'),
(55,120,90,123,36.7,78,'low'),
(50,130,80,288,38.9,76,'mid'),
(27,120,90,123,38.9,68,'mid'),
(60,140,90,216,36.7,77,'high'),
(55,100,70,123,38.3,80,'mid'),
(60,140,80,288,36.7,66,'high'),
(12,120,90,123,36.7,80,'mid'),
(17,140,100,123,39.4,80,'high'),
(60,120,80,123,36.7,77,'mid'),
(22,100,65,123,36.7,88,'low'),
(36,140,100,123,38.9,76,'high'),
(22,90,60,123,36.7,77,'low'),
(25,120,100,123,36.7,60,'mid'),
(35,100,60,270,36.7,80,'high'),
(40,140,100,234,38.3,66,'high'),
(27,120,70,123,36.7,77,'low'),
(36,140,100,123,38.9,76,'high'),
(22,90,60,123,36.7,77,'mid'),
(25,120,100,123,36.7,60,'low'),
(35,100,60,270,36.7,80,'high'),
(40,140,100,234,38.3,66,'high'),
(27,120,70,123,36.7,77,'low'),
(27,120,70,123,36.7,77,'low'),
(65,130,80,270,36.7,86,'high'),
(35,140,80,234,36.7,70,'high'),
(29,90,70,180,36.7,80,'high'),
(30,120,80,123,36.7,70,'mid'),
(35,120,60,110,36.7,76,'mid'),
(23,140,90,123,36.7,70,'high'),
(23,130,70,123,36.7,78,'mid'),
(35,85,60,198,38.9,86,'high'),
(32,120,90,123,36.7,70,'low'),
(43,130,80,324,36.7,70,'mid'),
(23,99,60,123,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,123,36.7,77,'low'),
(30,120,75,123,36.7,70,'mid'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,123,36.7,70,'low'),
(48,140,90,270,36.7,90,'high'),
(25,140,100,123,36.7,80,'high'),
(29,100,70,123,36.7,80,'low'),
(32,120,80,123,36.7,70,'mid'),
(35,120,60,110,36.7,76,'low'),
(23,140,90,123,36.7,70,'high'),
(23,130,70,123,36.7,78,'mid'),
(34,85,60,198,38.9,86,'high'),
(32,120,90,123,36.7,70,'low'),
(42,130,80,324,36.7,70,'mid'),
(23,90,60,123,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,123,36.7,77,'low'),
(20,120,75,123,36.7,70,'low'),
(48,120,80,198,36.7,88,'low'),
(15,120,80,123,36.7,70,'low'),
(50,140,90,270,36.7,90,'high'),
(25,140,100,123,36.7,80,'high'),
(30,120,80,123,38.3,76,'low'),
(31,110,90,123,37.8,70,'mid'),
(42,140,100,324,36.7,90,'high'),
(18,120,80,123,38.9,76,'low'),
(32,140,100,142,36.7,78,'high'),
(17,90,60,142,38.3,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,142,36.7,77,'low'),
(19,120,75,142,36.7,70,'low'),
(48,120,80,198,36.7,88,'low'),
(15,120,80,142,36.7,70,'low'),
(25,120,80,142,36.7,66,'mid'),
(22,100,65,142,36.7,80,'low'),
(50,140,95,306,36.7,60,'high'),
(35,100,70,142,36.7,60,'low'),
(19,120,85,142,36.7,60,'low'),
(60,90,65,142,36.7,77,'low'),
(38,135,60,142,38.3,86,'high'),
(50,120,80,142,36.7,70,'low'),
(39,90,70,162,36.7,80,'high'),
(30,140,100,270,36.7,70,'high'),
(31,120,60,110,36.7,76,'mid'),
(23,120,90,142,36.7,70,'mid'),
(29,130,70,142,36.7,78,'mid'),
(17,85,60,142,38.9,86,'low'),
(32,120,90,142,36.7,70,'low'),
(42,120,80,142,36.7,70,'low'),
(23,90,60,142,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,76,49,142,36.7,77,'low'),
(48,120,80,198,36.7,88,'mid'),
(15,120,80,142,36.7,70,'low'),
(63,140,90,270,36.7,90,'high'),
(25,140,100,142,36.7,80,'high'),
(30,120,80,142,38.3,76,'high'),
(17,70,50,142,36.7,70,'low'),
(55,140,100,324,36.7,90,'high'),
(18,120,80,142,38.9,76,'mid'),
(32,140,100,142,36.7,78,'high'),
(17,90,60,135,38.3,76,'low'),
(17,90,63,135,38.3,70,'low'),
(25,120,90,135,38.3,80,'low'),
(17,120,80,135,38.9,76,'low'),
(19,90,65,135,38.3,70,'low'),
(15,80,60,135,36.7,80,'low'),
(60,90,65,135,36.7,77,'low'),
(18,85,60,135,38.3,86,'mid'),
(50,120,80,135,36.7,70,'low'),
(19,90,70,135,36.7,80,'low'),
(30,140,100,270,36.7,70,'high'),
(31,120,60,110,36.7,76,'low'),
(23,120,90,135,36.7,70,'low'),
(29,130,70,135,36.7,78,'mid'),
(17,85,60,135,38.9,86,'low'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(42,90,60,135,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,78,49,135,36.7,77,'low'),
(23,120,75,144,36.7,70,'mid'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,135,36.7,70,'mid'),
(49,140,90,270,36.7,90,'high'),
(25,140,100,135,36.7,80,'high'),
(30,120,80,135,38.3,76,'mid'),
(16,70,50,135,37.8,70,'low'),
(16,100,70,135,36.7,80,'low'),
(19,120,75,135,36.7,66,'low'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(22,100,65,135,36.7,70,'low'),
(49,120,90,135,36.7,77,'low'),
(28,90,60,135,36.7,82,'low'),
(12,90,60,135,38.9,66,'low'),
(20,100,90,135,36.7,88,'low'),
(23,100,85,135,36.7,66,'low'),
(22,120,90,135,36.7,82,'low'),
(21,120,80,135,36.7,77,'low'),
(35,140,100,135,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'mid'),
(21,75,50,135,36.7,60,'low'),
(12,90,60,135,38.9,60,'low'),
(60,120,85,270,36.7,60,'mid'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'mid'),
(60,120,80,135,36.7,75,'low'),
(55,100,65,135,36.7,66,'low'),
(45,120,95,135,36.7,66,'low'),
(35,100,70,135,36.7,66,'low'),
(22,120,85,135,36.7,88,'low'),
(13,90,65,135,38.3,80,'low'),
(23,120,90,135,36.7,60,'low'),
(17,90,65,135,39.4,67,'low'),
(28,115,60,135,38.3,86,'mid'),
(59,120,80,135,36.7,70,'low'),
(29,120,70,162,36.7,80,'high'),
(23,120,80,135,36.7,70,'low'),
(31,120,60,110,36.7,76,'mid'),
(23,120,80,135,36.7,70,'mid'),
(29,130,70,135,36.7,78,'mid'),
(17,85,60,135,38.9,86,'low'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(23,90,60,135,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,78,49,135,36.7,77,'low'),
(20,120,75,135,36.7,70,'low'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,135,36.7,70,'low'),
(24,120,80,135,36.7,66,'low'),
(16,100,70,135,36.7,80,'low'),
(19,120,76,135,36.7,66,'low'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(22,100,65,135,36.7,70,'mid'),
(49,120,90,135,36.7,77,'mid'),
(28,90,60,135,36.7,82,'mid'),
(12,90,60,135,38.9,66,'mid'),
(20,100,90,135,36.7,88,'mid'),
(23,100,85,135,36.7,66,'mid'),
(22,120,90,135,36.7,82,'mid'),
(21,120,80,135,36.7,77,'mid'),
(35,140,100,135,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(21,75,50,135,36.7,60,'low'),
(22,90,60,135,38.9,60,'high'),
(40,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'high'),
(60,120,80,135,36.7,75,'mid'),
(40,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'mid'),
(41,120,80,135,36.7,75,'low'),
(55,100,65,135,36.7,66,'low'),
(45,120,95,135,36.7,66,'low'),
(35,100,70,135,36.7,66,'low'),
(22,120,85,135,36.7,88,'low'),
(13,90,65,135,38.3,80,'high'),
(23,120,90,135,36.7,60,'low'),
(17,90,65,135,39.4,67,'mid'),
(27,135,60,135,38.3,86,'high'),
(50,120,80,270,36.7,70,'high'),
(34,110,70,126,36.7,80,'high'),
(32,120,80,135,36.7,70,'low'),
(31,120,60,110,36.7,76,'low'),
(23,120,90,135,36.7,70,'low'),
(29,130,70,135,36.7,78,'mid'),
(17,85,60,135,38.3,86,'high'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(23,90,60,135,36.7,76,'low'),
(19,120,80,126,36.7,70,'mid'),
(15,76,49,135,36.7,77,'low'),
(20,120,76,135,36.7,70,'low'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,135,36.7,70,'low'),
(24,120,80,135,36.7,66,'low'),
(22,100,65,216,36.7,80,'high'),
(50,140,95,306,36.7,60,'high'),
(35,100,70,198,36.7,60,'high'),
(19,120,85,162,36.7,60,'mid'),
(30,90,65,144,36.7,77,'mid'),
(28,85,60,162,38.3,86,'mid'),
(50,130,80,270,36.7,86,'high'),
(35,140,90,234,36.7,70,'high'),
(29,90,70,198,37.8,80,'high'),
(19,120,60,126,36.9,70,'low'),
(46,140,100,216,37.2,90,'high'),
(28,95,60,180,38.3,86,'high'),
(50,120,80,126,36.7,70,'mid'),
(39,110,70,142,36.7,80,'mid'),
(25,140,100,270,37,70,'high'),
(31,120,60,110,36.7,76,'low'),
(23,120,85,144,36.7,70,'low'),
(29,130,70,144,36.7,78,'mid'),
(17,90,60,162,38.9,86,'mid'),
(32,120,90,126,37.8,70,'mid'),
(42,120,90,162,36.7,70,'mid'),
(23,90,60,121,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,76,68,126,36.7,77,'low'),
(34,120,75,144,36.7,70,'low'),
(48,120,80,198,36.7,88,'high'),
(15,120,80,119,37.2,70,'low'),
(27,140,90,270,36.7,90,'high'),
(25,140,100,216,37.2,80,'high'),
(36,120,90,126,36.7,82,'mid'),
(30,120,80,162,38.3,76,'mid'),
(15,70,50,108,36.7,70,'mid'),
(40,120,95,126,36.7,70,'high'),
(15,90,60,108,36.7,80,'low'),
(21,90,50,124,36.7,60,'low'),
(15,90,49,108,36.7,77,'low'),
(21,90,50,117,36.7,60,'low'),
(15,90,49,108,36.7,77,'low'),
(15,90,49,121,37.2,77,'low'),
(15,90,49,108,37.2,77,'low'),
(10,100,50,108,37.2,70,'mid'),
(15,100,49,123,37.2,77,'low'),
(15,100,49,108,37.2,77,'low'),
(12,100,50,115,36.7,70,'mid'),
(15,100,60,108,36.7,80,'low'),
(35,140,90,234,36.7,70,'high'),
(29,90,70,144,37.8,80,'high'),
(30,140,85,126,36.7,70,'high'),
(23,140,80,126,36.7,70,'high'),
(35,85,60,198,38.9,86,'high'),
(42,130,80,324,36.7,70,'high'),
(50,140,90,270,36.7,90,'high'),
(25,140,100,126,36.7,80,'high'),
(40,140,100,324,36.7,90,'high'),
(32,140,100,124,36.7,78,'high'),
(14,90,65,126,38.3,70,'high'),
(37,120,90,198,36.7,88,'high'),
(17,110,75,216,38.3,76,'high'),
(40,120,90,216,36.7,80,'high'),
(40,160,100,342,36.7,77,'high'),
(20,120,76,135,36.7,70,'low'),
(15,120,80,135,36.7,70,'low'),
(24,120,80,135,36.7,66,'low'),
(19,120,60,126,36.9,70,'low'),
(31,120,60,110,36.7,76,'low'),
(23,120,85,144,36.7,70,'low'),
(23,90,60,121,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,76,68,126,36.7,77,'low'),
(34,120,75,144,36.7,70,'low'),
(15,120,80,119,37.2,70,'low'),
(15,90,60,108,36.7,80,'low'),
(21,90,50,124,36.7,60,'low'),
(15,100,49,137,36.7,77,'low'),
(12,100,50,108,36.7,70,'mid'),
(21,100,50,123,36.7,60,'low'),
(23,130,70,126,36.7,78,'mid'),
(32,120,90,124,36.7,70,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,120,75,126,37.8,70,'mid'),
(48,120,80,198,36.7,88,'mid'),
(30,120,80,124,38.3,76,'mid'),
(18,120,80,124,38.9,76,'mid'),
(17,90,60,124,38.3,76,'mid'),
(17,90,63,124,38.3,70,'mid'),
(25,120,90,121,38.3,80,'mid'),
(17,120,80,121,38.9,76,'mid'),
(13,90,65,142,38.3,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,110,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(28,85,60,162,38.3,86,'mid'),
(50,140,80,121,36.7,70,'mid'),
(29,90,70,121,36.7,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,121,36.7,78,'mid'),
(17,85,60,162,38.9,86,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,110,60,126,37.8,70,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,120,75,126,37.8,70,'mid'),
(48,120,80,198,36.7,88,'mid'),
(30,120,80,124,38.3,76,'mid'),
(18,120,80,124,38.9,76,'mid'),
(17,90,60,124,38.3,76,'mid'),
(17,90,63,124,38.3,70,'mid'),
(25,120,90,121,38.3,80,'mid'),
(17,120,80,121,38.9,76,'mid'),
(13,90,65,142,38.3,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,110,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(28,85,60,162,38.3,86,'mid'),
(50,140,80,121,36.7,70,'mid'),
(29,90,70,121,36.7,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,121,36.7,78,'mid'),
(17,85,60,162,38.9,86,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,110,60,126,37.8,70,'mid'),
(32,120,65,108,38.3,76,'mid'),
(26,85,60,108,38.3,86,'mid'),
(29,130,70,139,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(54,130,70,216,36.7,67,'mid'),
(44,120,90,288,36.7,80,'mid'),
(23,130,70,124,36.7,70,'mid'),
(22,85,60,124,36.7,76,'mid'),
(55,120,90,216,36.7,70,'mid'),
(35,120,80,124,36.7,78,'mid'),
(21,90,60,124,36.7,86,'mid'),
(16,90,65,124,36.7,76,'mid'),
(33,115,65,126,36.7,70,'mid'),
(12,95,60,124,36.7,65,'mid'),
(28,120,90,124,36.7,70,'mid'),
(21,90,65,124,36.7,76,'mid'),
(18,90,60,124,36.7,70,'mid'),
(21,120,80,124,36.7,76,'mid'),
(16,100,70,124,36.7,80,'mid'),
(19,120,75,124,36.7,66,'mid'),
(23,100,85,124,36.7,66,'mid'),
(22,120,90,141,36.7,82,'mid'),
(60,120,85,270,36.7,60,'mid'),
(13,90,65,141,38.3,80,'mid'),
(23,120,90,141,36.7,60,'mid'),
(28,115,60,141,38.3,86,'mid'),
(50,120,80,141,36.7,70,'mid'),
(29,130,70,141,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(19,120,85,141,36.7,60,'mid'),
(60,90,65,123,36.7,77,'mid'),
(55,120,90,123,36.7,66,'mid'),
(25,120,80,123,36.7,66,'mid'),
(12,120,95,123,36.7,60,'mid'),
(35,100,70,123,36.7,60,'mid'),
(19,120,90,123,36.7,60,'mid'),
(60,90,65,123,36.7,77,'mid'),
(50,130,80,288,38.9,76,'mid'),
(27,120,90,123,38.9,68,'mid'),
(55,100,70,123,38.3,80,'mid'),
(12,120,90,123,36.7,80,'mid'),
(60,120,80,123,36.7,77,'mid'),
(25,120,100,123,36.7,60,'mid'),
(22,90,60,123,36.7,77,'mid'),
(30,120,80,123,36.7,70,'mid'),
(35,120,60,110,36.7,76,'mid'),
(23,130,70,123,36.7,78,'mid'),
(43,130,80,324,36.7,70,'mid'),
(19,120,80,126,36.7,70,'mid'),
(30,120,75,123,36.7,70,'mid'),
(32,120,80,123,36.7,70,'mid'),
(23,130,70,123,36.7,78,'mid'),
(42,130,80,324,36.7,70,'mid'),
(19,120,80,126,36.7,70,'mid'),
(31,110,90,123,37.8,70,'mid'),
(19,120,80,126,36.7,70,'mid'),
(25,120,80,142,36.7,66,'mid'),
(31,120,60,110,36.7,76,'mid'),
(23,120,90,142,36.7,70,'mid'),
(29,130,70,142,36.7,78,'mid'),
(48,120,80,198,36.7,88,'mid'),
(18,120,80,142,38.9,76,'mid'),
(18,85,60,135,38.3,86,'mid'),
(29,130,70,135,36.7,78,'mid'),
(23,120,75,144,36.7,70,'mid'),
(15,120,80,135,36.7,70,'mid'),
(30,120,80,135,38.3,76,'mid'),
(40,120,95,198,36.7,80,'mid'),
(60,120,85,270,36.7,60,'mid'),
(50,130,100,288,36.7,75,'mid'),
(28,115,60,135,38.3,86,'mid'),
(31,120,60,110,36.7,76,'mid'),
(23,120,80,135,36.7,70,'mid'),
(29,130,70,135,36.7,78,'mid'),
(22,100,65,135,36.7,70,'mid'),
(49,120,90,135,36.7,77,'mid'),
(28,90,60,135,36.7,82,'mid'),
(12,90,60,135,38.9,66,'mid'),
(20,100,90,135,36.7,88,'mid'),
(23,100,85,135,36.7,66,'mid'),
(22,120,90,135,36.7,82,'mid'),
(21,120,80,135,36.7,77,'mid'),
(60,120,80,135,36.7,75,'mid'),
(50,130,100,288,36.7,75,'mid'),
(17,90,65,135,39.4,67,'mid'),
(29,130,70,135,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(19,120,85,162,36.7,60,'mid'),
(30,90,65,144,36.7,77,'mid'),
(28,85,60,162,38.3,86,'mid'),
(50,120,80,126,36.7,70,'mid'),
(39,110,70,142,36.7,80,'mid'),
(29,130,70,144,36.7,78,'mid'),
(17,90,60,162,38.9,86,'mid'),
(32,120,90,126,37.8,70,'mid'),
(42,120,90,162,36.7,70,'mid'),
(36,120,90,126,36.7,82,'mid'),
(30,120,80,162,38.3,76,'mid'),
(15,70,50,108,36.7,70,'mid'),
(10,100,50,108,37.2,70,'mid'),
(12,100,50,115,36.7,70,'mid'),
(12,100,50,108,36.7,70,'mid'),
(23,130,70,126,36.7,78,'mid'),
(32,120,90,124,36.7,70,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,120,75,126,37.8,70,'mid'),
(48,120,80,198,36.7,88,'mid'),
(30,120,80,124,38.3,76,'mid'),
(18,120,80,124,38.9,76,'mid'),
(17,90,60,124,38.3,76,'mid'),
(17,90,63,124,38.3,70,'mid'),
(25,120,90,121,38.3,80,'mid'),
(17,120,80,121,38.9,76,'mid'),
(13,90,65,142,38.3,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,110,36.7,78,'mid'),
(19,120,80,126,36.7,70,'mid'),
(28,85,60,162,38.3,86,'mid'),
(50,140,80,121,36.7,70,'mid'),
(29,90,70,121,36.7,80,'mid'),
(31,120,60,110,36.7,76,'mid'),
(29,130,70,121,36.7,78,'mid'),
(17,85,60,162,38.9,86,'mid'),
(19,120,80,126,36.7,70,'mid'),
(20,110,60,126,37.8,70,'mid'),
(32,120,65,108,38.3,76,'mid'),
(27,120,70,123,36.7,77,'low'),
(27,120,70,123,36.7,77,'low'),
(32,120,90,123,36.7,70,'low'),
(23,99,60,123,36.7,76,'low'),
(15,76,49,123,36.7,77,'low'),
(15,120,80,123,36.7,70,'low'),
(29,100,70,123,36.7,80,'low'),
(35,120,60,110,36.7,76,'low'),
(32,120,90,123,36.7,70,'low'),
(23,90,60,123,36.7,76,'low'),
(15,76,49,123,36.7,77,'low'),
(20,120,75,123,36.7,70,'low'),
(48,120,80,198,36.7,88,'low'),
(15,120,80,123,36.7,70,'low'),
(30,120,80,123,38.3,76,'low'),
(18,120,80,123,38.9,76,'low'),
(17,90,60,142,38.3,76,'low'),
(15,76,49,142,36.7,77,'low'),
(19,120,75,142,36.7,70,'low'),
(48,120,80,198,36.7,88,'low'),
(15,120,80,142,36.7,70,'low'),
(22,100,65,142,36.7,80,'low'),
(35,100,70,142,36.7,60,'low'),
(19,120,85,142,36.7,60,'low'),
(60,90,65,142,36.7,77,'low'),
(50,120,80,142,36.7,70,'low'),
(17,85,60,142,38.9,86,'low'),
(32,120,90,142,36.7,70,'low'),
(42,120,80,142,36.7,70,'low'),
(23,90,60,142,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,76,49,142,36.7,77,'low'),
(15,120,80,142,36.7,70,'low'),
(17,70,50,142,36.7,70,'low'),
(17,90,60,135,38.3,76,'low'),
(17,90,63,135,38.3,70,'low'),
(25,120,90,135,38.3,80,'low'),
(17,120,80,135,38.9,76,'low'),
(19,90,65,135,38.3,70,'low'),
(15,80,60,135,36.7,80,'low'),
(60,90,65,135,36.7,77,'low'),
(50,120,80,135,36.7,70,'low'),
(19,90,70,135,36.7,80,'low'),
(31,120,60,110,36.7,76,'low'),
(23,120,90,135,36.7,70,'low'),
(17,85,60,135,38.9,86,'low'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(42,90,60,135,36.7,76,'low'),
(19,120,80,126,36.7,70,'low'),
(15,78,49,135,36.7,77,'low'),
(16,70,50,135,37.8,70,'low'),
(16,100,70,135,36.7,80,'low'),
(19,120,75,135,36.7,66,'low'),
(22,100,65,135,36.7,70,'low'),
(49,120,90,135,36.7,77,'low'),
(28,90,60,135,36.7,82,'low'),
(12,90,60,135,38.9,66,'low'),
(20,100,90,135,36.7,88,'low'),
(23,100,85,135,36.7,66,'low'),
(22,120,90,135,36.7,82,'low'),
(21,120,80,135,36.7,77,'low'),
(21,75,50,135,36.7,60,'low'),
(12,90,60,135,38.9,60,'low'),
(60,120,80,135,36.7,75,'low'),
(55,100,65,135,36.7,66,'low'),
(45,120,95,135,36.7,66,'low'),
(35,100,70,135,36.7,66,'low'),
(22,120,85,135,36.7,88,'low'),
(13,90,65,135,38.3,80,'low'),
(23,120,90,135,36.7,60,'low'),
(17,90,65,135,39.4,67,'low'),
(59,120,80,135,36.7,70,'low'),
(23,120,80,135,36.7,70,'low'),
(17,85,60,135,38.9,86,'low'),
(32,120,90,135,36.7,70,'low'),
(42,120,80,135,36.7,70,'low'),
(25,140,100,126,36.7,80,'high'),
(40,140,100,324,36.7,90,'high'),
(32,140,100,124,36.7,78,'high'),
(14,90,65,126,38.3,70,'high'),
(37,120,90,198,36.7,88,'high'),
(17,110,75,216,38.3,76,'high'),
(40,120,90,216,36.7,80,'high'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(12,90,60,142,38.9,66,'high'),
(35,140,100,144,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(60,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,75,'high'),
(17,90,65,110,39.4,67,'high'),
(28,83,60,144,38.3,86,'high'),
(50,120,80,270,36.7,70,'high'),
(17,85,60,162,38.9,86,'high'),
(33,120,75,180,36.7,70,'high'),
(48,120,80,198,36.7,88,'high'),
(50,140,95,306,36.7,60,'high'),
(30,140,100,270,36.7,70,'high'),
(29,120,75,130,37.8,70,'high'),
(48,120,80,198,36.7,88,'high'),
(50,140,90,270,36.7,77,'high'),
(25,140,100,130,36.7,80,'high'),
(55,140,80,130,38.3,76,'high'),
(40,140,100,324,36.7,77,'high'),
(28,120,80,162,38.9,76,'high'),
(32,140,100,144,36.7,70,'high'),
(17,90,60,198,38.3,78,'high'),
(17,90,63,144,38.3,70,'high'),
(25,120,90,216,38.3,80,'high'),
(17,120,80,126,38.9,76,'high'),
(19,90,65,198,38.3,70,'high'),
(37,120,90,198,36.7,88,'high'),
(17,110,75,234,38.3,76,'high'),
(25,120,90,270,36.7,80,'high'),
(40,160,100,342,36.7,77,'high'),
(32,140,90,324,36.7,88,'high'),
(12,90,60,144,38.9,66,'high'),
(35,140,100,162,36.7,66,'high'),
(54,140,100,270,36.7,66,'high'),
(40,120,95,198,36.7,80,'high'),
(12,90,60,198,38.9,60,'high'),
(60,120,85,270,36.7,60,'high'),
(55,140,95,342,36.7,77,'high'),
(50,130,100,288,36.7,76,'high'),
(13,90,65,162,38.3,80,'high'),
(17,90,65,139,39.4,67,'high'),
(17,85,60,114,38.9,86,'high'),
(40,120,75,139,36.7,70,'high'),
(48,120,80,198,36.7,88,'high'),
(22,120,60,270,36.7,80,'high'),
(55,120,90,324,36.7,60,'high'),
(35,85,60,342,36.7,86,'high'),
(43,120,90,324,36.7,70,'high'),
(32,120,65,108,38.3,76,'mid');

-- Recompute normalization stats / class priors from the verified reference set.
select public.refresh_model_stats();


-- END FILE: supabase/seed/maternal_reference_seed.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0002_tools.sql
-- ============================================================================
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


-- END FILE: supabase/migrations/0002_tools.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0003_membership_notifications.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Membership / billing + notifications.
--
-- Adds:
--   * plans, premium_contents               -> membership catalog (read-only to users)
--   * subscriptions, payments               -> the (demo) purchase records the admin sees
--   * notifications, notification_reads     -> in-app/OS notification feed + read state
--   * notification_templates                -> "ready-made" reminders the app schedules
--   * device_tokens                         -> scaffolding for a future FCM push step
--
-- Run AFTER 0001_init.sql (+ seed) and 0002_tools.sql, in the Supabase SQL Editor.
-- Per-user RLS like the existing tables. The admin panel uses the service-role
-- key (which bypasses RLS), so no is_admin column is required: it can insert
-- broadcast notifications and read every payment/subscription directly.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Membership catalog
-- ----------------------------------------------------------------------------

create table if not exists public.plans (
  id              bigint generated always as identity primary key,
  code            text not null unique,            -- free | premium_monthly | premium_quarter | premium_pregnancy
  name            text not null,
  description     text,
  price           numeric not null default 0,
  currency        text not null default 'TRY',
  period          text not null default 'monthly', -- monthly | quarter | pregnancy | lifetime
  duration_months int,                             -- access length; null = lifetime / free
  features        jsonb not null default '[]'::jsonb,
  perks           jsonb not null default '[]'::jsonb, -- display bullet list
  is_active       boolean not null default true,
  sort_order      int not null default 0,
  created_at      timestamptz not null default now()
);

create table if not exists public.premium_contents (
  id               bigint generated always as identity primary key,
  title            text not null,
  summary          text,
  body             text,
  category         text,
  icon             text,
  required_feature text not null default 'premium_content',
  is_active        boolean not null default true,
  sort_order       int not null default 0,
  created_at       timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- Purchases (demo — no real charge). These are what the admin panel surfaces.
-- ----------------------------------------------------------------------------

create table if not exists public.subscriptions (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  plan_code  text not null,
  plan_name  text not null,
  price      numeric not null default 0,
  currency   text not null default 'TRY',
  status     text not null default 'active',  -- active | cancelled | expired
  started_at timestamptz not null default now(),
  expires_at timestamptz,                     -- null = lifetime
  created_at timestamptz not null default now()
);
create index if not exists subscriptions_user_idx
  on public.subscriptions (user_id, status);

create table if not exists public.payments (
  id              bigint generated always as identity primary key,
  user_id         uuid not null references auth.users(id) on delete cascade,
  subscription_id bigint references public.subscriptions(id) on delete set null,
  plan_code       text not null,
  amount          numeric not null default 0,
  currency        text not null default 'TRY',
  method          text not null default 'demo',
  status          text not null default 'paid',
  raw             jsonb not null default '{}'::jsonb,
  created_at      timestamptz not null default now()
);
create index if not exists payments_user_idx on public.payments (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- Notifications
-- ----------------------------------------------------------------------------

create table if not exists public.notifications (
  id         bigint generated always as identity primary key,
  audience   text not null default 'user',    -- all | user
  user_id    uuid references auth.users(id) on delete cascade, -- null when audience = all
  title      text not null,
  body       text,
  category   text,
  icon       text,
  created_by uuid,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications (user_id, created_at desc);
create index if not exists notifications_audience_idx on public.notifications (audience, created_at desc);

create table if not exists public.notification_reads (
  user_id         uuid not null references auth.users(id) on delete cascade,
  notification_id bigint not null references public.notifications(id) on delete cascade,
  read_at         timestamptz not null default now(),
  primary key (user_id, notification_id)
);

-- "Ready-made" reminder templates the app schedules locally (su iç, değer gir...).
create table if not exists public.notification_templates (
  id              bigint generated always as identity primary key,
  key             text not null unique,
  title           text not null,
  body            text,
  category        text,
  icon            text,
  schedule_hour   int,   -- local daily reminder hour (0-23); null = not auto-scheduled
  schedule_minute int not null default 0,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

-- FCM device tokens (used by a future server-push step; harmless if unused).
create table if not exists public.device_tokens (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  token      text not null,
  platform   text,
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

-- ----------------------------------------------------------------------------
-- Row Level Security
-- ----------------------------------------------------------------------------

alter table public.plans                  enable row level security;
alter table public.premium_contents       enable row level security;
alter table public.subscriptions          enable row level security;
alter table public.payments               enable row level security;
alter table public.notifications          enable row level security;
alter table public.notification_reads     enable row level security;
alter table public.notification_templates enable row level security;
alter table public.device_tokens          enable row level security;

-- Catalog: readable by anyone (so the paywall can render even pre-login).
drop policy if exists plans_read on public.plans;
create policy plans_read on public.plans
  for select using (true);

drop policy if exists premium_contents_read on public.premium_contents;
create policy premium_contents_read on public.premium_contents
  for select using (auth.uid() is not null);

drop policy if exists notification_templates_read on public.notification_templates;
create policy notification_templates_read on public.notification_templates
  for select using (auth.uid() is not null);

-- Purchases: a user owns their own rows.
drop policy if exists subscriptions_rw on public.subscriptions;
create policy subscriptions_rw on public.subscriptions
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists payments_rw on public.payments;
create policy payments_rw on public.payments
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Device tokens: own rows.
drop policy if exists device_tokens_rw on public.device_tokens;
create policy device_tokens_rw on public.device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Notifications: read broadcasts + own; insert own (app may log fired reminders).
drop policy if exists notifications_read on public.notifications;
create policy notifications_read on public.notifications
  for select using (audience = 'all' or user_id = auth.uid());

drop policy if exists notifications_insert_own on public.notifications;
create policy notifications_insert_own on public.notifications
  for insert with check (audience = 'user' and user_id = auth.uid());

-- Notification read state: own rows.
drop policy if exists notification_reads_rw on public.notification_reads;
create policy notification_reads_rw on public.notification_reads
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ----------------------------------------------------------------------------
-- Realtime
-- ----------------------------------------------------------------------------

do $$
begin
  alter publication supabase_realtime add table public.notifications;
exception when duplicate_object then null; end $$;
do $$
begin
  alter publication supabase_realtime add table public.notification_reads;
exception when duplicate_object then null; end $$;
do $$
begin
  alter publication supabase_realtime add table public.subscriptions;
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- Seed: plans
-- ----------------------------------------------------------------------------

insert into public.plans
  (code, name, description, price, currency, period, duration_months, features, perks, is_active, sort_order)
values
  (
    'free', 'Ücretsiz', 'Temel takip ve risk skoru her zaman ücretsiz.',
    0, 'TRY', 'lifetime', null,
    '[]'::jsonb,
    '["Haftalık ölçüm girişi","KNN risk skoru","Araçlar (su, kilo, tekme...)","Randevu ve ilaç takibi"]'::jsonb,
    true, 0
  ),
  (
    'premium_monthly', 'Premium Aylık', 'Esnek: aydan aya detaylı değerlendirme ve içerik.',
    49.90, 'TRY', 'monthly', 1,
    '["guide","detailed_assessment","premium_content"]'::jsonb,
    '["Gebelik Rehberi ile sınırsız kullanım","Detaylı değerlendirme notları","Premium içerik kütüphanesi","İstediğin zaman bırak"]'::jsonb,
    true, 1
  ),
  (
    'premium_quarter', 'Premium 3 Aylık', 'Bir trimester boyunca kesintisiz destek.',
    119.90, 'TRY', 'quarter', 3,
    '["guide","detailed_assessment","premium_content"]'::jsonb,
    '["Gebelik Rehberi ile sınırsız kullanım","Detaylı değerlendirme notları","Premium içerik kütüphanesi","Aylığa göre ~%20 tasarruf"]'::jsonb,
    true, 2
  ),
  (
    'premium_pregnancy', 'Doğuma Kadar (9 Ay)', 'En avantajlı: tüm gebelik boyunca tam erişim.',
    299.00, 'TRY', 'pregnancy', 9,
    '["guide","detailed_assessment","premium_content"]'::jsonb,
    '["Gebelik Rehberi ile sınırsız kullanım","Detaylı değerlendirme notları","Premium içerik kütüphanesi","Doğuma kadar (9 ay) tek seferde","Aylık ~33 ₺ — en uygun"]'::jsonb,
    true, 3
  )
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  price = excluded.price,
  currency = excluded.currency,
  period = excluded.period,
  duration_months = excluded.duration_months,
  features = excluded.features,
  perks = excluded.perks,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

-- ----------------------------------------------------------------------------
-- Seed: premium content library
-- ----------------------------------------------------------------------------

insert into public.premium_contents (title, summary, body, category, icon, sort_order)
select * from (values
  (
    'Trimester Bazlı Beslenme Rehberi',
    'Her trimester için uzman onaylı beslenme planı ve örnek menüler.',
    'Birinci trimesterde folik asit ve B6; ikinci trimesterde demir, kalsiyum ve protein; üçüncü trimesterde omega-3 ve lif öne çıkar. Gün içinde az ve sık öğün, bol su ve işlenmiş şekeri sınırlamak temel ilkelerdir. Örnek bir gün: kahvaltıda yumurta + tam tahıl + yoğurt; ara öğünde ceviz/meyve; öğlen ızgara protein + sebze + bulgur; akşam mercimek çorbası + salata.',
    'Beslenme', 'restaurant_rounded', 0
  ),
  (
    'Güvenli Egzersiz Programı',
    'Gebelikte güvenli hareketler, kaçınılması gerekenler ve haftalık plan.',
    'Düşük etkili yürüyüş, prenatal yoga, yüzme ve pelvik taban egzersizleri çoğu gebelik için güvenlidir. Sırtüstü uzun süreli pozisyonlardan, düşme riski olan sporlardan ve aşırı ısınmadan kaçının. Haftada 3-4 gün, 20-30 dakikalık orta tempolu hareket hedefleyin; nefes darlığı, kanama veya kasılma olursa durup doktora danışın.',
    'Egzersiz', 'fitness_center_rounded', 1
  ),
  (
    'Doğuma Hazırlık Kontrol Listesi',
    'Hastane çantası, doğum planı ve son hafta hazırlıkları.',
    'Hastane çantasında anne için belgeler, rahat kıyafet, terlik ve hijyen ürünleri; bebek için body, zıbın, battaniye ve çıkış kıyafeti bulunsun. Doğum planında ağrı yönetimi tercihlerini, refakatçiyi ve acil durum iletişimini netleştirin. 36. haftadan itibaren çantayı hazır tutun.',
    'Doğum', 'checklist_rounded', 2
  ),
  (
    'Uyku ve Stres Yönetimi',
    'Daha iyi uyku için rutinler ve gebelikte stresle başa çıkma.',
    'Her gün benzer saatte yatıp kalkmak, akşam kafeini azaltmak ve sol yana yatış uyku kalitesini artırır. Nefes egzersizleri, kısa yürüyüşler ve ekran süresini sınırlamak stresi azaltır. Uyku düzeni günler boyu bozuksa veya yoğun kaygı varsa uzman desteği almaktan çekinmeyin.',
    'Sağlık', 'self_improvement_rounded', 3
  ),
  (
    'Emzirme Başlangıç Rehberi',
    'İlk günlerde emzirme teknikleri ve sık karşılaşılan sorunlar.',
    'Doğru tutuş ve pozisyon, bebeğin memeyi yeterince kavraması ve sık emzirme süt üretimini destekler. İlk günlerde göğüs hassasiyeti normaldir; çatlak veya şiddetli ağrı olursa pozisyonu gözden geçirin. Bebeğin bez sayısı ve kilo alımı yeterli beslenmenin göstergesidir.',
    'Bebek', 'child_care_rounded', 4
  )
) as v(title, summary, body, category, icon, sort_order)
where not exists (select 1 from public.premium_contents);

-- ----------------------------------------------------------------------------
-- Seed: notification templates (ready-made reminders the app schedules)
-- ----------------------------------------------------------------------------

insert into public.notification_templates (key, title, body, category, icon, schedule_hour, schedule_minute, is_active)
values
  ('su_ic', 'Su içmeyi unutma 💧', 'Bugün yeterince su içtin mi? Küçük yudumlarla güne yay.', 'reminder', 'local_drink_rounded', 11, 0, true),
  ('su_ic_2', 'Su molası zamanı 💧', 'Bir bardak su içmek için harika bir an.', 'reminder', 'local_drink_rounded', 16, 0, true),
  ('deger_gir', 'Bugünkü değerlerini girdin mi? 📋', 'Takip ekranından haftalık ölçümlerini ekleyerek analizini güncelle.', 'reminder', 'monitor_heart_rounded', 20, 0, true),
  ('ilac', 'İlaç ve vitamin hatırlatması 💊', 'Bugünkü takviyelerini almayı unutma.', 'reminder', 'medication_rounded', 9, 0, true),
  ('haftalik_gelisim', 'Bu haftanın gelişimi 🌱', 'Bebeğinin bu haftaki gelişimini anasayfadan keşfet.', 'info', 'eco_rounded', 10, 30, true)
on conflict (key) do update set
  title = excluded.title,
  body = excluded.body,
  category = excluded.category,
  icon = excluded.icon,
  schedule_hour = excluded.schedule_hour,
  schedule_minute = excluded.schedule_minute,
  is_active = excluded.is_active;


-- END FILE: supabase/migrations/0003_membership_notifications.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0004_admin.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Admin panel access + demo admin account.   (clean, idempotent)
--
-- The web admin panel (../admin) signs in with the public anon key via Supabase
-- Auth (no service_role key ever leaves the server). Admins are rows in
-- `admin_users`; the SECURITY DEFINER `is_admin()` helper drives extra RLS
-- policies that let an admin SELECT every user's data and broadcast
-- notifications, while normal users stay restricted to their own rows.
--
-- Run AFTER 0001_init.sql, 0002_tools.sql and 0003_membership_notifications.sql.
-- Requires the pgcrypto extension (already created in 0001).
--
-- Safe to run as many times as you like. Watch the "Messages" tab for a NOTICE
-- confirming the demo admin was created and flagged.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Admin registry + helper
-- ----------------------------------------------------------------------------

create table if not exists public.admin_users (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_users enable row level security;

-- A signed-in user may read ONLY their own admin row. The panel uses this to
-- decide whether to show the dashboard (no SECURITY DEFINER needed for the
-- check itself).
drop policy if exists admin_users_self on public.admin_users;
create policy admin_users_self on public.admin_users
  for select using (auth.uid() = user_id);

-- SECURITY DEFINER so it can read admin_users regardless of the caller's RLS.
-- Used by the data-access policies below.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users a where a.user_id = auth.uid()
  );
$$;

grant execute on function public.is_admin() to authenticated, anon;

-- ----------------------------------------------------------------------------
-- 2) Admin read access across every per-user table (additive to the owner
--    policies — Postgres OR's permissive policies together).
-- ----------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'profiles','week_entries','appointments','medications','chat_messages',
    'kick_sessions','contraction_logs','weight_entries','water_logs',
    'journal_entries','baby_names','subscriptions','payments',
    'notifications','notification_reads','device_tokens'
  ]
  loop
    execute format('drop policy if exists %I_admin_read on public.%I;', t, t);
    execute format(
      'create policy %I_admin_read on public.%I for select using (public.is_admin());',
      t, t);
  end loop;
end $$;

-- Admins can create/edit/remove notifications (broadcast to all or per user).
drop policy if exists notifications_admin_insert on public.notifications;
create policy notifications_admin_insert on public.notifications
  for insert with check (public.is_admin());

drop policy if exists notifications_admin_update on public.notifications;
create policy notifications_admin_update on public.notifications
  for update using (public.is_admin()) with check (public.is_admin());

drop policy if exists notifications_admin_delete on public.notifications;
create policy notifications_admin_delete on public.notifications
  for delete using (public.is_admin());

-- ----------------------------------------------------------------------------
-- 3) Demo admin account (for the instructor to log into the admin panel).
--
--      E-posta : admin@gebelik.app
--      Şifre   : Admin1234!
--
--    Creates the auth user if missing, resets its password, fixes the NULL
--    token columns that otherwise break login ("Database error querying
--    schema"), and flags it as admin. Fully idempotent.
-- ----------------------------------------------------------------------------

do $$
declare
  v_uid   uuid;
  v_email text := 'admin@gebelik.app';
  v_pass  text := 'Admin1234!';
  v_col   text;
  v_token_cols text[] := array[
    'confirmation_token','recovery_token','email_change','email_change_token_new',
    'email_change_token_current','phone_change','phone_change_token',
    'reauthentication_token'
  ];
begin
  select id into v_uid from auth.users where lower(email) = lower(v_email);

  if v_uid is null then
    v_uid := gen_random_uuid();

    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token, email_change, email_change_token_new
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_uid, 'authenticated', 'authenticated',
      v_email, crypt(v_pass, gen_salt('bf')),
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      '{"name":"Demo Admin"}'::jsonb,
      now(), now(),
      '', '', '', ''
    );

    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_uid::text, v_uid,
      jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
      'email', now(), now(), now()
    );
  else
    -- Existing row (maybe from a broken earlier run): reset password + confirm.
    update auth.users
       set encrypted_password = crypt(v_pass, gen_salt('bf')),
           email_confirmed_at = coalesce(email_confirmed_at, now())
     where id = v_uid;
  end if;

  -- Repair any NULL token columns (fixes "Database error querying schema").
  foreach v_col in array v_token_cols loop
    if exists (
      select 1 from information_schema.columns
      where table_schema = 'auth' and table_name = 'users' and column_name = v_col
    ) then
      execute format(
        'update auth.users set %I = coalesce(%I, '''') where id = $1', v_col, v_col
      ) using v_uid;
    end if;
  end loop;

  -- Make sure an email identity exists (older rows may lack it).
  if not exists (
    select 1 from auth.identities where user_id = v_uid and provider = 'email'
  ) then
    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_uid::text, v_uid,
      jsonb_build_object('sub', v_uid::text, 'email', v_email, 'email_verified', true),
      'email', now(), now(), now()
    );
  end if;

  -- Flag as admin (this is what the panel checks).
  insert into public.admin_users (user_id) values (v_uid)
    on conflict (user_id) do nothing;

  update public.profiles
     set name  = coalesce(nullif(name, ''), 'Demo Admin'),
         email = v_email
   where id = v_uid;

  raise notice 'Demo admin hazir -> e-posta: %, uid: %, admin_users''a eklendi.', v_email, v_uid;
end $$;

-- ----------------------------------------------------------------------------
-- 4) Verify — should return exactly one row (the demo admin).
-- ----------------------------------------------------------------------------
select au.user_id, u.email, u.email_confirmed_at is not null as email_confirmed
from public.admin_users au
join auth.users u on u.id = au.user_id;

-- ----------------------------------------------------------------------------
-- (İsteğe bağlı) Kendi e-postanı da yönetici yapmak istersen, aşağıdaki satırda
-- e-postayı değiştirip çalıştır:
--
--   insert into public.admin_users (user_id)
--   select id from auth.users where lower(email) = lower('SENIN_EPOSTAN@ornek.com')
--   on conflict (user_id) do nothing;
-- ----------------------------------------------------------------------------


-- END FILE: supabase/migrations/0004_admin.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0005_plans_and_ai_logs.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Pregnancy-fitted membership plans + assessment logs.
--
--   * Plans are re-scoped to the pregnancy timeline (monthly / 3-month /
--     "until birth" ~9 months). The old yearly plan is retired — nobody buys a
--     year of a 9-month journey.
--   * `analysis_logs` records every risk assessment (inputs, result and note)
--     so the admin panel can show each user's assessment history.
--
-- Run AFTER 0001..0004. Idempotent.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Plans: add a real duration + re-seed for the pregnancy timeline
-- ----------------------------------------------------------------------------

alter table public.plans
  add column if not exists duration_months int;  -- null = ömür boyu / ücretsiz

-- Retire the yearly plan (keep the row for history, just hide it).
update public.plans set is_active = false where code = 'premium_yearly';

insert into public.plans
  (code, name, description, price, currency, period, duration_months, features, perks, is_active, sort_order)
values
  (
    'free', 'Ücretsiz', 'Temel takip ve risk skoru her zaman ücretsiz.',
    0, 'TRY', 'lifetime', null,
    '[]'::jsonb,
    '["Haftalık ölçüm girişi","KNN risk skoru","Araçlar (su, kilo, tekme...)","Randevu ve ilaç takibi"]'::jsonb,
    true, 0
  ),
  (
    'premium_monthly', 'Premium Aylık', 'Esnek: aydan aya detaylı değerlendirme ve içerik.',
    49.90, 'TRY', 'monthly', 1,
    '["guide","detailed_assessment","premium_content"]'::jsonb,
    '["Gebelik Rehberi ile sınırsız kullanım","Detaylı değerlendirme notları","Premium içerik kütüphanesi","İstediğin zaman bırak"]'::jsonb,
    true, 1
  ),
  (
    'premium_quarter', 'Premium 3 Aylık', 'Bir trimester boyunca kesintisiz destek.',
    119.90, 'TRY', 'quarter', 3,
    '["guide","detailed_assessment","premium_content"]'::jsonb,
    '["Gebelik Rehberi ile sınırsız kullanım","Detaylı değerlendirme notları","Premium içerik kütüphanesi","Aylığa göre ~%20 tasarruf"]'::jsonb,
    true, 2
  ),
  (
    'premium_pregnancy', 'Doğuma Kadar (9 Ay)', 'En avantajlı: tüm gebelik boyunca tam erişim.',
    299.00, 'TRY', 'pregnancy', 9,
    '["guide","detailed_assessment","premium_content"]'::jsonb,
    '["Gebelik Rehberi ile sınırsız kullanım","Detaylı değerlendirme notları","Premium içerik kütüphanesi","Doğuma kadar (9 ay) tek seferde","Aylık ~33 ₺ — en uygun"]'::jsonb,
    true, 3
  )
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  price = excluded.price,
  currency = excluded.currency,
  period = excluded.period,
  duration_months = excluded.duration_months,
  features = excluded.features,
  perks = excluded.perks,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order;

-- ----------------------------------------------------------------------------
-- 2) Assessment logs (one row per "Analiz Et" run)
-- ----------------------------------------------------------------------------

create table if not exists public.analysis_logs (
  id            bigint generated always as identity primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  week_no       int,
  age           int,
  systolic      double precision,
  diastolic     double precision,
  blood_sugar   double precision,
  body_temp     double precision,
  bmi           double precision,
  heart_rate    double precision,
  risk_label    text,
  risk_score    double precision,
  knn_k         int,
  knn_high      int,
  knn_mid       int,
  knn_low       int,
  avg_distance  double precision,
  source        text,          -- dataset | local
  guidance_note text,
  ai_advice     text,          -- legacy compatibility; no longer written
  created_at    timestamptz not null default now()
);
create index if not exists analysis_logs_user_idx
  on public.analysis_logs (user_id, created_at desc);

alter table public.analysis_logs
  add column if not exists guidance_note text;

alter table public.analysis_logs enable row level security;

-- Owner can read/write their own logs.
drop policy if exists analysis_logs_rw on public.analysis_logs;
create policy analysis_logs_rw on public.analysis_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Admins can read every log (is_admin() from 0004_admin.sql).
drop policy if exists analysis_logs_admin_read on public.analysis_logs;
create policy analysis_logs_admin_read on public.analysis_logs
  for select using (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.analysis_logs;
exception when duplicate_object then null; end $$;


-- END FILE: supabase/migrations/0005_plans_and_ai_logs.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0006_support.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Support / contact messages.
--
-- The in-app "Destek" form writes to `support_messages`; the admin panel reads
-- them and can mark them resolved. Same admin model as everything else
-- (is_admin() from 0004_admin.sql).
--
-- Run AFTER 0001..0005. Idempotent.
-- ============================================================================

create table if not exists public.support_messages (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users(id) on delete set null,
  name       text,
  email      text,
  subject    text,
  message    text not null,
  status     text not null default 'new',  -- new | read | resolved
  created_at timestamptz not null default now()
);
create index if not exists support_messages_created_idx
  on public.support_messages (created_at desc);
create index if not exists support_messages_status_idx
  on public.support_messages (status, created_at desc);

alter table public.support_messages enable row level security;

-- A user can create and read their own messages.
drop policy if exists support_messages_insert_own on public.support_messages;
create policy support_messages_insert_own on public.support_messages
  for insert with check (auth.uid() = user_id);

drop policy if exists support_messages_read_own on public.support_messages;
create policy support_messages_read_own on public.support_messages
  for select using (auth.uid() = user_id);

-- Admins can read every message and update its status.
drop policy if exists support_messages_admin_read on public.support_messages;
create policy support_messages_admin_read on public.support_messages
  for select using (public.is_admin());

drop policy if exists support_messages_admin_update on public.support_messages;
create policy support_messages_admin_update on public.support_messages
  for update using (public.is_admin()) with check (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.support_messages;
exception when duplicate_object then null; end $$;


-- END FILE: supabase/migrations/0006_support.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0007_symptoms_safety_consent.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Phase 1: symptom tracking, account requests (KVKK), consent.
--
--   * symptom_logs       -> daily symptom / check-in entries (per user)
--   * account_requests   -> data deletion / export requests the admin handles
--   * profiles.consent_*  -> KVKK consent + medical disclaimer acceptance
--
-- Run AFTER 0001..0006. Idempotent. Admin model = is_admin() from 0004.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Symptom / daily check-in logs
-- ----------------------------------------------------------------------------

create table if not exists public.symptom_logs (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  logged_on   date not null default current_date,
  week_no     int,
  symptoms    jsonb not null default '[]'::jsonb,  -- list of symptom labels
  severity    int,                                 -- 1 hafif | 2 orta | 3 şiddetli
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists symptom_logs_user_idx
  on public.symptom_logs (user_id, logged_on desc);

alter table public.symptom_logs enable row level security;

drop policy if exists symptom_logs_rw on public.symptom_logs;
create policy symptom_logs_rw on public.symptom_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists symptom_logs_admin_read on public.symptom_logs;
create policy symptom_logs_admin_read on public.symptom_logs
  for select using (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.symptom_logs;
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- 2) Account requests (KVKK/GDPR: data deletion or export)
-- ----------------------------------------------------------------------------

create table if not exists public.account_requests (
  id         bigint generated always as identity primary key,
  user_id    uuid references auth.users(id) on delete set null,
  email      text,
  type       text not null default 'deletion',  -- deletion | export
  status     text not null default 'new',        -- new | in_progress | done
  note       text,
  created_at timestamptz not null default now()
);
create index if not exists account_requests_status_idx
  on public.account_requests (status, created_at desc);

alter table public.account_requests enable row level security;

drop policy if exists account_requests_insert_own on public.account_requests;
create policy account_requests_insert_own on public.account_requests
  for insert with check (auth.uid() = user_id);

drop policy if exists account_requests_read_own on public.account_requests;
create policy account_requests_read_own on public.account_requests
  for select using (auth.uid() = user_id);

drop policy if exists account_requests_admin_read on public.account_requests;
create policy account_requests_admin_read on public.account_requests
  for select using (public.is_admin());

drop policy if exists account_requests_admin_update on public.account_requests;
create policy account_requests_admin_update on public.account_requests
  for update using (public.is_admin()) with check (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.account_requests;
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- 3) Consent / disclaimer acceptance on the profile
-- ----------------------------------------------------------------------------

alter table public.profiles
  add column if not exists consent_accepted_at timestamptz,
  add column if not exists consent_version      text;


-- END FILE: supabase/migrations/0007_symptoms_safety_consent.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0008_checklists_cms.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Phase 2: interactive checklists + admin content management.
--
--   * checklist_items     -> per-user interactive checklists (hospital bag,
--                            birth plan, to-do, shopping)
--   * Admin WRITE policies -> let the admin panel create/edit/delete plans,
--                            premium_contents and notification_templates from
--                            the UI (was SQL-only before).
--
-- Run AFTER 0001..0007. Idempotent. Admin model = is_admin() from 0004.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1) Checklist items
-- ----------------------------------------------------------------------------

create table if not exists public.checklist_items (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  category   text not null,            -- hospital_bag | birth_plan | todo | shopping
  title      text not null,
  is_done    boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists checklist_items_user_idx
  on public.checklist_items (user_id, category, sort_order);

alter table public.checklist_items enable row level security;

drop policy if exists checklist_items_rw on public.checklist_items;
create policy checklist_items_rw on public.checklist_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists checklist_items_admin_read on public.checklist_items;
create policy checklist_items_admin_read on public.checklist_items
  for select using (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.checklist_items;
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- 2) Admin content management — write access for admins
--    (these tables already allow public/auth SELECT from earlier migrations).
-- ----------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array['plans','premium_contents','notification_templates']
  loop
    execute format('drop policy if exists %I_admin_insert on public.%I;', t, t);
    execute format(
      'create policy %I_admin_insert on public.%I for insert with check (public.is_admin());',
      t, t);

    execute format('drop policy if exists %I_admin_update on public.%I;', t, t);
    execute format(
      'create policy %I_admin_update on public.%I for update using (public.is_admin()) with check (public.is_admin());',
      t, t);

    execute format('drop policy if exists %I_admin_delete on public.%I;', t, t);
    execute format(
      'create policy %I_admin_delete on public.%I for delete using (public.is_admin());',
      t, t);
  end loop;
end $$;


-- END FILE: supabase/migrations/0008_checklists_cms.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0009_admin_actions.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Phase 3: admin user-management actions.
--
--   * profiles.is_active          -> admin can deactivate (ban) an account
--   * subscriptions admin WRITE   -> admin can grant / cancel premium for a user
--
-- Run AFTER 0001..0008. Idempotent. Admin model = is_admin() from 0004.
-- ============================================================================

alter table public.profiles
  add column if not exists is_active boolean not null default true;

-- Admin can create a subscription for any user (manual grant / comp).
drop policy if exists subscriptions_admin_insert on public.subscriptions;
create policy subscriptions_admin_insert on public.subscriptions
  for insert with check (public.is_admin());

-- Admin can update any subscription (cancel / extend).
drop policy if exists subscriptions_admin_update on public.subscriptions;
create policy subscriptions_admin_update on public.subscriptions
  for update using (public.is_admin()) with check (public.is_admin());

-- Admin can update any profile (toggle is_active, fix data).
drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update on public.profiles
  for update using (public.is_admin()) with check (public.is_admin());


-- END FILE: supabase/migrations/0009_admin_actions.sql

-- ============================================================================
-- BEGIN FILE: supabase/migrations/0010_baby_logs.sql
-- ============================================================================
-- ============================================================================
-- Gebelik Takip — Phase 4: postpartum baby tracking (feeding / sleep / diaper).
--
-- Run AFTER 0001..0009. Idempotent. Admin model = is_admin() from 0004.
-- ============================================================================

create table if not exists public.baby_logs (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  type        text not null,                 -- feeding | sleep | diaper
  occurred_at timestamptz not null default now(),
  amount      text,                          -- "120 ml", "30 dk", "kaka/çiş"
  note        text,
  created_at  timestamptz not null default now()
);
create index if not exists baby_logs_user_idx
  on public.baby_logs (user_id, occurred_at desc);

alter table public.baby_logs enable row level security;

drop policy if exists baby_logs_rw on public.baby_logs;
create policy baby_logs_rw on public.baby_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists baby_logs_admin_read on public.baby_logs;
create policy baby_logs_admin_read on public.baby_logs
  for select using (public.is_admin());

do $$
begin
  alter publication supabase_realtime add table public.baby_logs;
exception when duplicate_object then null; end $$;


-- END FILE: supabase/migrations/0010_baby_logs.sql
