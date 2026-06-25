# Gebelik Takip · Yönetim Paneli (Admin Panel)

Mobil uygulamayla **aynı Supabase projesine** bağlanan, React tabanlı web yönetim paneli.
Kullanıcıları, üyelikleri, ödemeleri ve bildirimleri tek yerden takip eder.

## Ne gösterir?

- **Genel Bakış**: kayıtlı kullanıcı (≈ indirme) sayısı, premium üye sayısı, toplam satın alma, toplam gelir, kayıtlı cihaz ve gönderilen bildirim sayısı; son 14 günün ödeme grafiği; paket dağılımı; son ödemeler.
- **Kullanıcılar**: tüm kullanıcılar + arama; her kullanıcının kişisel bilgileri, hangi paketi kullandığı, haftalık ölçümleri, ödemeleri ve aktivitesi (randevu, ilaç, tekme, kilo, günlük, sohbet).
- **Abonelikler**: tüm abonelikler, plan, ücret, durum, başlangıç/bitiş.
- **Ödemeler**: tüm satın alma kayıtları (demo) + toplam gelir.
- **Bildirimler**: tüm kullanıcılara veya tek bir kullanıcıya bildirim gönderme + geçmiş.

## Güvenlik mimarisi

Panel **anon (public) anahtar** + Supabase Auth ile çalışır; `service_role` anahtarı **hiçbir yerde** kullanılmaz.
Yönetici erişimi `supabase/migrations/0004_admin.sql` içindeki `admin_users` tablosu ve `is_admin()`
fonksiyonuna dayanır: sadece bu tabloda kayıtlı kullanıcılar tüm verileri görebilir (RLS politikaları).

## Kurulum

### 1) SQL migration'larını çalıştır (bir kez)

Supabase SQL Editor'de **sırayla** tüm migration'lar:
`0001_init.sql` → `seed/maternal_reference_seed.sql` → `0002_tools.sql` → `0003_membership_notifications.sql` → `0004_admin.sql` → `0005_plans_and_ai_logs.sql` → `0006_support.sql` → `0007_symptoms_safety_consent.sql` → `0008_checklists_cms.sql` → `0009_admin_actions.sql` → `0010_baby_logs.sql`

`0004_admin.sql` aynı zamanda **demo yönetici hesabını** oluşturur:

```
E-posta : admin@gebelik.app
Şifre   : Admin1234!
```

> Supabase sürümün doğrudan `auth.users` eklemeyi reddederse: Dashboard → Authentication → **Add user**
> ile (e-postayı onaylayarak) bu hesabı oluştur, sonra `0004_admin.sql` dosyasının sonundaki
> `insert into public.admin_users ...` bloğunu o kullanıcının id'siyle çalıştır.

### 2) Ortam değişkenleri

```bash
cd admin
cp .env.example .env     # Windows: copy .env.example .env
```

`.env` içine Supabase **Project URL** ve **anon public** anahtarını gir
(Dashboard → Project Settings → API). Bunlar mobil uygulamadaki değerlerle aynıdır.

### 3) Çalıştır

```bash
cd admin
npm install
npm run dev      # http://localhost:5173 açılır
```

Üretim derlemesi:

```bash
npm run build    # çıktı: admin/dist
npm run preview  # derlemeyi yerelde önizle
```

## Teknoloji

React 18 · Vite · React Router · @supabase/supabase-js · Recharts.

## Notlar

- "İndirme sayısı" için ayrı bir analitik yoktur; panel **kayıtlı kullanıcı** sayısını gösterir
  (her kayıt = bir kurulum/hesap). Gerçek mağaza indirme sayıları için Play Console/App Store Connect gerekir.
- Ödemeler **demo** olup gerçek tahsilat içermez; her satın alma `payments` + `subscriptions` tablolarına yazılır.
