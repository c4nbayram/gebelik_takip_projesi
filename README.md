# Gebelik Takip Mobil Uygulaması

## Proje Hakkında

Bu proje, hamileler ve bebek bakıcılarına gebelik süreci boyunca destek sağlayan bir mobil uygulamadır. Uygulama, kullanıcılara gebelik hakkında bilgi edinme, ilaçlarını takip etme, doktor randevularını yönetme ve danışmanlık hizmeti sunmaktadır.

## Temel Özellikler

- Sohbet Aracı: Gebelik süreci hakkında sorular sorabilme ve danışmanlık alabilme
- Randevu Takibi: Doktor randevularını yönetme ve takip etme
- İlaç Takibi: Kullanılan ilaçlar ve dozajlarının kaydı
- Dashboard: Gebelik sürecinin görsel takibi
- Kullanıcı Profili: Kişisel bilgiler ve sağlık durumunun yönetimi
- Kimlik Doğrulama: E-posta ve parola ile güvenli giriş
- Yerel Veri Depolaması: Cihazda güvenli veri saklama

## Teknoloji Stack

| Teknoloji | Versiyon | Amaç |
|-----------|---------|------|
| Flutter | 3.2+ | Mobil UI Framework |
| Dart | 3.2+ | Programlama Dili |
| Provider | 6.1.2 | State Management |
| SharedPreferences | 2.2.3 | Yerel Veri Depolaması |
| HTTP | 1.2.2 | API Çağrıları |
| Intl | 0.19.0 | Dil Desteği |

## Uygulama Akışı

```
Onboarding → Authentication → İlk Kurulum → Ana Sayfa
```

## Ekranlar

1. Onboarding Screen - Uygulamaya hoş geldin
2. Auth Screen - Giriş ve kayıt
3. Initial Setup Screen - Kişisel bilgileri doldurma
4. Main Shell - Ana uygulama
   - Dashboard - Ana sayfa
   - Appointments - Randevu yönetimi
   - Medications - İlaç takibi
   - Track - İlerleme takibi
   - Chat - Danışmanlık hizmeti
   - Profile - Profil ayarları

## Kurulum

### Ön Koşullar

