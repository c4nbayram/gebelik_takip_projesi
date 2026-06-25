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
