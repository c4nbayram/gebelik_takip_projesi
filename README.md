# Gebelik Takip - AI Destekli Mobil Uygulama

![Flutter](https://img.shields.io/badge/Flutter-3.2+-blue)
![Dart](https://img.shields.io/badge/Dart-3.2+-blue)
![License](https://img.shields.io/badge/License-MIT-green)

## 📋 Proje Hakkında

**Gebelik Takip**, hamileler ve bebek bakıcılarına yönelik AI destekli mobil uygulama. Kullanıcılar gebelik süreci hakkında bilgi alabilir, ilaçları takip edebilir, randevularını yönetebilir ve AI asistanla sohbet aracılığıyla soru sorabilirler.

### Temel Özellikler

- 🤖 **AI Destekli Sohbet**: OpenAI entegrasyonu ile AI asistanın gerçek zamanlı danışmanlığı
- 📅 **Randevu Takibi**: Doktor randevularını yönetme ve takip etme
- 💊 **İlaç Takibi**: Kullanılan ilaçlar ve dozajlarının kaydı
- 📊 **Dashboard**: Gebelik sürecinin görsel takibi
- 👤 **Kullanıcı Profili**: Kişisel bilgiler ve sağlık durumunun yönetimi
- 🔐 **Kimlik Doğrulama**: E-posta ve parola ile güvenli login
- 💾 **Yerel Veri Depolaması**: SharedPreferences ile cihazda güvenli veri saklama
- 🌙 **Dark Mode**: Modern ve kullanıcı dostu tasarım

## 🛠️ Teknoloji Stack

| Teknoloji | Versiyon | Amaç |
|-----------|---------|------|
| Flutter | 3.2+ | UI Framework |
| Dart | 3.2+ | Programlama Dili |
| Provider | 6.1.2 | State Management |
| OpenAI API | Latest | AI İşlemleri |
| SharedPreferences | 2.2.3 | Local Storage |
| HTTP | 1.2.2 | API Çağrıları |
| Intl | 0.19.0 | Lokalizasyon |

## 📱 Uygulama Akışı

```
Onboarding → Authentication → Initial Setup → Home Dashboard
```

### Ekranlar

1. **Onboarding Screen** - Uygulamaya hoş geldin mesajı ve tanıtım
2. **Auth Screen** - Login ve kayıt işlemleri
3. **Initial Setup Screen** - Kullanıcı bilgilerinin ilk kurulumu
4. **Main Shell** - Ana uygulama arayüzü
   - Dashboard - Ana sayfa ve özet bilgiler
   - Appointments - Randevu yönetimi
   - Medications - İlaç takibi
   - Track - İlerleme takibi
   - Chat - AI asistanla sohbet
   - Profile - Profil ayarları

## 🚀 Kurulum

### Ön Koşullar

- Flutter SDK 3.2.0 veya üzeri ([Kurulum](https://flutter.dev/docs/get-started/install))
- Dart 3.2.0 veya üzeri (Flutter SDK ile birlikte gelir)
- OpenAI API Key (Chat özelliği için isteğe bağlı)

### Adım 1: Repository'i Clone Et

```bash
git clone https://github.com/yourusername/gebelik_takip_projesi.git
cd gebelik_takip_projesi
```

### Adım 2: Bağımlılıkları Yükle

```bash
flutter pub get
```

### Adım 3: OpenAI API Key Konfigürasyonu (İsteğe Bağlı)

AI sohbet özelliğini kullanmak için OpenAI API key'i ayarla:

1. `lib/src/config/app_config.dart` dosyasını aç
2. `openAiApiKey` değişkenini güncelle:

```dart
class AppConfig {
  static const String openAiApiKey = "YOUR_OPENAI_API_KEY_HERE";
  static const bool localOnly = false; // API kullanmak için false yapın
}
```

**Not**: Production'a push etmeden API key'i kaldırmayı unutma!

### Adım 4: Uygulamayı Çalıştır

```bash
# Varsayılan cihazda çalıştır
flutter run

# Belirli bir cihazda çalıştır
flutter run -d <device_id>

# Release modda çalıştır
flutter run --release
```

## 💻 Geliştirme

### Proje Yapısı

```
lib/
├── main.dart                          # Uygulamaya giriş noktası
├── src/
│   ├── app.dart                       # Ana uygulama widget'ı
│   ├── config/
│   │   └── app_config.dart           # Global konfigürasyonlar
│   ├── core/
│   │   └── entry_flow_signal.dart    # Navigasyon yönetimi
│   ├── models/
│   │   └── app_models.dart           # Veri modelleri
│   ├── providers/
│   │   └── auth_provider.dart        # State management (kimlik doğrulama)
│   ├── screens/
│   │   ├── auth_screen.dart          # Login/Register ekranı
│   │   ├── dashboard_screen.dart     # Ana sayfa
│   │   ├── appointments_screen.dart  # Randevu yönetimi
│   │   ├── medications_screen.dart   # İlaç takibi
│   │   ├── track_screen.dart         # İlerleme takibi
│   │   ├── chat_screen.dart          # AI sohbet ekranı
│   │   ├── profile_screen.dart       # Profil ayarları
│   │   ├── onboarding_screen.dart    # Tanıtım ekranı
│   │   ├── initial_setup_screen.dart # İlk kurulum
│   │   └── main_shell.dart           # Ana uygulama kabuğu
│   ├── services/
│   │   ├── api_service.dart          # API çağrıları
│   │   └── local_account_store.dart  # Yerel veri depolaması
│   ├── theme/
│   │   ├── app_tokens.dart           # Renk ve stil tanımlamaları
│   │   └── ...                       # Tema dosyaları
│   └── widgets/
│       └── calm_background.dart      # Özel widget'lar
├── assets/
│   └── week/                          # Gebelik haftası bilgileri
└── pubspec.yaml                       # Proje bağımlılıkları
```

### Önemli Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `lib/src/config/app_config.dart` | API key, URL ve flag ayarları |
| `lib/src/providers/auth_provider.dart` | Kimlik doğrulama ve state yönetimi |
| `lib/src/services/api_service.dart` | Backend API ile iletişim |
| `lib/src/theme/app_tokens.dart` | Tasarım sistem ve renk paleti |

## 📊 Veri Modelleri

### Kullanıcı (User)
```dart
- id: String
- email: String
- name: String
- role: String (caregiver_role)
- babyName: String
- city: String
- birthDate: DateTime?
- lastPeriodStart: DateTime?
- estimatedDueDate: DateTime?
- planningBaby: bool
- maternalChronicCondition: String?
```

### Randevu (Appointment)
```dart
- id: String
- title: String
- date: DateTime
- time: String
- doctor: String
- notes: String?
```

### İlaç (Medication)
```dart
- id: String
- name: String
- dosage: String
- frequency: String
- startDate: DateTime
- notes: String?
```

## 🔌 API Entegrasyonu

### OpenAI Chat API

AI sohbet özelliği OpenAI API'sini kullanır:

```dart
// lib/src/services/api_service.dart
Future<String> chatWithAI(String message) async {
  // OpenAI'a POST isteği gönder
  // Cevap döndür veya fallback cevap kullan
}
```

**Fallback Mekanizması**: OpenAI hatası durumunda uygulama yerel cevaplar sağlayarak kullanıcı deneyimini kesintisiz tutmaya çalışır.

## 🔐 Güvenlik

- ✅ Kimlik doğrulama akışı
- ✅ Yerel veri şifreleme (SharedPreferences)
- ✅ HTTPS API çağrıları
- ✅ API key güvenli konfigürasyonu

**Best Practices**:
- API key'leri hiçbir zaman repository'ye commit etme
- Environment variables veya secure storage kullan
- Harici bağımlılıkları düzenli güncelle

## 🧪 Test Etme

### Manuel Test

```bash
# Onboarding akışını test et
flutter run

# Debug modda çalıştır
flutter run -v

# Specific device üzerinde test et
flutter run -d <device_id>
```

### Hot Reload
```bash
# Değişiklikleri anında uygulamaya yansıt
r (konsolia yazıp Enter)
```

## 📦 Build Etme

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

## ⚙️ Konfigürasyon

### app_config.dart Ayarları

```dart
class AppConfig {
  // API Konfigürasyonu
  static const String apiBaseUrl = "http://10.0.2.2:3000"; // Emülatör için
  static const String openAiApiKey = "sk-...";
  static const bool localOnly = true; // Yerel mod
  
  // SharedPreferences Keys
  static const String seenOnboardingKey = "seen_onboarding";
  static const String authStepDoneKey = "auth_step_done";
  static const String guestModeKey = "guest_mode";
  // ... diğer ayarlar
}
```

## 📝 Geliştirme Notları

### State Management
- **Provider**: Kimlik doğrulama ve global state'i yönetmek için kullanılır
- **Listen**: UI güncellemelerini tetiklemek için ChangeNotifier pattern'i kullanılır

### Navigation
- **Stateful Widget**: Onboarding → Auth → Setup → Home akışını yönetir
- **EntryFlowSignal**: Navigasyon durumunu değiştirir

### Yerel Depolama
- **SharedPreferences**: Kullanıcı tercihleri ve basit veriler
- **LocalAccountStore**: Daha karmaşık veri yapıları için

## 🤝 Katkı

Bu proje aktif olarak geliştirilmektedir. Geliştirilmesi gereken alanlar:

- [ ] Backend API entegrasyonunun tamamlanması
- [ ] Daha fazla AI soru-cevap kategorileri
- [ ] Grafik ve istatistik paneli
- [ ] Push notification sistemi
- [ ] Offline mode iyileştirmesi

## 📄 Lisans

Bu proje MIT Lisansı altında lisanslıdır - [LICENSE](LICENSE) dosyasına bakın.

## 👨‍💻 Geliştirici Bilgileri

- **Geliştirici**: Bayramcan Özgül
- **E-posta**: canbayram.ozgul@gmail.com
- **GitHub**: [c4nbayram](https://github.com/c4nbayram)

## 📞 Destek

Sorularınız veya sorunlar için:
- GitHub Issues'te bir issue açın
- E-posta ile iletişim kurun

## 🎯 Hedefler ve Vizyonu

Bu uygulama, hamilelerin ve bebek bakıcılarının sağlık takiplerini dijitalleştirmeyi ve AI asistanı aracılığıyla güvenilir bilgi alabilmelerini sağlamayı hedeflemektedir. Özellikle kısıtlı sağlık hizmetlerine erişimi olan bölgelerde büyük bir fark yaratabilecek potansiyele sahiptir.

---

**Son Güncelleme**: 2026-06-11
