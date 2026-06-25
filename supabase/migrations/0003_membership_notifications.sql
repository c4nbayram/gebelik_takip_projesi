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
