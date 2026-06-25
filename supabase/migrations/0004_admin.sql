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