- Flutter SDK 3.2.0 veya üzeri ([Kurulum](https://flutter.dev/docs/get-started/install))
- Dart 3.2.0 veya üzeri
- Danışmanlık hizmeti için kendi API anahtarınız

### Adım 1: Repository'i İndir

```bash
git clone https://github.com/yourusername/gebelik_takip_projesi.git
cd gebelik_takip_projesi
```

### Adım 2: Bağımlılıkları Yükle

```bash
flutter pub get
```

### Adım 3: API Anahtarı Konfigürasyonu

Uygulama şu anda lokal ortamda çalıştığı için danışmanlık hizmetini kullanmak istiyorsanız kendi API anahtarınızı yapılandırmanız gereklidir.

1. `lib/src/config/app_config.dart` dosyasını aç
2. Aşağıdaki bölümü bulun:

```dart
class AppConfig {
  static const String openAiApiKey = "PUT_OPENAI_API_KEY_HERE";
  static const bool localOnly = true;
}
```

3. `openAiApiKey` değerini kendi API anahtarınızla değiştirin
4. `localOnly` değerini `false` olarak ayarlayın

**Önemli Not**: API anahtarınızı hiçbir zaman repository'ye commit etmeyin!

### Adım 4: Uygulamayı Çalıştır

```bash
# Varsayılan cihazda çalıştır
flutter run

# Belirli bir cihazda çalıştır
flutter run -d <device_id>

# Release modda çalıştır
flutter run --release
```

## Proje Yapısı

```
lib/
├── main.dart                          # Giriş noktası
├── src/
│   ├── app.dart                       # Ana uygulama
│   ├── config/
│   │   └── app_config.dart           # Ayarlar
│   ├── core/
│   │   └── entry_flow_signal.dart    # Navigasyon
│   ├── models/
│   │   └── app_models.dart           # Veri modelleri
│   ├── providers/
│   │   └── auth_provider.dart        # Kimlik doğrulama
│   ├── screens/
│   │   ├── auth_screen.dart          # Giriş ekranı
│   │   ├── dashboard_screen.dart     # Ana sayfa
│   │   ├── appointments_screen.dart  # Randevu yönetimi
│   │   ├── medications_screen.dart   # İlaç takibi
│   │   ├── track_screen.dart         # İlerleme takibi
│   │   ├── chat_screen.dart          # Danışmanlık
│   │   ├── profile_screen.dart       # Profil
│   │   ├── onboarding_screen.dart    # Tanıtım
│   │   ├── initial_setup_screen.dart # İlk kurulum
│   │   └── main_shell.dart           # Ana kabuk
│   ├── services/
│   │   ├── api_service.dart          # API çağrıları
│   │   └── local_account_store.dart  # Yerel depolama
│   ├── theme/
│   │   └── app_tokens.dart           # Stil ve renkler
│   └── widgets/
│       └── calm_background.dart      # Özel tasarım öğeleri
├── assets/
│   └── week/                          # Haftalık bilgiler
└── pubspec.yaml                       # Proje ayarları
```

## Önemli Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `lib/src/config/app_config.dart` | API anahtarı ve ayarları |
| `lib/src/providers/auth_provider.dart` | Giriş işlemleri ve durum yönetimi |
| `lib/src/services/api_service.dart` | Sunucu ile iletişim |
| `lib/src/theme/app_tokens.dart` | Renkler ve tasarım |

## Veri Modelleri

### Kullanıcı
```dart
- id: String
- email: String
- name: String
- role: String
- babyName: String
- city: String
- birthDate: DateTime?
- lastPeriodStart: DateTime?
- estimatedDueDate: DateTime?
- planningBaby: bool
- maternalChronicCondition: String?
```

### Randevu
```dart
- id: String
- title: String
- date: DateTime
- time: String
- doctor: String
- notes: String?
```

### İlaç
```dart
- id: String
- name: String
- dosage: String
- frequency: String
- startDate: DateTime
- notes: String?
```

## API Entegrasyonu

Sohbet ve danışmanlık özelliği harici bir API ile çalışır. API çağrısı başarısız olursa uygulama yerel cevaplar kullanarak çalışmaya devam eder, böylece kullanıcı deneyimi kesintisiz kalır.

```dart
// lib/src/services/api_service.dart
Future<String> chatWithAI(String message) async {
  // API'ye istek gönder
  // Cevap al ya da yerel cevap kullan
}
```

## Güvenlik

- Kimlik doğrulama sistemi
- Yerel veri depolaması
- API çağrılarında HTTPS
- API anahtarının güvenli konfigürasyonu

**Öneriler**:
- API anahtarlarını asla code'a yazma
- Environment variables kullan
- Bağımlılıkları düzenli güncelle

## Test Etme

```bash
# Uygulamayı çalıştır
flutter run

# Debug modda çalıştır
flutter run -v

# Hot reload (Ctrl+R ya da konsolda 'r' yaz)
```

## Build Etme

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### iOS

```bash
flutter build ios --release
# Output: build/ios/iphoneos/Runner.app
```

## Ayarlar

`lib/src/config/app_config.dart` dosyasında şu ayarları değiştirebilirsin:

```dart
class AppConfig {
  // API Sunucusu
  static const String apiBaseUrl = "http://10.0.2.2:3000";
  
  // API Anahtarı
  static const String openAiApiKey = "YOUR_KEY_HERE";
  
  // Yerel mod (API kullanmadan çalış)
  static const bool localOnly = true;
  
  // Depolama anahtarları
  static const String seenOnboardingKey = "seen_onboarding";
  static const String authStepDoneKey = "auth_step_done";
  static const String guestModeKey = "guest_mode";
}
```

## Geliştirme Notları

### Durum Yönetimi
- Provider kütüphanesi kullanılır
- ChangeNotifier pattern ile UI güncellemesi sağlanır

### Navigasyon
- Onboarding → Giriş → Kurulum → Ana Sayfa akışı
- EntryFlowSignal ile navigasyon kontrol edilir

### Veri Depolaması
- SharedPreferences: Basit veriler için
- LocalAccountStore: Daha karmaşık veriler için

## İyileştirme Alanları

- Backend API entegrasyonunun tamamlanması
- Daha fazla danışmanlık kategorisi
- Grafik ve istatistik paneli
- Bildirim sistemi
- Çevrimdışı mod

## Lisans

MIT Lisansı - Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## Geliştirici

- **Ad**: Bayramcan Özgül
- **E-posta**: canbayram.ozgul@gmail.com
- **GitHub**: [c4nbayram](https://github.com/c4nbayram)

## Destek ve İletişim

Soru veya sorun için:
- GitHub'da issue açın
- E-posta ile iletişim kurun

## Amaç

Bu uygulama, hamilelerin ve bakıcıların sağlık takiplerini dijitalleştirmeyi amaçlar. Özellikle sağlık hizmetlerine erişimi sınırlı olan bölgelerde kullanılabilir.

---

Son Güncelleme: 2026-06-11
