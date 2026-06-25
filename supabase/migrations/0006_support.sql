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
