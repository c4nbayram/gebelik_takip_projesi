# Gebelik Bebek Takip - Flutter Projesi

Bu klasor, web versiyonundan ilham alarak sifirdan kurulmus Flutter mobil iskeletidir.

## Baslatma

```
cd flutter_baby_tracker
flutter pub get
flutter run
```

Emülatörde lokal backend kullanmak icin:

```
flutter run --dart-define=API_BASE_URL=http://10.0.2.2/gebelik_projesi
```

### Mobil + Web Backend Entegrasyonu Notu

Mobil taraf bu projede asagidaki endpointleri bekler:

- `POST /api/auth_login.php`
- `POST /api/auth_register.php`
- `GET /api/auth_me.php`
- `POST /api/auth_logout.php`
- `GET /api/week_info.php?week=...` (mevcut endpoint mevcut)
- `GET /api/week_entries.php` (beklenen liste endpoint)
- `POST /api/analyze.php` (mevcut endpoint mevcut)
- `POST /api/chat.php` (mevcut endpoint mevcut)
- `POST /api/profile.php` (mevcut endpoint)
- `GET/POST/DELETE /api/appointments.php` (beklenen endpoint)
- `GET/POST/DELETE /api/medications.php` (beklenen endpoint)

Senaryo olarak web kodu su an session tabanli calisiyor. Mobilde daha saglam calisabilmesi icin
API'leri token bazli cagrilabilir hale getirmen gerekir.

