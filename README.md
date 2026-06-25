# Gebelik ve Bebek Takip Mobil Uygulaması

## Ders ve Öğrenci Bilgileri

| Bilgi | Açıklama |
|---|---|
| Üniversite | İstanbul Topkapı Üniversitesi |
| Ders | Mobil Uygulama Tasarımı ve Geliştirme |
| Ders Kodu | EFC304 |
| Öğrenci | Bayramcan Özgül |
| Öğrenci Numarası | 23040101010 |
| Proje Türü | Mobil uygulama, web yönetim paneli ve bulut tabanlı backend |
| Mobil Teknoloji | Flutter / Dart |
| Yönetim Paneli | React / Vite |
| Backend | Supabase / PostgreSQL |

## Canlı Admin Paneli

Projenin web yönetim panelini Vercel üzerinde canlı olarak yayınladım:

**Canlı bağlantı:** [https://gebelik-takip-admin.vercel.app](https://gebelik-takip-admin.vercel.app)

```text
E-posta : admin@gebelik.app
Şifre   : Admin1234!
```

Panel Supabase backend'e bağlıdır. Mobil uygulamada oluşturulan kullanıcı, ölçüm, abonelik, demo ödeme ve destek kayıtları yönetim panelinde görüntülenebilir.

## Proje Hakkında

Bu projeyi, gebelik sürecindeki sağlık verilerinin ve günlük ihtiyaçların tek bir uygulama üzerinden düzenli biçimde takip edilebilmesi amacıyla geliştirdim. Uygulamada kullanıcının haftalık sağlık ölçümlerini kaydedebileceği, randevu ve ilaçlarını yönetebileceği, gebelik haftasına ait gelişim bilgilerini okuyabileceği ve doğum sonrasında bebek kayıtlarını tutabileceği bütünleşik bir yapı oluşturdum.

Projeyi yalnızca bir mobil arayüz olarak bırakmadım. Mobil uygulamanın kullandığı verileri yöneten React tabanlı bir admin paneli ve Supabase üzerinde çalışan PostgreSQL veritabanı da geliştirdim. Böylece proje; frontend, backend, kimlik doğrulama, veritabanı güvenliği, gerçek zamanlı veri takibi ve yönetim paneli bileşenlerini birlikte içeren uçtan uca bir mobil uygulama projesi oldu.

> Önemli sağlık notu: Uygulamadaki risk değerlendirmeleri ve rehberlik notları yalnızca bilgilendirme amaçlıdır. Tıbbi teşhis veya tedavi yerine geçmez. Acil bir durumda sağlık kuruluşuna başvurulmalıdır.

## Projenin Amacı

Bu projede aşağıdaki amaçlara ulaşmayı hedefledim:

- Gebelik sürecindeki temel sağlık ölçümlerini haftalık olarak kayıt altına almak.
- Kullanıcının geçmiş ve güncel ölçümlerini tek ekranda karşılaştırabilmesini sağlamak.
- Maternal sağlık veri setini kullanarak anlaşılabilir bir risk değerlendirmesi sunmak.
- Randevu, ilaç, su, kilo, tekme ve kasılma gibi günlük takip ihtiyaçlarını birleştirmek.
- Gebelikten doğum sonrasına kadar devam edebilen bir kullanıcı deneyimi oluşturmak.
- Mobil uygulamayla aynı veritabanını kullanan bir yönetim paneli hazırlamak.
- Kullanıcı verilerini Supabase Auth ve Row Level Security politikalarıyla korumak.
- İnternet bağlantısı bulunmadığında temel ekranların yerel önbellekle çalışmaya devam etmesini sağlamak.

## Genel Mimari

Proje üç ana katmandan oluşmaktadır:

| Katman | Görevi |
|---|---|
| Flutter mobil uygulaması | Son kullanıcının kayıt olması, ölçüm girmesi ve takip araçlarını kullanması |
| React admin paneli | Kullanıcıların, risk kayıtlarının, üyeliklerin, içeriklerin ve destek mesajlarının yönetilmesi |
| Supabase backend | Kimlik doğrulama, PostgreSQL veritabanı, RLS güvenliği, gerçek zamanlı veri ve sunucu fonksiyonları |

Temel veri akışı şu şekildedir:

```text
Mobil Uygulama
      |
      | Supabase istemcisi
      v
Supabase Auth + PostgreSQL + Realtime
      ^
      | Supabase istemcisi ve yönetici yetkisi
      |
React Admin Paneli
```

Mobil uygulama ve admin paneli aynı Supabase projesine bağlanır. Mobil kullanıcı yalnızca kendi verilerine erişebilir. Yönetici hesabı ise `admin_users` tablosu ve `is_admin()` fonksiyonu sayesinde yetkili olduğu yönetim verilerine erişebilir.

## Kullanıcı Türleri

### Mobil kullanıcı

Mobil uygulamada hazır bir kullanıcı hesabı bulunmamaktadır. Kullanıcı giriş ekranındaki kayıt formundan ad, e-posta ve şifre bilgilerini girerek kendi hesabını oluşturur. Kayıt sonrasında profil satırı otomatik oluşturulur.

### Misafir kullanıcı

Uygulama bazı tanıtım ve genel içeriklerin misafir olarak görüntülenmesine izin verir. Hesap veya bulut kaydı gerektiren bir işlem yapılmak istendiğinde kullanıcı giriş ekranına yönlendirilir.

### Yönetici

Yönetici yalnızca web admin panelini kullanır. Yönetici hesabının bilgileri:

```text
Canlı panel  : https://gebelik-takip-admin.vercel.app
Yerel panel  : http://localhost:5173
E-posta      : admin@gebelik.app
Şifre        : Admin1234!
```

Bu demo yönetici hesabı [0004_admin.sql](supabase/migrations/0004_admin.sql) migration dosyası tarafından oluşturulur ve `admin_users` tablosuna eklenir.

## Mobil Uygulama Özellikleri

### 1. Karşılama ve başlangıç akışı

Uygulama ilk açıldığında üç sayfalı bir tanıtım akışı gösterir. Bu bölümde gebelik ve bebek takibi, kişisel gebelik rehberi ve aile odaklı kullanım anlatılır. Kullanıcı tanıtımı tamamladıktan sonra giriş/kayıt ekranına geçer.

Girişten sonra ilk kurulum ekranında kullanıcının rolü, bebek bilgileri, şehir, gebelik tarihleri ve gerekli sağlık bilgileri alınır. Bu bilgiler hem kişiselleştirme hem de gebelik haftasının hesaplanması için kullanılır.

### 2. Kimlik doğrulama

- E-posta ve şifre ile kayıt olma
- E-posta ve şifre ile giriş yapma
- Oturumun cihazda saklanması
- Güvenli çıkış yapma
- Profil ekranından şifre değiştirme
- Kullanıcı değiştiğinde üyelik bilgilerinin otomatik yenilenmesi

Kimlik doğrulama işlemlerini Supabase Auth ile gerçekleştirdim. Kullanıcının oturum bilgisi cihazda korunur ve uygulama yeniden açıldığında oturum geri yüklenir.

### 3. Ana sayfa

Ana sayfada kullanıcının gebelik sürecine ait özet bilgileri gösterilir:

- Güncel gebelik haftası ve haftalık gelişim bilgisi
- Bebeğin adına göre kişiselleştirilmiş başlıklar
- Son sağlık ölçümlerinin özeti
- Risk durumu ve haftalık değişim
- Yaklaşan doktor randevuları
- İlaç hatırlatmaları
- Okunmamış bildirim sayısı
- Üyelik ve premium içerik yönlendirmeleri
- Sağlık bilgilendirme ve onay metni

### 4. Haftalık sağlık takibi

Takip ekranında kullanıcı şu değerleri girebilir:

- Gebelik haftası
- Yaş
- Sistolik tansiyon
- Diastolik tansiyon
- Kan şekeri
- Vücut sıcaklığı
- Vücut kitle indeksi
- Nabız

Kaydedilen ölçümler `week_entries` tablosuna yazılır. Kullanıcı aynı haftaya tekrar veri girerse ilgili hafta kaydı güncellenir. Sonuç ekranında risk yüzdesi, risk seviyesi, komşu dağılımı, haftalık grafikler ve önceki haftayla karşılaştırmalar gösterilir.

### 5. Risk değerlendirmesi

Risk değerlendirmesinde UCI Maternal Health Risk veri setinden oluşturulmuş referans kayıtlarını kullandım. Hesaplama Supabase üzerindeki `classify_maternal_risk` PostgreSQL fonksiyonu tarafından yapılır.

Kullanılan yöntem:

1. Referans veri setindeki yaş, tansiyon, kan şekeri, sıcaklık ve nabız alanlarının ortalama ve standart sapmaları hesaplanır.
2. Farklı ölçü birimlerinin sonucu bozmasını engellemek için değerler standart sapmaya göre normalize edilir.
3. Kullanıcının ölçümleri ile veri setindeki satırlar arasındaki Öklid mesafesi hesaplanır.
4. Varsayılan olarak en yakın 15 komşu seçilir.
5. Komşuların düşük, orta ve yüksek risk dağılımı bulunur.
6. Yüksek risk `1.0`, orta risk `0.5`, düşük risk `0.0` ağırlığıyla değerlendirilerek 0 ile 1 arasında risk skoru üretilir.
7. Sonuç düşük, orta veya yüksek risk etiketiyle kullanıcıya gösterilir.

Bağlantı kurulamadığında uygulama tamamen kapanmaz. Temel eşik kurallarına dayanan yerel bir değerlendirme üretir ve verileri cihaz önbelleğinde saklar.

### 6. Gebelik Rehberi

Rehber ekranını dış bir servis kullanmadan, uygulama içinde çalışan kural tabanlı bir yapı olarak geliştirdim. Kullanıcının son ölçümlerini ve soru içindeki anahtar ifadeleri değerlendirerek beslenme, su tüketimi, uyku ve genel takip konularında bilgi verir.

Kanama, bayılma, şiddetli ağrı, nefes problemi veya ateş gibi acil olabilecek ifadelerde kullanıcıyı beklemeden doktora ya da acil servise yönlendirir. Rehber mesajları istenirse `chat_messages` tablosunda kullanıcı geçmişi olarak saklanır.

### 7. Araçlar ekranı

Araçlar merkezi, günlük gebelik ve bebek takibi için hazırladığım yardımcı modülleri bir araya getirir:

| Araç | Açıklama |
|---|---|
| Tekme sayacı | Bebeğin hareketlerini oturum olarak kaydeder |
| Kasılma sayacı | Kasılmaların başlangıç, süre ve aralık bilgilerini tutar |
| Kilo takibi | Tarihe göre kilo kayıtlarını ve değişimi izler |
| Su takibi | Günlük bardak sayısını ve hedefi takip eder |
| Günlük | Ruh hâli ve kişisel notları kaydeder |
| İsim listesi | Bebek isimleri ekleme, silme ve favorileştirme sağlar |
| Belirti takibi | Belirti, şiddet, not ve tarih kaydı oluşturur |
| Kontrol listesi | Gebelik görevlerini tamamlandı/tamamlanmadı olarak izler |
| Güvenli besin rehberi | Gebelikte besin güvenliği hakkında bilgi sunar |
| Doğum öncesi takvim | Gebelik dönemindeki önemli haftaları gösterir |
| Kırmızı bayraklar | Acil değerlendirilmesi gereken belirtileri listeler |
| Doktor raporu | Profil ve son ölçümleri özetleyen paylaşılabilir metin oluşturur |
| Bebek modu | Doğum sonrasında beslenme, uyku ve benzeri bebek kayıtlarını tutar |

### 8. Randevu ve ilaç takibi

Kullanıcı doktor randevusu ekleyebilir, yaklaşan randevularını görebilir ve tamamlanan kayıtları silebilir. İlaç bölümünde ilaç adı, doz, kullanım sıklığı, başlangıç tarihi ve not bilgileri saklanır.

Randevu ve ilaç kayıtları ana sayfadaki yaklaşan hatırlatıcılar bölümüne de yansıtılır.

### 9. Bildirim sistemi

Bildirim altyapısında `flutter_local_notifications` ve `timezone` paketlerini kullandım.

- Günlük yerel hatırlatmalar planlanabilir.
- Admin panelinden tüm kullanıcılara veya tek kullanıcıya bildirim gönderilebilir.
- Uygulama uzaktaki bildirim kayıtlarını dinler.
- Okunan bildirimler `notification_reads` tablosunda tutulur.
- Bildirim izinleri platforma uygun biçimde istenir.

### 10. Üyelik ve ödeme

Uygulamada ücretsiz ve premium plan yapısı vardır. Premium planlar aylık, üç aylık ve doğuma kadar dokuz aylık seçeneklerden oluşur.

Ödeme ekranı ders projesi için hazırlanmış bir demo akıştır. Gerçek kart bilgisi işlenmez ve gerçek para tahsil edilmez. Kullanıcı işlemi tamamladığında:

- `subscriptions` tablosunda abonelik kaydı oluşur.
- `payments` tablosunda demo ödeme kaydı oluşur.
- Premium özellikler kullanıcı hesabında aktif hâle gelir.
- İşlem admin panelindeki abonelik ve ödeme ekranlarında görünür.

### 11. Profil, güvenlik ve destek

Profil ekranında:

- Ad, yaş, rol, bebek adı ve şehir düzenlenebilir.
- Gebelik ve sağlık bilgileri güncellenebilir.
- Şifre değiştirilebilir.
- Açık, koyu veya sistem teması seçilebilir.
- Üyelik planı görüntülenebilir.
- Premium içeriklere ulaşılabilir.
- Destek formu gönderilebilir.
- Sık sorulan sorular ve gizlilik açıklamaları okunabilir.
- KVKK kapsamında hesap/veri silme talebi oluşturulabilir.
- Oturum kapatılabilir.

## Admin Paneli

Admin panelini React 18 ve Vite ile geliştirdim. Grafiklerde Recharts, sayfa yönlendirmelerinde React Router ve backend iletişiminde Supabase JavaScript istemcisini kullandım.

### Admin paneli modülleri

| Modül | İşlev |
|---|---|
| Giriş | Yönetici hesabını Supabase Auth ile doğrular |
| Genel Bakış | Kullanıcı, premium üye, ödeme, gelir, cihaz ve bildirim sayılarını gösterir |
| Kullanıcılar | Kullanıcıları listeler, arar ve detay sayfasına yönlendirir |
| Kullanıcı Detayı | Profil, ölçüm, risk, randevu, ilaç, aktivite, rehber ve bebek kayıtlarını gösterir |
| Risk Takibi | Son değerlendirmesine göre dikkat gerektiren kullanıcıları listeler |
| Abonelikler | Plan, durum, başlangıç ve bitiş tarihlerini gösterir |
| Ödemeler | Demo satın alma kayıtlarını ve toplam geliri gösterir |
| Bildirimler | Genel veya kullanıcıya özel bildirim gönderir ve geçmişi gösterir |
| İçerik Yönetimi | Planları, premium içerikleri ve bildirim şablonlarını yönetir |
| Destek | Kullanıcı mesajlarını okur, yanıtlar ve çözüldü olarak işaretler |
| Talepler | Hesap/veri silme gibi kullanıcı taleplerini yönetir |

Panel, tarayıcıya kesinlikle `service_role` anahtarı koymaz. Mobil uygulamada olduğu gibi yalnızca public istemci anahtarını kullanır. Geniş veri erişimi anahtarla değil, oturum açan kullanıcının `admin_users` tablosundaki kaydı ve RLS politikalarıyla sağlanır.

## Backend ve Veritabanı

Backend için Supabase kullandım. Supabase bu projede dört temel görevi yerine getirir:

- E-posta/şifre tabanlı kimlik doğrulama
- PostgreSQL veritabanı
- Row Level Security ile yetkilendirme
- Gerçek zamanlı veri güncellemeleri

### Temel tablolar

| Tablo | Saklanan veri |
|---|---|
| `profiles` | Kullanıcı profili, rol, şehir, bebek ve gebelik bilgileri |
| `week_entries` | Haftalık sağlık ölçümleri ve risk sonucu |
| `appointments` | Doktor randevuları |
| `medications` | İlaç ve kullanım bilgileri |
| `chat_messages` | Gebelik Rehberi mesaj geçmişi |
| `maternal_reference` | Risk hesabında kullanılan doğrulanmış referans veri seti |
| `model_stats` | Referans alanlarının ortalama ve standart sapma değerleri |
| `analysis_logs` | Risk değerlendirmesi girişleri, sonucu ve rehberlik notu |

### Takip aracı tabloları

| Tablo | Saklanan veri |
|---|---|
| `kick_sessions` | Tekme sayacı oturumları |
| `contraction_logs` | Kasılma kayıtları |
| `weight_entries` | Kilo kayıtları |
| `water_logs` | Günlük su tüketimi |
| `journal_entries` | Günlük ve ruh hâli |
| `baby_names` | Bebek isim listesi ve favoriler |
| `symptom_logs` | Belirti kayıtları |
| `checklist_items` | Kullanıcı kontrol listeleri |
| `baby_logs` | Doğum sonrası bebek kayıtları |

### Üyelik ve yönetim tabloları

| Tablo | Saklanan veri |
|---|---|
| `plans` | Ücretsiz ve premium paketler |
| `subscriptions` | Kullanıcı abonelikleri |
| `payments` | Demo ödeme hareketleri |
| `premium_contents` | Premium içerik kütüphanesi |
| `notifications` | Gönderilen bildirimler |
| `notification_reads` | Bildirim okunma durumu |
| `notification_templates` | Hazır bildirim şablonları |
| `device_tokens` | Bildirim cihaz kayıtları |
| `support_messages` | Destek talepleri ve admin yanıtları |
| `account_requests` | Hesap ve veri silme talepleri |
| `admin_users` | Yönetici yetkisine sahip kullanıcılar |

### Veritabanı güvenliği

Tüm kullanıcı tablolarında Row Level Security aktiftir. Temel güvenlik kuralları şunlardır:

- Kullanıcı yalnızca `auth.uid() = user_id` koşulunu sağlayan kendi satırlarını okuyabilir ve değiştirebilir.
- Referans veri seti yalnızca okunabilir.
- Yönetici erişimi `public.is_admin()` fonksiyonuyla kontrol edilir.
- Admin panelinde `service_role` anahtarı kullanılmaz.
- Kullanıcı silindiğinde ona bağlı kayıtlar yabancı anahtar ve `on delete cascade` kurallarıyla temizlenir.
- Uygulama sırlarını kaynak kod içine yazmak yerine `.env` dosyalarında tuttum.

## Çevrimdışı Çalışma

Supabase yapılandırılmamışsa veya bağlantı geçici olarak kesilirse uygulamanın tamamen kullanılamaz hâle gelmemesi için SharedPreferences tabanlı yerel önbellek kullandım.

Yerel olarak saklanabilen başlıca veriler:

- Kullanıcı profil özeti
- Haftalık ölçümler
- Randevular
- İlaçlar
- Onboarding ve ilk kurulum durumları
- Tema ve bazı uygulama tercihleri

Bağlantı olduğunda ana veri kaynağı Supabase'tir. Yerel kayıtlar ekranların son bilinen veriyi göstermesini sağlar.

## Kullanılan Teknolojiler

| Teknoloji | Kullanım amacı |
|---|---|
| Flutter | Android, iOS, web ve masaüstüne uyarlanabilir mobil arayüz |
| Dart | Mobil uygulama programlama dili |
| Provider | Kimlik doğrulama, üyelik ve tema durum yönetimi |
| Supabase Auth | Kullanıcı ve yönetici oturumları |
| Supabase PostgreSQL | Kalıcı veri saklama ve KNN fonksiyonu |
| Supabase Realtime | Ölçüm, randevu, ilaç ve bildirim güncellemeleri |
| SharedPreferences | Yerel önbellek ve uygulama tercihleri |
| flutter_dotenv | Ortam değişkenlerinin okunması |
| flutter_local_notifications | Cihaz bildirimleri ve zamanlanmış hatırlatmalar |
| timezone | Bildirimlerin yerel saate göre planlanması |
| intl | Türkçe tarih ve saat biçimlendirme |
| React 18 | Admin paneli kullanıcı arayüzü |
| Vite | Admin paneli geliştirme ve production build aracı |
| React Router | Admin paneli sayfa yönlendirmeleri |
| Recharts | Yönetim panelindeki istatistik grafikleri |

## Proje Dosya Yapısı

```text
gebelik_takip_projesi/
├── lib/
│   ├── main.dart                 Uygulamanın başlangıç noktası
│   └── src/
│       ├── app.dart              Tema, provider ve başlangıç yönlendirmesi
│       ├── config/               Ortam ve uygulama ayarları
│       ├── core/                 Erişim, rol ve ortak akış kuralları
│       ├── models/               Dart veri modelleri
│       ├── providers/            Auth ve premium durum yönetimi
│       ├── screens/              Mobil ekranlar
│       ├── services/             Supabase, veri ve bildirim servisleri
│       ├── theme/                Açık/koyu tema ve tasarım sabitleri
│       └── widgets/              Tekrar kullanılabilir arayüz bileşenleri
├── admin/
│   ├── src/
│   │   ├── components/           Admin ortak bileşenleri
│   │   └── pages/                Admin modül sayfaları
│   ├── package.json              Admin bağımlılıkları ve komutları
│   └── .env.example              Admin ortam değişkeni örneği
├── assets/week/                  Haftalık gebelik görselleri
├── supabase/
│   ├── migrations/               Veritabanı migration dosyaları
│   ├── seed/                     Maternal referans veri seti
│   └── final_supabase_setup.sql  Tek parça kurulum SQL dosyası
├── test/                         Flutter testleri
├── .env.example                  Mobil ortam değişkeni örneği
└── pubspec.yaml                  Flutter bağımlılıkları ve proje ayarları
```

## Kurulum

### Gereksinimler

- Flutter SDK 3.2 veya üzeri
- Dart SDK 3.2 veya üzeri
- Android Studio veya uygun bir Flutter geliştirme ortamı
- Node.js ve npm
- Bir Supabase projesi
- Admin paneli için modern bir web tarayıcısı

### 1. Projeyi hazırlama

```bash
git clone https://github.com/c4nbayram/gebelik_takip_projesi.git
cd gebelik_takip_projesi
flutter pub get
```

### 2. Supabase veritabanını kurma

En kolay kurulum için Supabase Dashboard üzerindeki SQL Editor ekranını açıp aşağıdaki dosyanın tamamını tek seferde çalıştırmak yeterlidir:

[supabase/final_supabase_setup.sql](supabase/final_supabase_setup.sql)

Bu dosya migration ve seed işlemlerini doğru sırayla birleştirilmiş olarak içerir.

Migration dosyaları ayrı ayrı çalıştırılmak istenirse sıra:

1. `supabase/migrations/0001_init.sql`
2. `supabase/seed/maternal_reference_seed.sql`
3. `supabase/migrations/0002_tools.sql`
4. `supabase/migrations/0003_membership_notifications.sql`
5. `supabase/migrations/0004_admin.sql`
6. `supabase/migrations/0005_plans_and_ai_logs.sql`
7. `supabase/migrations/0006_support.sql`
8. `supabase/migrations/0007_symptoms_safety_consent.sql`
9. `supabase/migrations/0008_checklists_cms.sql`
10. `supabase/migrations/0009_admin_actions.sql`
11. `supabase/migrations/0010_baby_logs.sql`

SQL işlemi bittikten sonra Supabase Dashboard içinde `profiles`, `week_entries`, `plans` ve `admin_users` tablolarının oluştuğu kontrol edilebilir.

### 3. Mobil uygulama ortam değişkenleri

Proje kökündeki `.env.example` dosyasını `.env` adıyla kopyalayın:

```powershell
Copy-Item .env.example .env
```

`.env` içeriği:

```dotenv
SUPABASE_URL=https://PROJE-REFERANSI.supabase.co
SUPABASE_ANON_KEY=SUPABASE_ANON_PUBLIC_KEY
```

Bu değerler Supabase Dashboard içindeki Project Settings > API bölümünden alınır. Buraya `service_role` anahtarı yazılmamalıdır.

### 4. Mobil uygulamayı çalıştırma

Bağlı cihazları görmek için:

```bash
flutter devices
```

Uygulamayı varsayılan cihazda çalıştırmak için:

```bash
flutter run
```

Belirli bir cihazda:

```bash
flutter run -d DEVICE_ID
```

Android APK oluşturmak için:

```bash
flutter build apk --release
```

Release APK dosyası `build/app/outputs/flutter-apk/app-release.apk` altında oluşur.

### 5. Admin paneli ortam değişkenleri

```bash
cd admin
npm install
```

`admin/.env.example` dosyasını `admin/.env` adıyla kopyalayın:

```powershell
Copy-Item .env.example .env
```

`admin/.env` içeriği:

```dotenv
VITE_SUPABASE_URL=https://PROJE-REFERANSI.supabase.co
VITE_SUPABASE_ANON_KEY=SUPABASE_ANON_PUBLIC_KEY
```

Mobil uygulama ve admin paneli için aynı Supabase projesinin bilgileri kullanılmalıdır.

### 6. Admin panelini çalıştırma

```bash
npm run dev
```

Panelin yerel adresi:

```text
http://localhost:5173
```

Canlı production adresi:

```text
https://gebelik-takip-admin.vercel.app
```

Giriş bilgileri:

```text
E-posta : admin@gebelik.app
Şifre   : Admin1234!
```

Production derlemesi:

```bash
npm run build
npm run preview
```

Derlenen panel `admin/dist` klasöründe oluşur.

### 7. Admin panelini Vercel'de yayınlama

Bu repository Vercel'e bağlanırken proje ayarları aşağıdaki gibi olmalıdır:

| Vercel ayarı | Değer |
|---|---|
| Framework Preset | Vite |
| Root Directory | `admin` |
| Build Command | `npm run build` |
| Output Directory | `dist` |

Vercel projesinin Environment Variables bölümüne şu iki değer eklenmelidir:

```text
VITE_SUPABASE_URL
VITE_SUPABASE_ANON_KEY
```

React Router sayfalarının doğrudan açıldığında 404 vermemesi için [admin/vercel.json](admin/vercel.json) dosyasındaki rewrite kuralı kullanılır. GitHub bağlantısı kurulduktan sonra `main` dalına gönderilen yeni commitler otomatik olarak tekrar yayınlanabilir.

## Uygulamanın Kullanım Akışı

```text
Tanıtım Ekranları
       |
       v
Giriş Yap / Kayıt Ol / Misafir Devam Et
       |
       v
İlk Profil ve Gebelik Kurulumu
       |
       v
Ana Sayfa
       |
       +--> Haftalık Ölçüm ve Risk Değerlendirmesi
       +--> Takip Araçları
       +--> Gebelik Rehberi
       +--> Randevu ve İlaçlar
       +--> Bildirimler
       +--> Üyelik ve Premium İçerik
       +--> Profil, Destek ve Güvenlik
```

## Test ve Kalite Kontrolleri

Mobil uygulama için kullandığım kontrol komutları:

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

Admin paneli için:

```bash
cd admin
npm run build
```

Son doğrulama sonuçları:

- `flutter analyze`: sorun bulunmadı.
- `flutter test`: tüm testler geçti.
- Android debug APK derlemesi: başarılı.
- Admin paneli production build işlemi: başarılı.

## Demo ve Proje Sınırlamaları

- Ödeme sistemi gerçek bir banka veya ödeme kuruluşuna bağlı değildir; demo kayıt üretir.
- Uygulama tıbbi cihaz değildir ve risk sonucu doktor değerlendirmesinin yerine geçmez.
- Mağaza indirme sayısı için Google Play Console veya App Store Connect entegrasyonu yoktur. Admin panelindeki kullanıcı sayısı kayıtlı hesap sayısını gösterir.
- Push bildirim altyapısında cihaz kayıt tabloları bulunur; ders projesi kapsamında temel yerel ve uygulama içi bildirim akışı kullanılmıştır.
- iOS release derlemesi için macOS ve Xcode gereklidir.
- Supabase ücretsiz plan limitleri gerçek üretim ortamında kullanıcı sayısına göre yeniden değerlendirilmelidir.

## Sunum İçin Önerdiğim Akış

Projeyi sunarken aşağıdaki sırayı takip etmek bütün yapıyı kısa sürede göstermeyi kolaylaştırır:

1. README üzerindeki proje amacı ve mimariyi açıklamak.
2. Mobil uygulamada yeni bir kullanıcı kaydı oluşturmak.
3. İlk kurulumdan rol, bebek ve gebelik bilgilerini girmek.
4. Takip ekranından haftalık sağlık ölçümü eklemek.
5. KNN risk sonucunu, komşu dağılımını ve haftalık grafikleri göstermek.
6. Tekme, su, kilo, randevu ve ilaç araçlarından örnek kayıt oluşturmak.
7. Gebelik Rehberi ve acil belirti yönlendirmesini göstermek.
8. Demo premium plan satın alarak abonelik kaydı oluşturmak.
9. Admin paneline demo yönetici hesabıyla giriş yapmak.
10. Oluşturulan kullanıcıyı, risk kaydını, aboneliği ve ödemeyi admin panelinde göstermek.
11. Bildirim veya destek mesajı göndererek mobil ve admin tarafının aynı backend üzerinde çalıştığını göstermek.
12. Supabase tabloları ve RLS politikaları üzerinden güvenlik mimarisini açıklamak.

## Sonuç

Bu proje ile Flutter kullanarak çok ekranlı ve durum yönetimine sahip bir mobil uygulama geliştirdim. React ile ayrı bir yönetim paneli oluşturdum ve her iki uygulamayı Supabase üzerinde ortak bir backend'e bağladım. PostgreSQL fonksiyonları, KNN tabanlı risk değerlendirmesi, gerçek zamanlı veri, çevrimdışı önbellek, üyelik sistemi, bildirimler ve RLS güvenliği gibi farklı konuları tek bir proje içinde uygulama fırsatı buldum.

Mobil Uygulama Tasarımı ve Geliştirme dersi kapsamında hedefim yalnızca çalışan ekranlar hazırlamak değil; mobil uygulama, web paneli ve backend arasındaki veri akışını bir bütün olarak tasarlamak ve çalışan bir ürün prototipi ortaya koymaktı.

## Hazırlayan

**Bayramcan Özgül**

**Öğrenci No:** 23040101010

**İstanbul Topkapı Üniversitesi**

**Mobil Uygulama Tasarımı ve Geliştirme (EFC304)**
