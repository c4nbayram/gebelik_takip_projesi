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
