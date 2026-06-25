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
