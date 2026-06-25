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
