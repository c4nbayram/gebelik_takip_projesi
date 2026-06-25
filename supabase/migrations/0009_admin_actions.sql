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
