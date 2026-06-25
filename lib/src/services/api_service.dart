import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import '../config/app_config.dart';
import '../core/setup_options.dart';
import '../models/app_models.dart';
import 'supabase_client.dart';

class ApiService {
  ApiService({this.baseUrl = "", this.localOnly = false});

  final String baseUrl;

  final bool localOnly;

  bool get _online => SupabaseBootstrap.isReady;
  SupabaseClient get _sb => SupabaseBootstrap.client;
  String? get _uid => _online ? _sb.auth.currentUser?.id : null;

  static const String _localWeekEntriesKey = "gebelik_local_week_entries";
  static const String _localAppointmentsKey = "gebelik_local_appointments";
  static const String _localMedicationsKey = "gebelik_local_medications";
  static const String _localProfileNameKey = AppConfig.profileNameKey;
  static const String _localProfileAgeKey = AppConfig.profileAgeKey;
  static const String _localProfileMedicalKey = AppConfig.profileMedicalKey;
  static const String _userEmailKey = "gebelik_user_email";
  static const String _currentWeekKey = "gebelik_current_week";

  static const List<String> _profileCacheKeys = [
    AppConfig.profileNameKey,
    AppConfig.profileAgeKey,
    AppConfig.profileMedicalKey,
    AppConfig.caregiverRoleKey,
    AppConfig.babyNameKey,
    AppConfig.babyCityKey,
    AppConfig.babyBirthDateKey,
    AppConfig.lastPeriodStartKey,
    AppConfig.estimatedDueDateKey,
    AppConfig.planningBabyKey,
    AppConfig.maternalChronicKey,
    AppConfig.firstSetupDoneKey,
  ];

  Future<SharedPreferences> _prefs() async => SharedPreferences.getInstance();

  Future<void> restoreSession() async {}

  bool get hasToken => _uid != null;

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!_online) {
      throw Exception(
          "Sunucu yapilandirilmamis. Lutfen internet baglantini ve uygulama ayarlarini kontrol et.");
    }
    final res = await _sb.auth.signUp(
      email: email.trim(),
      password: password,
      data: {"name": name.trim()},
    );
    final user = res.user;
    if (user == null) {
      throw Exception("Kayit tamamlanamadi.");
    }
    if (res.session == null) {
      throw Exception(
          "Hesap olusturuldu ancak e-posta dogrulamasi gerekiyor. Lutfen e-postani onayla ve giris yap.");
    }
    try {
      await _sb.from("profiles").update({
        "name": name.trim(),
        "email": email.trim(),
      }).eq("id", user.id);
    } catch (_) {}
    final profile = await _fetchProfileRow(user.id);
    final up = _userFromProfile(user.id, email.trim(), profile,
        fallbackName: name.trim());
    await _cacheProfileToPrefs(up, profile);
    return up;
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    if (!_online) {
      throw Exception(
          "Sunucu yapilandirilmamis. Lutfen internet baglantini kontrol et.");
    }
    final res = await _sb.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw Exception("Giris basarisiz oldu.");
    }
    final profile = await _fetchProfileRow(user.id);
    final up = _userFromProfile(user.id, user.email ?? email.trim(), profile);
    await _cacheProfileToPrefs(up, profile);
    return up;
  }

  Future<UserProfile> fetchMe() async {
    if (!_online) {
      throw Exception("Aktif oturum bulunamadi.");
    }
    final user = _sb.auth.currentUser;
    if (user == null) {
      throw Exception("Aktif oturum bulunamadi.");
    }
    final profile = await _fetchProfileRow(user.id);
    if (profile != null && profile["is_active"] == false) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
      throw Exception(
          "Hesabin devre disi birakildi. Destek ile iletisime gec.");
    }
    final up = _userFromProfile(user.id, user.email ?? "", profile);
    await _cacheProfileToPrefs(up, profile);
    return up;
  }

  Future<void> logout() async {
    if (_online) {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    final prefs = await _prefs();
    for (final k in _profileCacheKeys) {
      await prefs.remove(k);
    }
    await prefs.remove(_userEmailKey);
    await prefs.remove(_localWeekEntriesKey);
    await prefs.remove(_localAppointmentsKey);
    await prefs.remove(_localMedicationsKey);
    await prefs.remove(_currentWeekKey);
  }

  Future<Map<String, dynamic>?> _fetchProfileRow(String id) async {
    try {
      final row =
          await _sb.from("profiles").select().eq("id", id).maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  UserProfile _userFromProfile(
    String id,
    String email,
    Map<String, dynamic>? p, {
    String? fallbackName,
  }) {
    final pName = (p?["name"] as String?)?.trim() ?? "";
    final pEmail = (p?["email"] as String?)?.trim() ?? "";
    return UserProfile(
      id: id,
      name: pName.isNotEmpty ? pName : (fallbackName ?? ""),
      email: pEmail.isNotEmpty ? pEmail : email,
      age: (p?["age"] as num?)?.toInt(),
      medicalHistory: (p?["medical_history"] as String?)?.trim(),
    );
  }

  Future<void> _cacheProfileToPrefs(
      UserProfile up, Map<String, dynamic>? p) async {
    final prefs = await _prefs();
    await prefs.setString(_localProfileNameKey, up.name);
    await prefs.setString(_userEmailKey, up.email);
    if (up.age != null) {
      await prefs.setInt(_localProfileAgeKey, up.age!);
    }
    if (up.medicalHistory != null) {
      await prefs.setString(_localProfileMedicalKey, up.medicalHistory!);
    }
    if (p == null) return;

    Future<void> writeStr(String key, String? value) async {
      if (value != null && value.trim().isNotEmpty) {
        await prefs.setString(key, value.trim());
      }
    }

    Future<void> writeDate(String key, String? value) async {
      if (value == null || value.trim().isEmpty) return;
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        await prefs.setInt(key, parsed.millisecondsSinceEpoch);
      }
    }

    final caregiverRole = (p["caregiver_role"] as String?)?.trim() ?? "";
    await writeStr(AppConfig.caregiverRoleKey, caregiverRole);
    await writeStr(AppConfig.babyNameKey, p["baby_name"] as String?);
    await writeStr(AppConfig.babyCityKey, p["city"] as String?);
    await writeStr(
        AppConfig.maternalChronicKey, p["maternal_chronic"] as String?);
    await writeDate(
        AppConfig.babyBirthDateKey, p["baby_birth_date"] as String?);
    await writeDate(
        AppConfig.lastPeriodStartKey, p["last_period_start"] as String?);
    await writeDate(
        AppConfig.estimatedDueDateKey, p["estimated_due_date"] as String?);
    await prefs.setBool(
        AppConfig.planningBabyKey, (p["planning_baby"] as bool?) ?? false);
    await prefs.setBool(AppConfig.firstSetupDoneKey, caregiverRole.isNotEmpty);
  }

  Future<void> syncProfileToBackend() async {
    final uid = _uid;
    if (!_online || uid == null) return;
    final prefs = await _prefs();

    String? readStr(String key) {
      final v = prefs.getString(key)?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    String? readDate(String key) {
      final ms = prefs.getInt(key);
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms)
          .toIso8601String()
          .split("T")
          .first;
    }

    final caregiverRole = readStr(AppConfig.caregiverRoleKey);
    final maternalChronic = caregiverRole == SetupOptions.motherRole
        ? readStr(AppConfig.maternalChronicKey)
        : null;

    try {
      await _sb.from("profiles").upsert({
        "id": uid,
        "name": readStr(AppConfig.profileNameKey) ?? "",
        "email": readStr(_userEmailKey) ?? (_sb.auth.currentUser?.email ?? ""),
        "age": prefs.getInt(AppConfig.profileAgeKey),
        "medical_history": readStr(AppConfig.profileMedicalKey),
        "caregiver_role": caregiverRole,
        "baby_name": readStr(AppConfig.babyNameKey),
        "city": readStr(AppConfig.babyCityKey),
        "baby_birth_date": readDate(AppConfig.babyBirthDateKey),
        "last_period_start": readDate(AppConfig.lastPeriodStartKey),
        "estimated_due_date": readDate(AppConfig.estimatedDueDateKey),
        "planning_baby": prefs.getBool(AppConfig.planningBabyKey) ?? false,
        "maternal_chronic": maternalChronic,
      });
    } catch (_) {}
  }

  String _babyPossessive(String? babyName) {
    final trimmed = (babyName ?? "").trim();
    if (trimmed.isEmpty) return "Bebeginizin";
    return "$trimmed'in";
  }

  Future<WeekInfo> getWeekInfo(int weekNo) async {
    final prefs = await _prefs();
    final babyName = prefs.getString(AppConfig.babyNameKey);
    return WeekInfo(weekNo: weekNo, text: _weekContent(weekNo, babyName));
  }

  String _weekContent(int week, String? babyName) {
    final baby = _babyPossessive(babyName);
    if (week <= 4) {
      return "$baby yolculugu yeni basliyor. Bu ilk haftalarda hucreler hizla bolunuyor ve yerlesim tamamlaniyor. Folik asit takviyesi, dengeli beslenme ve sigara/alkolden uzak durmak su an en kiymetlisi.";
    }
    if (week <= 8) {
      return "$baby $week. haftasinda kalp atisi baslamis, temel organ taslaklari sekilleniyor. Bulanti ve yorgunluk olabilir; az ve sik ogun, bol su ve dinlenme rahatlatir.";
    }
    if (week <= 12) {
      return "$baby $week. haftasinda ilk trimesterin sonuna yaklasiyor. Organlar belirginlesiyor, dusuk riski azaliyor. Ilk tarama testleri icin doktor randevunu planlamak iyi olur.";
    }
    if (week <= 16) {
      return "$baby $week. haftasinda ikinci trimestere girdin. Enerjin genelde toparlanir, mide sikayetleri azalir. Dengeli protein ve demir alimina ozen goster.";
    }
    if (week <= 20) {
      return "$baby $week. haftasinda ilk hareketlerini hissetmeye baslayabilirsin. Bu donemde ayrintili ultrason (anomali taramasi) yapilir. Su tuketimi ve hafif yuruyusler iyi gelir.";
    }
    if (week <= 24) {
      return "$baby $week. haftasinda duyma duyusu gelisiyor; sesine tepki verebilir. Bacaklarda sislik olabilir, dinlenirken ayaklarini yukari almak rahatlatir.";
    }
    if (week <= 28) {
      return "$baby $week. haftasinda ucuncu trimester basliyor. Kilo alimi ve seker dengesi onem kazanir; bu donemde gestasyonel diyabet taramasi yapilabilir.";
    }
    if (week <= 32) {
      return "$baby $week. haftasinda hizla buyuyor ve hareketleri belirginlesiyor. Hareket sayisini takip etmek faydali. Sirt ve bel agrisi icin dogru durus ve destek yastigi yardimci olur.";
    }
    if (week <= 36) {
      return "$baby $week. haftasinda akcigerler olgunlasiyor, bebek doguma hazirlaniyor. Dogum cantasini hazirlamak ve dogum planini doktorunla konusmak icin iyi bir zaman.";
    }
    return "$baby $week. haftasinda artik term donemde. Kasik basinci, seyrek kasilmalar olabilir. Duzenli kasilma, su gelmesi veya kanama olursa beklemeden saglik kurulusuna basvur.";
  }

  WeekEntry _weekEntryFromRow(Map<String, dynamic> row) {
    return WeekEntry(
      weekNo: (row["week_no"] as num?)?.toInt() ?? 0,
      riskScore: (row["risk_score"] as num?)?.toDouble(),
      riskLabel: (row["risk_label"] as String?)?.trim(),
      updatedAt: DateTime.tryParse(
          (row["updated_at"] ?? row["created_at"])?.toString() ?? ""),
      systolic: (row["systolic"] as num?)?.toDouble(),
      diastolic: (row["diastolic"] as num?)?.toDouble(),
      bloodSugar: (row["blood_sugar"] as num?)?.toDouble(),
      bodyTemp: (row["body_temp"] as num?)?.toDouble(),
      bmi: (row["bmi"] as num?)?.toDouble(),
      heartRate: (row["heart_rate"] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> _entryToJson(WeekEntry e) => {
        "week_no": e.weekNo,
        "risk_score": e.riskScore,
        "risk_label": e.riskLabel,
        "updated_at": e.updatedAt?.toIso8601String(),
        "systolic_bp": e.systolic,
        "diastolic": e.diastolic,
        "bs": e.bloodSugar,
        "body_temp": e.bodyTemp,
        "bmi": e.bmi,
        "heart_rate": e.heartRate,
      };

  Future<List<WeekEntry>> _loadLocalEntries() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_localWeekEntriesKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => WeekEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> _saveLocalEntries(List<WeekEntry> entries) async {
    final prefs = await _prefs();
    final list = entries.map(_entryToJson).toList(growable: false);
    await prefs.setString(_localWeekEntriesKey, jsonEncode(list));
  }

  Future<List<WeekEntry>> getWeekEntries() async {
    final uid = _uid;
    if (_online && uid != null) {
      try {
        final rows = await _sb
            .from("week_entries")
            .select()
            .eq("user_id", uid)
            .order("week_no") as List;
        final entries = rows
            .map((r) => _weekEntryFromRow(r as Map<String, dynamic>))
            .toList(growable: false);
        await _saveLocalEntries(entries);
        return entries;
      } catch (_) {
        return _loadLocalEntries();
      }
    }
    return _loadLocalEntries();
  }

  Stream<List<WeekEntry>> weekEntriesStream() {
    final uid = _uid;
    if (!_online || uid == null) {
      return Stream<List<WeekEntry>>.value(const []);
    }
    return _sb
        .from("week_entries")
        .stream(primaryKey: ["id"])
        .eq("user_id", uid)
        .order("week_no")
        .map((rows) =>
            rows.map((r) => _weekEntryFromRow(r)).toList(growable: false));
  }

  Future<HealthAnalyzeResult> analyzeWeek(HealthAnalyzeRequest request) async {
    final prefs = await _prefs();
    final medicalContext = _combinedMedicalContext(
      explicitMedical: request.medicalHistory,
      profileMedical: prefs.getString(_localProfileMedicalKey),
      maternalChronic: prefs.getString(AppConfig.maternalChronicKey),
    );
    final existingEntries = await getWeekEntries();
    WeekEntry? previousEntry;
    for (final entry in existingEntries) {
      if (entry.weekNo < request.weekNo &&
          (previousEntry == null || entry.weekNo > previousEntry.weekNo)) {
        previousEntry = entry;
      }
    }

    double score;
    String label;
    int knnK = 0;
    int knnHigh = 0;
    int knnMid = 0;
    int knnLow = 0;
    double avgDistance = 0;
    String source = "local";

    final uid = _uid;
    Map<String, dynamic>? knn;
    if (_online && uid != null) {
      try {
        final age =
            request.profileAge ?? prefs.getInt(_localProfileAgeKey) ?? 28;
        final res = await _sb.rpc("classify_maternal_risk", params: {
          "p_age": age,
          "p_systolic": request.systolic,
          "p_diastolic": request.diastolic,
          "p_bs": request.bloodSugar,
          "p_body_temp": request.bodyTemp,
          "p_heart_rate": request.heartRate,
          "p_k": 15,
        });
        if (res is Map) {
          knn = Map<String, dynamic>.from(res);
        }
      } catch (_) {
        knn = null;
      }
    }

    if (knn != null) {
      score = (knn["risk_score"] as num?)?.toDouble() ?? 0.05;
      label = _labelTr((knn["risk_label"] as String?) ?? "low");
      knnK = (knn["k"] as num?)?.toInt() ?? 0;
      knnHigh = (knn["high_count"] as num?)?.toInt() ?? 0;
      knnMid = (knn["mid_count"] as num?)?.toInt() ?? 0;
      knnLow = (knn["low_count"] as num?)?.toInt() ?? 0;
      avgDistance = (knn["avg_distance"] as num?)?.toDouble() ?? 0;
      source = "dataset";
    } else {
      final local = _localRiskScore(request, previousEntry, medicalContext);
      score = local.$1;
      label = local.$2;
      knnK = 5;
      knnHigh = score > 0.66 ? 4 : (score > 0.33 ? 2 : 1);
    }

    final entry = WeekEntry(
      weekNo: request.weekNo,
      riskScore: score,
      riskLabel: label,
      updatedAt: DateTime.now(),
      systolic: request.systolic,
      diastolic: request.diastolic,
      bloodSugar: request.bloodSugar,
      bodyTemp: request.bodyTemp,
      bmi: request.bmi,
      heartRate: request.heartRate,
    );

    List<WeekEntry> updated;
    if (_online && uid != null) {
      try {
        await _sb.from("week_entries").upsert({
          "user_id": uid,
          "week_no": request.weekNo,
          "systolic": request.systolic,
          "diastolic": request.diastolic,
          "blood_sugar": request.bloodSugar,
          "body_temp": request.bodyTemp,
          "bmi": request.bmi,
          "heart_rate": request.heartRate,
          "risk_score": score,
          "risk_label": label,
          "knn_k": knnK,
          "knn_high": knnHigh,
        }, onConflict: "user_id,week_no");
        updated = await getWeekEntries();
      } catch (_) {
        updated = _mergeEntry(existingEntries, entry);
        await _saveLocalEntries(updated);
      }
    } else {
      updated = _mergeEntry(existingEntries, entry);
      await _saveLocalEntries(updated);
    }

    final insight = await buildTrackingInsight(
      selectedWeek: request.weekNo,
      weekEntries: updated,
    );
    final advice = _buildLocalAdviceFromInsight(insight);

    if (_online && uid != null) {
      try {
        await _sb.from("analysis_logs").insert({
          "user_id": uid,
          "week_no": request.weekNo,
          "age": request.profileAge ?? prefs.getInt(_localProfileAgeKey),
          "systolic": request.systolic,
          "diastolic": request.diastolic,
          "blood_sugar": request.bloodSugar,
          "body_temp": request.bodyTemp,
          "bmi": request.bmi,
          "heart_rate": request.heartRate,
          "risk_label": label,
          "risk_score": score,
          "knn_k": knnK,
          "knn_high": knnHigh,
          "knn_mid": knnMid,
          "knn_low": knnLow,
          "avg_distance": avgDistance,
          "source": source,
          "guidance_note": advice,
        });
      } catch (_) {}
    }

    return HealthAnalyzeResult(
      weekNo: request.weekNo,
      riskLabel: label,
      riskScore: score,
      knnK: knnK,
      knnHigh: knnHigh,
      knnMid: knnMid,
      knnLow: knnLow,
      avgDistance: avgDistance,
      aiAdvice: advice,
      source: source,
    );
  }

  List<WeekEntry> _mergeEntry(List<WeekEntry> existing, WeekEntry entry) {
    final updated =
        existing.where((e) => e.weekNo != entry.weekNo).toList(growable: true);
    updated.add(entry);
    updated.sort((a, b) => a.weekNo.compareTo(b.weekNo));
    return updated;
  }

  String _labelTr(String en) {
    switch (en.toLowerCase()) {
      case "high":
        return "Yuksek";
      case "mid":
        return "Orta";
      default:
        return "Dusuk";
    }
  }

  (double, String) _localRiskScore(
    HealthAnalyzeRequest request,
    WeekEntry? previousEntry,
    String medicalContext,
  ) {
    double score = 0.05;
    if (request.systolic >= 140) {
      score += 0.25;
    } else if (request.systolic >= 120) {
      score += 0.12;
    }
    if (request.diastolic >= 90) {
      score += 0.2;
    } else if (request.diastolic >= 80) {
      score += 0.1;
    }
    if (request.bloodSugar >= 140) {
      score += 0.18;
    } else if (request.bloodSugar >= 110) {
      score += 0.08;
    }
    if (request.bodyTemp >= 38.0) {
      score += 0.15;
    } else if (request.bodyTemp >= 37.2) {
      score += 0.05;
    }
    if (request.bmi >= 30) {
      score += 0.12;
    } else if (request.bmi >= 25) {
      score += 0.06;
    }
    if (request.heartRate >= 110) {
      score += 0.1;
    } else if (request.heartRate >= 95) {
      score += 0.05;
    }
    if (_containsAny(
        medicalContext, const ["hipertansiyon", "preeklampsi", "tansiyon"])) {
      score += request.systolic >= 130 || request.diastolic >= 85 ? 0.08 : 0.03;
    }
    if (_containsAny(
        medicalContext, const ["diyabet", "seker", "insulin", "gestasyonel"])) {
      score += request.bloodSugar >= 105 ? 0.08 : 0.03;
    }
    if (_containsAny(medicalContext, const ["kalp", "aritmi", "tasikardi"])) {
      score += request.heartRate >= 95 ? 0.06 : 0.02;
    }
    if (_containsAny(
        medicalContext, const ["obez", "kilo", "insulin direnci"])) {
      score += request.bmi >= 25 ? 0.05 : 0.02;
    }
    if (previousEntry != null) {
      if (request.systolic - (previousEntry.systolic ?? request.systolic) >=
          10) {
        score += 0.03;
      }
      if (request.bloodSugar -
              (previousEntry.bloodSugar ?? request.bloodSugar) >=
          10) {
        score += 0.03;
      }
      if (request.heartRate - (previousEntry.heartRate ?? request.heartRate) >=
          8) {
        score += 0.02;
      }
      if (request.bodyTemp - (previousEntry.bodyTemp ?? request.bodyTemp) >=
          0.3) {
        score += 0.02;
      }
    }
    score = score.clamp(0.05, 0.95);
    final label = score < 0.33 ? "Dusuk" : (score < 0.66 ? "Orta" : "Yuksek");
    return (score, label);
  }

  Future<void> saveWeekProfile(int age, String? medicalHistory) async {
    final prefs = await _prefs();
    await prefs.setInt(_localProfileAgeKey, age);
    await prefs.setString(_localProfileMedicalKey, medicalHistory ?? "");
    final uid = _uid;
    if (_online && uid != null) {
      try {
        await _sb.from("profiles").update({
          "age": age,
          "medical_history": medicalHistory ?? "",
        }).eq("id", uid);
      } catch (_) {}
    }
  }

  Future<void> saveLocalIdentity({String? name, String? email}) async {
    final prefs = await _prefs();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_localProfileNameKey, name);
    }
    if (email != null && email.isNotEmpty) {
      await prefs.setString(_userEmailKey, email);
    }
    final uid = _uid;
    if (_online && uid != null) {
      try {
        final patch = <String, dynamic>{};
        if (name != null && name.isNotEmpty) patch["name"] = name;
        if (email != null && email.isNotEmpty) patch["email"] = email;
        if (patch.isNotEmpty) {
          await _sb.from("profiles").update(patch).eq("id", uid);
        }
      } catch (_) {}
    }
  }

  Future<void> snapshotIfActive() async {}

  Future<TrackingInsight> buildTrackingInsight({
    required int selectedWeek,
    List<WeekEntry>? weekEntries,
  }) async {
    final prefs = await _prefs();
    final entries = [...(weekEntries ?? await getWeekEntries())]
      ..sort((a, b) => a.weekNo.compareTo(b.weekNo));
    final medicalContext = _combinedMedicalContext(
      profileMedical: prefs.getString(_localProfileMedicalKey),
      maternalChronic: prefs.getString(AppConfig.maternalChronicKey),
    );

    if (entries.isEmpty) {
      final recommendations = <String>[
        "Ilk hafta kaydini girdiginde sistem tum haftalari ayni panelde karsilastiracak.",
        "Ilk kayitta paylastigin saglik gecmisi bundan sonraki onerilere otomatik yansitilacak.",
        "Sistolik, diastolik, kan sekeri, sicaklik, BMI ve nabiz alanlarini birlikte doldurman analiz kalitesini artirir.",
      ];
      return TrackingInsight(
        selectedWeek: selectedWeek,
        focusWeek: null,
        selectedWeekHasEntry: false,
        focusEntry: null,
        previousEntry: null,
        headline: "Henuz haftalik analiz olusmadi",
        summary:
            "Bu alanda her hafta girdigin olcumler kendi gecmisiyle kiyaslanir ve anne saglik notlariyla birlikte yorumlanir.",
        recommendations: recommendations,
        medicalFlags: _medicalHistoryFlags(medicalContext),
        comparisons: const [],
        trendSeries: const [],
        trackedWeeks: 0,
        averageRiskScore: 0,
        highestRiskWeek: null,
        highestRiskScore: null,
      );
    }

    WeekEntry? focusEntry;
    for (final entry in entries) {
      if (entry.weekNo == selectedWeek) {
        focusEntry = entry;
        break;
      }
    }
    focusEntry ??= entries.last;
    final selectedWeekHasEntry = focusEntry.weekNo == selectedWeek;

    WeekEntry? previousEntry;
    for (final entry in entries.reversed) {
      if (entry.weekNo < focusEntry.weekNo) {
        previousEntry = entry;
        break;
      }
    }

    final comparisons =
        _buildMetricComparisons(focusEntry, previousEntry, medicalContext);
    final trendSeries = _buildTrendSeries(entries);
    final medicalFlags = _medicalHistoryFlags(medicalContext);

    double averageRiskScore = 0;
    int riskCount = 0;
    WeekEntry? highestRiskEntry;
    for (final entry in entries) {
      if (entry.riskScore != null) {
        averageRiskScore += entry.riskScore!;
        riskCount += 1;
        if (highestRiskEntry == null ||
            entry.riskScore! > (highestRiskEntry.riskScore ?? -1)) {
          highestRiskEntry = entry;
        }
      }
    }
    if (riskCount > 0) {
      averageRiskScore /= riskCount;
    }

    final headline = _buildInsightHeadline(
      focusEntry: focusEntry,
      previousEntry: previousEntry,
      selectedWeekHasEntry: selectedWeekHasEntry,
      medicalContext: medicalContext,
      comparisons: comparisons,
    );
    final summary = _buildInsightSummary(
      entries: entries,
      focusEntry: focusEntry,
      previousEntry: previousEntry,
      medicalContext: medicalContext,
      selectedWeekHasEntry: selectedWeekHasEntry,
      averageRiskScore: averageRiskScore,
      highestRiskEntry: highestRiskEntry,
    );
    final recommendations = _buildRecommendations(
      focusEntry: focusEntry,
      previousEntry: previousEntry,
      comparisons: comparisons,
      medicalContext: medicalContext,
      selectedWeekHasEntry: selectedWeekHasEntry,
    );

    return TrackingInsight(
      selectedWeek: selectedWeek,
      focusWeek: focusEntry.weekNo,
      selectedWeekHasEntry: selectedWeekHasEntry,
      focusEntry: focusEntry,
      previousEntry: previousEntry,
      headline: headline,
      summary: summary,
      recommendations: recommendations,
      medicalFlags: medicalFlags,
      comparisons: comparisons,
      trendSeries: trendSeries,
      trackedWeeks: entries.length,
      averageRiskScore: averageRiskScore,
      highestRiskWeek: highestRiskEntry?.weekNo,
      highestRiskScore: highestRiskEntry?.riskScore,
    );
  }

  String _combinedMedicalContext({
    String? explicitMedical,
    String? profileMedical,
    String? maternalChronic,
  }) {
    final parts = <String>[];
    for (final part in [explicitMedical, profileMedical, maternalChronic]) {
      final text = (part ?? "").trim();
      if (text.isNotEmpty && !parts.contains(text)) {
        parts.add(text);
      }
    }
    return parts.join(" | ").toLowerCase();
  }

  bool _containsAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  List<String> _medicalHistoryFlags(String medicalContext) {
    if (medicalContext.isEmpty) return const [];
    final flags = <String>[];
    if (_containsAny(
        medicalContext, const ["hipertansiyon", "preeklampsi", "tansiyon"])) {
      flags.add("Tansiyon gecmisi takipte dikkate aliniyor.");
    }
    if (_containsAny(
        medicalContext, const ["diyabet", "seker", "insulin", "gestasyonel"])) {
      flags.add("Kan sekeri oykusu icin karbonhidrat dengesi yakin izleniyor.");
    }
    if (_containsAny(medicalContext, const ["kalp", "aritmi", "tasikardi"])) {
      flags.add("Kalp ritmi oykusu nedeniyle nabiz degisimi one cikiyor.");
    }
    if (_containsAny(medicalContext, const ["tiroid", "hashimoto"])) {
      flags.add(
          "Tiroid gecmisi icin enerji, nabiz ve genel denge daha sik takip edilmeli.");
    }
    if (_containsAny(
        medicalContext, const ["obez", "kilo", "insulin direnci"])) {
      flags.add(
          "Kilo ve metabolik gecmis nedeniyle BMI ve seker dengesi birlikte izleniyor.");
    }
    return flags.take(3).toList(growable: false);
  }

  List<MetricComparison> _buildMetricComparisons(
    WeekEntry focusEntry,
    WeekEntry? previousEntry,
    String medicalContext,
  ) {
    return _metricSpecs.map((spec) {
      final currentValue = spec.valueOf(focusEntry) ?? 0;
      final previousValue =
          previousEntry == null ? null : spec.valueOf(previousEntry);
      final delta = previousValue == null ? 0.0 : currentValue - previousValue;
      TrendDirection direction;
      if (previousValue == null || delta.abs() < spec.steadyThreshold) {
        direction = TrendDirection.steady;
      } else if (delta > 0) {
        direction = TrendDirection.up;
      } else {
        direction = TrendDirection.down;
      }

      final bool attention = spec.isAttention(currentValue, medicalContext);
      final bool worsening =
          previousValue != null && delta >= spec.worseningThreshold;
      final status = attention
          ? (worsening ? "Yukseliyor" : "Dikkat")
          : previousValue == null
              ? "Baz olcumu"
              : direction == TrendDirection.steady
                  ? "Stabil"
                  : delta < 0
                      ? "Iyilesiyor"
                      : "Artis";

      String summary;
      if (previousValue == null) {
        summary = "Ilk kayit alindi, sonraki haftalarda dogrudan kiyaslanacak.";
      } else {
        final sign = delta > 0 ? "+" : "";
        summary =
            "Gecen kayda gore $sign${delta.toStringAsFixed(spec.decimals)} ${spec.unit}";
        if (attention) {
          summary += " degisimiyla izlenmeli.";
        } else if (direction == TrendDirection.steady) {
          summary += " ile dengeli gorunuyor.";
        } else if (delta < 0) {
          summary += " dususunde.";
        } else {
          summary += " artisinda.";
        }
      }

      return MetricComparison(
        key: spec.key,
        label: spec.label,
        unit: spec.unit,
        currentValue: currentValue,
        previousValue: previousValue,
        delta: delta,
        direction: direction,
        status: status,
        summary: summary,
      );
    }).toList(growable: false);
  }

  List<MetricTrendSeries> _buildTrendSeries(List<WeekEntry> entries) {
    return _trendSpecs
        .map((spec) {
          final points = <TrendPoint>[];
          for (final entry in entries) {
            final value = spec.valueOf(entry);
            if (value != null) {
              points.add(TrendPoint(weekNo: entry.weekNo, value: value));
            }
          }
          return MetricTrendSeries(
            key: spec.key,
            label: spec.label,
            unit: spec.unit,
            points: points,
          );
        })
        .where((series) => series.points.isNotEmpty)
        .toList(growable: false);
  }

  String _buildInsightHeadline({
    required WeekEntry focusEntry,
    required WeekEntry? previousEntry,
    required bool selectedWeekHasEntry,
    required String medicalContext,
    required List<MetricComparison> comparisons,
  }) {
    if (!selectedWeekHasEntry) {
      return "${focusEntry.weekNo}. hafta kaydi uzerinden son gidi sat izleniyor";
    }

    final critical = comparisons
        .where((c) => c.status == "Dikkat" || c.status == "Yukseliyor")
        .toList();
    if (critical.isEmpty) {
      if ((focusEntry.riskScore ?? 0) < 0.33) {
        return "Bu hafta genel tablo dengeli gorunuyor";
      }
      return "Bu hafta olcumlerde temkinli takip gerekiyor";
    }

    final primary = critical.first.label.toLowerCase();
    if (_containsAny(medicalContext, const ["hipertansiyon", "tansiyon"]) &&
        primary.contains("tansiyon")) {
      return "Tansiyon degerleri gecmis saglik notlarinla birlikte yakindan izlenmeli";
    }
    if (_containsAny(medicalContext, const ["diyabet", "seker", "insulin"]) &&
        primary.contains("seker")) {
      return "Kan sekeri bu hafta gecmis oykunle birlikte daha dikkatli takip edilmeli";
    }
    return "$primary bu hafta onceki kayitlara gore daha fazla dikkat istiyor";
  }

  String _buildInsightSummary({
    required List<WeekEntry> entries,
    required WeekEntry focusEntry,
    required WeekEntry? previousEntry,
    required String medicalContext,
    required bool selectedWeekHasEntry,
    required double averageRiskScore,
    required WeekEntry? highestRiskEntry,
  }) {
    final buffer = StringBuffer();
    if (!selectedWeekHasEntry) {
      buffer.write(
        "Secili hafta icin henuz olcum girilmemis. Son kayit olan ${focusEntry.weekNo}. hafta baz alinarak yorum yapiliyor. ",
      );
    }

    if (previousEntry != null &&
        focusEntry.riskScore != null &&
        previousEntry.riskScore != null) {
      final delta = focusEntry.riskScore! - previousEntry.riskScore!;
      final direction = delta.abs() < 0.03
          ? "stabil"
          : (delta < 0 ? "geriliyor" : "yukseliyor");
      buffer.write(
        "Risk skoru ${previousEntry.weekNo}. haftaya gore $direction. ",
      );
    } else {
      buffer.write(
        "Bu hafta icin karsilastirma bazini olusturan kayitlar toplanmaya baslandi. ",
      );
    }

    if (entries.length >= 2) {
      buffer.write(
        "Tum kayitlarin ortalama risk seviyesi %${(averageRiskScore * 100).toStringAsFixed(0)} civarinda. ",
      );
    }
    if (highestRiskEntry?.riskScore != null) {
      buffer.write(
        "Su ana kadarki en yuksek risk ${highestRiskEntry!.weekNo}. haftada %${(highestRiskEntry.riskScore! * 100).toStringAsFixed(0)} olarak goruldu. ",
      );
    }
    if (medicalContext.isNotEmpty) {
      buffer.write(
        "Ilk kayitta verilen saglik notlari da yorumun agirligini belirliyor.",
      );
    }
    return buffer.toString().trim();
  }

  List<String> _buildRecommendations({
    required WeekEntry focusEntry,
    required WeekEntry? previousEntry,
    required List<MetricComparison> comparisons,
    required String medicalContext,
    required bool selectedWeekHasEntry,
  }) {
    final recommendations = <String>[];
    if (!selectedWeekHasEntry) {
      recommendations.add(
        "Secili hafta icin olcum ekledigin anda sistem bu karti dogrudan o haftaya gore yeniler.",
      );
    }

    final byKey = {for (final item in comparisons) item.key: item};
    final systolic = focusEntry.systolic ?? 0;
    final diastolic = focusEntry.diastolic ?? 0;
    final bloodSugar = focusEntry.bloodSugar ?? 0;
    final bodyTemp = focusEntry.bodyTemp ?? 0;
    final bmi = focusEntry.bmi ?? 0;
    final heartRate = focusEntry.heartRate ?? 0;

    if (systolic >= 130 || diastolic >= 85) {
      recommendations.add(
        "Tansiyon icin tuzu azalt, gun icinde kisa dinlenme aralari ver ve olcumu mumkunse benzer saatlerde tekrar et.",
      );
    }
    if (bloodSugar >= 105) {
      recommendations.add(
        "Kan sekeri icin basit sekerleri kisip protein, yogurt, yumurta ve tam tahilli kucuk ogunleri daha duzenli yay.",
      );
    }
    if (bodyTemp >= 37.2) {
      recommendations.add(
        "Vucut sicakligi yukseliyorsa su tuketimini artir, istirahat et ve deger devam ederse uzman gorusu al.",
      );
    }
    if (bmi >= 25) {
      recommendations.add(
        "Kilo yonetimi icin ogun atlamadan sebze, lif ve protein dengesi kur; tek ogunde fazla yuklenme yerine daha dengeli tabaklar tercih et.",
      );
    }
    if (heartRate >= 95) {
      recommendations.add(
        "Nabiz artiyorsa kafeini azalt, hareketten sonra daha uzun toparlanma molalari ver ve su alimini ihmal etme.",
      );
    }

    if (_containsAny(medicalContext, const ["hipertansiyon", "tansiyon"]) &&
        !recommendations.any((e) => e.contains("Tansiyon"))) {
      recommendations.add(
        "Tansiyon gecmisin oldugu icin ev tipi takipte sabah-aksam olcum duzeni kurman faydali olabilir.",
      );
    }
    if (_containsAny(medicalContext, const ["diyabet", "seker", "insulin"]) &&
        !recommendations.any((e) => e.contains("Kan sekeri"))) {
      recommendations.add(
        "Seker gecmisi icin meyve, ekmek ve paketli atistirmaliklari tek ogunde toplamak yerine gun icine yaymak daha dengeli olabilir.",
      );
    }
    if (_containsAny(medicalContext, const ["kalp", "aritmi", "tasikardi"]) &&
        heartRate >= 90) {
      recommendations.add(
        "Kalp ritmi oykun oldugu icin carpinti veya nefes darligi eklenirse beklemeden doktorunla gorus.",
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        "Gidisat dengeli gorunuyor; su, uyku, hafif hareket ve duzenli haftalik takip rutiniyle devam edebilirsin.",
      );
      recommendations.add(
        "Olcumlerini ayni cihaz ve benzer saatlerle girmek grafikteki degisimi daha anlamli hale getirir.",
      );
    }

    final worseningCount = byKey.values
        .where((item) => item.status == "Dikkat" || item.status == "Yukseliyor")
        .length;
    if (worseningCount >= 3 ||
        (focusEntry.riskScore != null && focusEntry.riskScore! >= 0.66)) {
      recommendations.add(
        "Birden fazla deger ayni anda yukseliyorsa bu haftaki tabloyu doktoruna kisa bir ozet halinde iletmen iyi olur.",
      );
    } else if (previousEntry != null &&
        focusEntry.riskScore != null &&
        previousEntry.riskScore != null &&
        focusEntry.riskScore! < previousEntry.riskScore!) {
      recommendations.add(
        "Onceki haftaya gore daha dengeli bir seyir var; ayni rutini koruman faydali olur.",
      );
    }

    return recommendations.take(4).toList(growable: false);
  }

  String _buildLocalAdviceFromInsight(TrackingInsight insight) {
    final lines = <String>[
      insight.headline,
      insight.summary,
      ...insight.recommendations.map((item) => "• $item"),
    ];
    return lines.where((line) => line.trim().isNotEmpty).join("\n");
  }

  Future<List<ChatMessage>> getChatHistory() async {
    final uid = _uid;
    if (!_online || uid == null) return const [];
    try {
      final rows = await _sb
          .from("chat_messages")
          .select()
          .eq("user_id", uid)
          .order("created_at") as List;
      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        return ChatMessage(
          message: (m["message"] as String?) ?? "",
          fromUser: m["from_user"] == true,
          createdAt: DateTime.tryParse(m["created_at"]?.toString() ?? "") ??
              DateTime.now(),
        );
      }).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveChatMessage(String message, bool fromUser) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    try {
      await _sb.from("chat_messages").insert({
        "user_id": uid,
        "message": message,
        "from_user": fromUser,
      });
    } catch (_) {}
  }

  Future<String> sendChat(String message, {bool includeLatest = false}) async {
    await _saveChatMessage(message, true);
    final reply = await _buildLocalChatReply(message);
    await _saveChatMessage(reply, false);
    return reply;
  }

  Stream<String> sendChatStream(
    String message, {
    List<ChatMessage> history = const [],
    bool includeLatest = false,
  }) async* {
    await _saveChatMessage(message, true);

    var replyBuffer = StringBuffer();
    var streamed = false;

    try {
      if (_online && _uid != null) {
        final payload = await _buildChatStreamPayload(
          message,
          history: history,
          includeLatest: includeLatest,
        );
        await for (final delta in _streamChatFromEdge(payload)) {
          if (delta.trim().isEmpty) continue;
          streamed = true;
          replyBuffer.write(delta);
          yield delta;
        }
      }
    } catch (_) {
      if (streamed && replyBuffer.isNotEmpty) {
        final partialReply = replyBuffer.toString().trim();
        if (partialReply.isNotEmpty) {
          await _saveChatMessage(partialReply, false);
        }
        rethrow;
      }
      streamed = false;
      replyBuffer = StringBuffer();
    }

    if (!streamed || replyBuffer.isEmpty) {
      final fallback = await _buildLocalChatReply(message);
      await for (final delta in _simulateStreamingText(fallback)) {
        replyBuffer.write(delta);
        yield delta;
      }
    }

    final finalReply = replyBuffer.toString().trim();
    if (finalReply.isNotEmpty) {
      await _saveChatMessage(finalReply, false);
    }
  }

  Future<Map<String, dynamic>> _buildChatStreamPayload(
    String message, {
    required List<ChatMessage> history,
    required bool includeLatest,
  }) async {
    final prefs = await _prefs();
    final entries = await getWeekEntries();
    final latest = entries.isEmpty
        ? null
        : ([...entries]..sort((a, b) => b.weekNo.compareTo(a.weekNo))).first;

    final safeHistory = history
        .where((item) => item.message.trim().isNotEmpty)
        .map((item) => {
              "role": item.fromUser ? "user" : "assistant",
              "content": item.message.trim(),
            })
        .toList(growable: false);
    final recentHistory = safeHistory.length > 10
        ? safeHistory.sublist(safeHistory.length - 10)
        : safeHistory;

    return {
      "message": message,
      "history": recentHistory,
      "context": {
        "profile_name": prefs.getString(AppConfig.profileNameKey)?.trim(),
        "profile_age": prefs.getInt(AppConfig.profileAgeKey),
        "medical_history": prefs.getString(AppConfig.profileMedicalKey)?.trim(),
        "caregiver_role": prefs.getString(AppConfig.caregiverRoleKey)?.trim(),
        "baby_name": prefs.getString(AppConfig.babyNameKey)?.trim(),
        "planning_baby": prefs.getBool(AppConfig.planningBabyKey) ?? false,
        "latest_week": includeLatest ? latest?.weekNo : null,
        "latest_risk_label": includeLatest ? latest?.riskLabel : null,
        "latest_risk_score": includeLatest ? latest?.riskScore : null,
        "latest_systolic": includeLatest ? latest?.systolic : null,
        "latest_diastolic": includeLatest ? latest?.diastolic : null,
        "latest_blood_sugar": includeLatest ? latest?.bloodSugar : null,
        "latest_body_temp": includeLatest ? latest?.bodyTemp : null,
        "latest_bmi": includeLatest ? latest?.bmi : null,
        "latest_heart_rate": includeLatest ? latest?.heartRate : null,
      },
    };
  }

  Stream<String> _streamChatFromEdge(Map<String, dynamic> payload) async* {
    final url = Uri.parse("${AppConfig.supabaseUrl}/functions/v1/chat-stream");
    final accessToken = _sb.auth.currentSession?.accessToken;
    final apiKey = AppConfig.supabaseClientKey;
    if (accessToken == null || accessToken.isEmpty || apiKey.isEmpty) {
      throw Exception("Eksik kimlik dogrulama bilgisi.");
    }

    final request = http.Request("POST", url)
      ..headers.addAll({
        "Content-Type": "application/json",
        "Accept": "text/event-stream",
        "Authorization": "Bearer $accessToken",
        "apikey": apiKey,
      })
      ..body = jsonEncode(payload);

    final response = await http.Client().send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errorBody = await response.stream.bytesToString();
      throw Exception(
        errorBody.isEmpty
            ? "Canli sohbet baglantisi kurulamadı."
            : errorBody,
      );
    }

    final lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lineStream) {
      final line = rawLine.trim();
      if (!line.startsWith("data:")) continue;
      final data = line.substring(5).trim();
      if (data.isEmpty) continue;
      if (data == "[DONE]") break;

      final parsed = jsonDecode(data);
      if (parsed is! Map<String, dynamic>) continue;
      if (parsed["type"] == "error") {
        throw Exception((parsed["error"] ?? "Sohbet akisi hatasi").toString());
      }
      if (parsed["type"] == "delta") {
        final delta = (parsed["delta"] ?? "").toString();
        if (delta.isNotEmpty) yield delta;
      }
    }
  }

  Stream<String> _simulateStreamingText(String text) async* {
    final tokenMatches = RegExp(r"\S+\s*").allMatches(text);
    for (final match in tokenMatches) {
      final token = match.group(0) ?? "";
      if (token.isEmpty) continue;
      await Future<void>.delayed(const Duration(milliseconds: 35));
      yield token;
    }
  }

  Future<String> _buildLocalChatReply(String message) async {
    final prefs = await _prefs();
    final name = prefs.getString(AppConfig.profileNameKey)?.trim();
    final babyName = prefs.getString(AppConfig.babyNameKey)?.trim();
    final entries = await getWeekEntries();

    WeekEntry? latest;
    if (entries.isNotEmpty) {
      final sorted = [...entries]..sort((a, b) => b.weekNo.compareTo(a.weekNo));
      latest = sorted.first;
    }

    final q = message.toLowerCase();
    final greetName = (name != null && name.isNotEmpty) ? name : "anne";
    final babyRef = _babyPossessive(babyName);
    final emergencyWords = [
      "kanama",
      "bayil",
      "siddetli agri",
      "nefes",
      "ates"
    ];
    final hasEmergencySignal = emergencyWords.any(q.contains);

    if (hasEmergencySignal) {
      return "$greetName, bunu ciddiye alalim. Acil belirti olabilecek bir durum tarif ettin, beklemeden doktorunla veya acil servisle iletisime gecmeni oneririm.";
    }

    if (latest == null) {
      return "$greetName, $babyRef yolculugunda sana daha uygun bilgi sunabilmem icin analiz ekranindan bir hafta verisi girebilirsin.";
    }

    final risk = (latest.riskLabel ?? "Belirsiz").toLowerCase();
    final riskText = latest.riskLabel ?? "Belirsiz";
    final scoreText = latest.riskScore == null
        ? "hesaplanmamis"
        : latest.riskScore!.toStringAsFixed(2);

    String advice;
    if (risk.contains("yuksek")) {
      advice =
          "Son olcumlerinde risk daha yuksek gorunuyor. Olcumlerini gun icinde tekrar et, dinlen, su tuket ve doktoruna kisa bir durum ozeti ilet.";
    } else if (risk.contains("orta")) {
      advice =
          "Risk orta seviyede. Tuz/sekere dikkat ederek dinlenme, su tuketimi ve duzenli olcum rutiniyle takibi surdur.";
    } else {
      advice =
          "Gidisat su an iyi gorunuyor. Duzenli uyku, dengeli beslenme ve haftalik olcum takibiyle devam et.";
    }

    if (q.contains("beslen") || q.contains("yemek")) {
      advice =
          "Beslenmede az ve sik ogun, yeterli su, sebze-protein dengesi ve asiri sekerli iceceklerden kacinma guvenli bir yaklasim olur.";
    } else if (q.contains("uyku")) {
      advice =
          "Uyku icin her gun benzer saatte yatip kalkmak, aksam kafeini azaltmak ve sol yana yatmak rahatlatici olabilir.";
    } else if (q.contains("su")) {
      advice =
          "Gun icinde suyu yayarak icmek iyi olur. Idrar rengi koyulasiyorsa su alimini artirmayi dusunebilirsin.";
    }

    return "$greetName, $babyRef ${latest.weekNo}. haftasinda son risk degeri $riskText (skor: $scoreText). $advice";
  }

  Map<String, dynamic> _appointmentToJson(Appointment a) => {
        "id": a.id,
        "title": a.title,
        "appointment_at": a.appointmentAt.toIso8601String(),
        "notes": a.notes ?? "",
      };

  Future<List<Appointment>> _loadLocalAppointments() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_localAppointmentsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> _saveLocalAppointments(List<Appointment> items) async {
    final prefs = await _prefs();
    final list = items.map(_appointmentToJson).toList(growable: false);
    await prefs.setString(_localAppointmentsKey, jsonEncode(list));
  }

  Appointment _appointmentFromRow(Map<String, dynamic> row) => Appointment(
        id: (row["id"] as num?)?.toInt() ?? 0,
        title: (row["title"] as String?)?.trim() ?? "",
        appointmentAt:
            DateTime.tryParse(row["appointment_at"]?.toString() ?? "") ??
                DateTime.now(),
        notes: (row["notes"] as String?)?.trim(),
      );

  Future<List<Appointment>> getAppointments() async {
    final uid = _uid;
    if (_online && uid != null) {
      try {
        final rows = await _sb
            .from("appointments")
            .select()
            .eq("user_id", uid)
            .order("appointment_at") as List;
        final items = rows
            .map((r) => _appointmentFromRow(r as Map<String, dynamic>))
            .toList(growable: false);
        await _saveLocalAppointments(items);
        return items;
      } catch (_) {
        return _loadLocalAppointments();
      }
    }
    final items = await _loadLocalAppointments();
    items.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
    return items;
  }

  Stream<List<Appointment>> appointmentsStream() {
    final uid = _uid;
    if (!_online || uid == null) {
      return Stream<List<Appointment>>.value(const []);
    }
    return _sb
        .from("appointments")
        .stream(primaryKey: ["id"])
        .eq("user_id", uid)
        .order("appointment_at")
        .map((rows) => rows.map(_appointmentFromRow).toList(growable: false));
  }

  Future<void> addAppointment(Appointment appointment) async {
    final uid = _uid;
    if (_online && uid != null) {
      await _sb.from("appointments").insert({
        "user_id": uid,
        "title": appointment.title,
        "appointment_at": appointment.appointmentAt.toIso8601String(),
        "notes": appointment.notes ?? "",
      });
      return;
    }
    final items = await _loadLocalAppointments();
    final nextId =
        (items.map((e) => e.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    items.add(Appointment(
      id: nextId,
      title: appointment.title,
      appointmentAt: appointment.appointmentAt,
      notes: appointment.notes,
    ));
    await _saveLocalAppointments(items);
  }

  Future<void> deleteAppointment(int id) async {
    final uid = _uid;
    if (_online && uid != null) {
      await _sb.from("appointments").delete().eq("id", id).eq("user_id", uid);
      return;
    }
    final items = await _loadLocalAppointments();
    items.removeWhere((a) => a.id == id);
    await _saveLocalAppointments(items);
  }

  Map<String, dynamic> _medicationToJson(Medication m) => {
        "id": m.id,
        "name": m.name,
        "dosage": m.dosage ?? "",
        "frequency": m.frequency ?? "",
        "start_date": m.startDate ?? "",
        "end_date": m.endDate ?? "",
        "times": m.times,
        "notes": m.notes ?? "",
      };

  Future<List<Medication>> _loadLocalMedications() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_localMedicationsKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> _saveLocalMedications(List<Medication> items) async {
    final prefs = await _prefs();
    final list = items.map(_medicationToJson).toList(growable: false);
    await prefs.setString(_localMedicationsKey, jsonEncode(list));
  }

  Medication _medicationFromRow(Map<String, dynamic> row) {
    final timesRaw = row["times"];
    final times = (timesRaw is List)
        ? timesRaw.map((e) => e.toString()).toList()
        : <String>[];
    return Medication(
      id: (row["id"] as num?)?.toInt() ?? 0,
      name: (row["name"] as String?)?.trim() ?? "",
      dosage: (row["dosage"] as String?)?.trim(),
      frequency: (row["frequency"] as String?)?.trim(),
      startDate: (row["start_date"] as String?)?.trim(),
      endDate: (row["end_date"] as String?)?.trim(),
      times: times,
      notes: (row["notes"] as String?)?.trim(),
    );
  }

  Future<List<Medication>> getMedications() async {
    final uid = _uid;
    if (_online && uid != null) {
      try {
        final rows = await _sb
            .from("medications")
            .select()
            .eq("user_id", uid)
            .order("created_at") as List;
        final items = rows
            .map((r) => _medicationFromRow(r as Map<String, dynamic>))
            .toList(growable: false);
        await _saveLocalMedications(items);
        return items;
      } catch (_) {
        return _loadLocalMedications();
      }
    }
    return _loadLocalMedications();
  }

  Stream<List<Medication>> medicationsStream() {
    final uid = _uid;
    if (!_online || uid == null) {
      return Stream<List<Medication>>.value(const []);
    }
    return _sb
        .from("medications")
        .stream(primaryKey: ["id"])
        .eq("user_id", uid)
        .order("created_at")
        .map((rows) => rows.map(_medicationFromRow).toList(growable: false));
  }

  Future<void> addMedication({
    required String name,
    String? dosage,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String times = "",
    String? notes,
  }) async {
    final timesList = times
        .split(",")
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final startStr = startDate?.toIso8601String().split("T").first;
    final endStr = endDate?.toIso8601String().split("T").first;

    final uid = _uid;
    if (_online && uid != null) {
      await _sb.from("medications").insert({
        "user_id": uid,
        "name": name,
        "dosage": dosage ?? "",
        "frequency": frequency ?? "",
        "start_date": startStr,
        "end_date": endStr,
        "times": timesList,
        "notes": notes ?? "",
      });
      return;
    }

    final items = await _loadLocalMedications();
    final nextId =
        (items.map((e) => e.id).fold<int>(0, (a, b) => a > b ? a : b)) + 1;
    items.add(Medication(
      id: nextId,
      name: name,
      dosage: dosage,
      frequency: frequency,
      startDate: startStr,
      endDate: endStr,
      times: timesList,
      notes: notes,
    ));
    await _saveLocalMedications(items);
  }

  Future<void> deleteMedication(int id) async {
    final uid = _uid;
    if (_online && uid != null) {
      await _sb.from("medications").delete().eq("id", id).eq("user_id", uid);
      return;
    }
    final items = await _loadLocalMedications();
    items.removeWhere((m) => m.id == id);
    await _saveLocalMedications(items);
  }

  String _today() => DateTime.now().toIso8601String().split("T").first;

  Stream<List<T>> _toolStream<T>(
    String table,
    T Function(Map<String, dynamic>) map, {
    String orderBy = "created_at",
    bool ascending = false,
  }) {
    final uid = _uid;
    if (!_online || uid == null) return Stream<List<T>>.value(const []);
    return _sb
        .from(table)
        .stream(primaryKey: ["id"])
        .eq("user_id", uid)
        .order(orderBy, ascending: ascending)
        .map((rows) => rows.map(map).toList(growable: false));
  }

  Future<List<Map<String, dynamic>>> _toolSelect(
    String table, {
    String orderBy = "created_at",
    bool ascending = false,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return const [];
    try {
      final rows = await _sb
          .from(table)
          .select()
          .eq("user_id", uid)
          .order(orderBy, ascending: ascending) as List;
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return const [];
    }
  }

  Stream<List<KickSession>> kickSessionsStream() =>
      _toolStream("kick_sessions", KickSession.fromRow, orderBy: "started_at");

  Future<List<KickSession>> getKickSessions() async =>
      (await _toolSelect("kick_sessions", orderBy: "started_at"))
          .map(KickSession.fromRow)
          .toList(growable: false);

  Future<void> addKickSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int kickCount,
    required int durationSeconds,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("kick_sessions").insert({
      "user_id": uid,
      "started_at": startedAt.toIso8601String(),
      "ended_at": endedAt.toIso8601String(),
      "kick_count": kickCount,
      "duration_seconds": durationSeconds,
    });
  }

  Future<void> deleteKickSession(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("kick_sessions").delete().eq("id", id).eq("user_id", uid);
  }

  Stream<List<ContractionLog>> contractionsStream() =>
      _toolStream("contraction_logs", ContractionLog.fromRow,
          orderBy: "started_at");

  Future<void> addContraction({
    required DateTime startedAt,
    required int durationSeconds,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("contraction_logs").insert({
      "user_id": uid,
      "started_at": startedAt.toIso8601String(),
      "duration_seconds": durationSeconds,
    });
  }

  Future<void> deleteContraction(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("contraction_logs").delete().eq("id", id).eq("user_id", uid);
  }

  Stream<List<WeightEntry>> weightStream() =>
      _toolStream("weight_entries", WeightEntry.fromRow,
          orderBy: "recorded_on", ascending: true);

  Future<List<WeightEntry>> getWeightEntries() async =>
      (await _toolSelect("weight_entries",
              orderBy: "recorded_on", ascending: true))
          .map(WeightEntry.fromRow)
          .toList(growable: false);

  Future<void> upsertWeight({
    required DateTime recordedOn,
    required double weightKg,
    int? weekNo,
    String? note,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("weight_entries").upsert({
      "user_id": uid,
      "recorded_on": recordedOn.toIso8601String().split("T").first,
      "weight_kg": weightKg,
      "week_no": weekNo,
      "note": note,
    }, onConflict: "user_id,recorded_on");
  }

  Future<void> deleteWeight(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("weight_entries").delete().eq("id", id).eq("user_id", uid);
  }

  Future<WaterLog?> getTodayWater() async {
    final uid = _uid;
    if (!_online || uid == null) return null;
    try {
      final row = await _sb
          .from("water_logs")
          .select()
          .eq("user_id", uid)
          .eq("day", _today())
          .maybeSingle();
      return row == null ? null : WaterLog.fromRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> setWater({required int glasses, int goal = 8}) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("water_logs").upsert({
      "user_id": uid,
      "day": _today(),
      "glasses": glasses < 0 ? 0 : glasses,
      "goal": goal,
    }, onConflict: "user_id,day");
  }

  Stream<List<JournalEntry>> journalStream() =>
      _toolStream("journal_entries", JournalEntry.fromRow);

  Future<void> addJournal({String? mood, String? note}) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("journal_entries").insert({
      "user_id": uid,
      "mood": mood,
      "note": note,
    });
  }

  Future<void> deleteJournal(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("journal_entries").delete().eq("id", id).eq("user_id", uid);
  }

  Stream<List<BabyName>> namesStream() =>
      _toolStream("baby_names", BabyName.fromRow);

  Future<void> addBabyName({
    required String name,
    String? gender,
    String? note,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("baby_names").insert({
      "user_id": uid,
      "name": name,
      "gender": gender,
      "note": note,
      "is_favorite": false,
    });
  }

  Future<void> setNameFavorite(int id, bool value) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb
        .from("baby_names")
        .update({"is_favorite": value})
        .eq("id", id)
        .eq("user_id", uid);
  }

  Future<void> deleteBabyName(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("baby_names").delete().eq("id", id).eq("user_id", uid);
  }

  Future<Set<int>> _notificationReadIds() async {
    final uid = _uid;
    if (!_online || uid == null) return <int>{};
    try {
      final rows = await _sb
          .from("notification_reads")
          .select("notification_id")
          .eq("user_id", uid) as List;
      return rows
          .map((r) => (r["notification_id"] as num?)?.toInt() ?? 0)
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  Future<List<AppNotification>> getNotifications() async {
    final uid = _uid;
    if (!_online || uid == null) return const [];
    try {
      final rows = await _sb
          .from("notifications")
          .select()
          .or("audience.eq.all,user_id.eq.$uid")
          .order("created_at", ascending: false) as List;
      final reads = await _notificationReadIds();
      return rows.map((r) {
        final m = r as Map<String, dynamic>;
        final id = (m["id"] as num?)?.toInt() ?? 0;
        return AppNotification.fromRow(m, read: reads.contains(id));
      }).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Stream<int> unreadCountStream() {
    final uid = _uid;
    if (!_online || uid == null) return Stream<int>.value(0);
    return _sb
        .from("notifications")
        .stream(primaryKey: ["id"])
        .order("created_at", ascending: false)
        .asyncMap((rows) async {
          final reads = await _notificationReadIds();
          var count = 0;
          for (final r in rows) {
            final audience = (r["audience"] as String?) ?? "user";
            final rowUid = r["user_id"]?.toString();
            final visible = audience == "all" || rowUid == uid;
            final id = (r["id"] as num?)?.toInt() ?? 0;
            if (visible && !reads.contains(id)) count++;
          }
          return count;
        });
  }

  Future<void> markNotificationRead(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    try {
      await _sb.from("notification_reads").upsert({
        "user_id": uid,
        "notification_id": id,
      }, onConflict: "user_id,notification_id");
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead(List<int> ids) async {
    final uid = _uid;
    if (!_online || uid == null || ids.isEmpty) return;
    try {
      await _sb.from("notification_reads").upsert(
            ids
                .map((id) => {"user_id": uid, "notification_id": id})
                .toList(growable: false),
            onConflict: "user_id,notification_id",
          );
    } catch (_) {}
  }

  Future<List<NotificationTemplate>> getNotificationTemplates() async {
    if (!_online) return const [];
    try {
      final rows = await _sb
          .from("notification_templates")
          .select()
          .eq("is_active", true)
          .order("id") as List;
      return rows
          .map((r) => NotificationTemplate.fromRow(r as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> logLocalNotification({
    required String title,
    String? body,
    String? category,
    String? icon,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    try {
      await _sb.from("notifications").insert({
        "audience": "user",
        "user_id": uid,
        "title": title,
        "body": body,
        "category": category ?? "reminder",
        "icon": icon,
      });
    } catch (_) {}
  }

  Future<void> registerDeviceToken(String token, {String platform = ""}) async {
    final uid = _uid;
    if (!_online || uid == null || token.isEmpty) return;
    try {
      await _sb.from("device_tokens").upsert({
        "user_id": uid,
        "token": token,
        "platform": platform,
        "updated_at": DateTime.now().toIso8601String(),
      }, onConflict: "user_id,token");
    } catch (_) {}
  }

  Stream<List<SymptomLog>> symptomLogsStream() =>
      _toolStream("symptom_logs", SymptomLog.fromRow, orderBy: "logged_on");

  Future<List<SymptomLog>> getSymptomLogs() async =>
      (await _toolSelect("symptom_logs", orderBy: "logged_on"))
          .map(SymptomLog.fromRow)
          .toList(growable: false);

  Future<void> addSymptomLog({
    required List<String> symptoms,
    int? severity,
    String? note,
    int? weekNo,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("symptom_logs").insert({
      "user_id": uid,
      "symptoms": symptoms,
      "severity": severity,
      "note": note,
      "week_no": weekNo,
    });
  }

  Future<void> deleteSymptomLog(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("symptom_logs").delete().eq("id", id).eq("user_id", uid);
  }

  Stream<List<ChecklistItem>> checklistStream() =>
      _toolStream("checklist_items", ChecklistItem.fromRow,
          orderBy: "sort_order", ascending: true);

  Future<List<ChecklistItem>> getChecklistItems() async =>
      (await _toolSelect("checklist_items",
              orderBy: "sort_order", ascending: true))
          .map(ChecklistItem.fromRow)
          .toList(growable: false);

  Future<void> addChecklistItem({
    required String category,
    required String title,
    int sortOrder = 100,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("checklist_items").insert({
      "user_id": uid,
      "category": category,
      "title": title,
      "sort_order": sortOrder,
    });
  }

  Future<void> setChecklistDone(int id, bool done) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb
        .from("checklist_items")
        .update({"is_done": done})
        .eq("id", id)
        .eq("user_id", uid);
  }

  Future<void> deleteChecklistItem(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("checklist_items").delete().eq("id", id).eq("user_id", uid);
  }

  Future<void> seedDefaultChecklist(
      Map<String, List<String>> defaultsByCategory) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    final rows = <Map<String, dynamic>>[];
    for (final entry in defaultsByCategory.entries) {
      var i = 0;
      for (final title in entry.value) {
        rows.add({
          "user_id": uid,
          "category": entry.key,
          "title": title,
          "sort_order": i,
        });
        i++;
      }
    }
    if (rows.isEmpty) return;
    try {
      await _sb.from("checklist_items").insert(rows);
    } catch (_) {}
  }

  Stream<List<BabyLog>> babyLogsStream() =>
      _toolStream("baby_logs", BabyLog.fromRow, orderBy: "occurred_at");

  Future<void> addBabyLog({
    required String type,
    String? amount,
    String? note,
    DateTime? occurredAt,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("baby_logs").insert({
      "user_id": uid,
      "type": type,
      "amount": amount,
      "note": note,
      "occurred_at": (occurredAt ?? DateTime.now()).toIso8601String(),
    });
  }

  Future<void> deleteBabyLog(int id) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    await _sb.from("baby_logs").delete().eq("id", id).eq("user_id", uid);
  }

  Future<void> requestAccountAction(String type, {String? note}) async {
    final uid = _uid;
    if (!_online || uid == null) {
      throw Exception("Bu işlem için giriş gerekir.");
    }
    final prefs = await _prefs();
    final email =
        (prefs.getString(_userEmailKey) ?? (_sb.auth.currentUser?.email ?? ""))
            .trim();
    await _sb.from("account_requests").insert({
      "user_id": uid,
      "email": email,
      "type": type,
      "note": note,
    });
  }

  Future<void> acceptConsent(String version) async {
    final uid = _uid;
    if (!_online || uid == null) return;
    try {
      await _sb.from("profiles").update({
        "consent_accepted_at": DateTime.now().toIso8601String(),
        "consent_version": version,
      }).eq("id", uid);
    } catch (_) {}
  }

  Future<void> submitSupportMessage({
    required String subject,
    required String message,
  }) async {
    final uid = _uid;
    if (!_online || uid == null) {
      throw Exception(
          "Destek mesajı göndermek için internet bağlantısı ve giriş gerekir.");
    }
    final prefs = await _prefs();
    final name = (prefs.getString(AppConfig.profileNameKey) ?? "").trim();
    final email =
        (prefs.getString(_userEmailKey) ?? (_sb.auth.currentUser?.email ?? ""))
            .trim();
    await _sb.from("support_messages").insert({
      "user_id": uid,
      "name": name,
      "email": email,
      "subject": subject.trim(),
      "message": message.trim(),
    });
  }

  Future<List<Plan>> getPlans() async {
    if (!_online) return const [];
    try {
      final rows = await _sb
          .from("plans")
          .select()
          .eq("is_active", true)
          .order("sort_order") as List;
      return rows
          .map((r) => Plan.fromRow(r as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<PremiumContent>> getPremiumContents() async {
    if (!_online) return const [];
    try {
      final rows = await _sb
          .from("premium_contents")
          .select()
          .eq("is_active", true)
          .order("sort_order") as List;
      return rows
          .map((r) => PremiumContent.fromRow(r as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<Subscription?> getActiveSubscription() async {
    final uid = _uid;
    if (!_online || uid == null) return null;
    try {
      final row = await _sb
          .from("subscriptions")
          .select()
          .eq("user_id", uid)
          .eq("status", "active")
          .order("started_at", ascending: false)
          .limit(1)
          .maybeSingle();
      if (row == null) return null;
      final code = (row["plan_code"] as String?)?.trim() ?? "";
      List<String> features = const [];
      try {
        final planRow = await _sb
            .from("plans")
            .select("features")
            .eq("code", code)
            .maybeSingle();
        if (planRow != null) {
          features = Plan.fromRow({...planRow, "code": code}).features;
        }
      } catch (_) {}
      final sub = Subscription.fromRow(row, features: features);
      return sub.isActive ? sub : null;
    } catch (_) {
      return null;
    }
  }

  Future<Subscription> purchasePlan(Plan plan) async {
    final uid = _uid;
    if (!_online || uid == null) {
      throw Exception("Ödeme için giriş yapman gerekiyor.");
    }
    final now = DateTime.now();
    final months = plan.durationMonths;
    final DateTime? expiresAt = (months != null && months > 0)
        ? DateTime(now.year, now.month + months, now.day, now.hour, now.minute,
            now.second)
        : null;

    final subRow = await _sb
        .from("subscriptions")
        .insert({
          "user_id": uid,
          "plan_code": plan.code,
          "plan_name": plan.name,
          "price": plan.price,
          "currency": plan.currency,
          "status": "active",
          "started_at": now.toIso8601String(),
          "expires_at": expiresAt?.toIso8601String(),
        })
        .select()
        .single();

    final subId = (subRow["id"] as num?)?.toInt();

    await _sb.from("payments").insert({
      "user_id": uid,
      "subscription_id": subId,
      "plan_code": plan.code,
      "amount": plan.price,
      "currency": plan.currency,
      "method": "demo",
      "status": "paid",
      "raw": {
        "plan_name": plan.name,
        "period": plan.period,
        "demo": true,
      },
    });

    return Subscription.fromRow(subRow, features: plan.features);
  }
}

typedef _EntryValueGetter = double? Function(WeekEntry entry);
typedef _MetricAttentionRule = bool Function(
    double value, String medicalContext);

class _MetricSpec {
  final String key;
  final String label;
  final String unit;
  final int decimals;
  final double steadyThreshold;
  final double worseningThreshold;
  final _EntryValueGetter valueOf;
  final _MetricAttentionRule isAttention;

  const _MetricSpec({
    required this.key,
    required this.label,
    required this.unit,
    required this.decimals,
    required this.steadyThreshold,
    required this.worseningThreshold,
    required this.valueOf,
    required this.isAttention,
  });
}

const List<_MetricSpec> _metricSpecs = [
  _MetricSpec(
    key: "systolic",
    label: "Sistolik",
    unit: "mmHg",
    decimals: 0,
    steadyThreshold: 2,
    worseningThreshold: 8,
    valueOf: _systolicValue,
    isAttention: _systolicAttention,
  ),
  _MetricSpec(
    key: "diastolic",
    label: "Diastolik",
    unit: "mmHg",
    decimals: 0,
    steadyThreshold: 2,
    worseningThreshold: 5,
    valueOf: _diastolicValue,
    isAttention: _diastolicAttention,
  ),
  _MetricSpec(
    key: "bloodSugar",
    label: "Kan sekeri",
    unit: "mg/dL",
    decimals: 0,
    steadyThreshold: 4,
    worseningThreshold: 10,
    valueOf: _bloodSugarValue,
    isAttention: _bloodSugarAttention,
  ),
  _MetricSpec(
    key: "bodyTemp",
    label: "Sicaklik",
    unit: "°C",
    decimals: 1,
    steadyThreshold: 0.15,
    worseningThreshold: 0.3,
    valueOf: _bodyTempValue,
    isAttention: _bodyTempAttention,
  ),
  _MetricSpec(
    key: "bmi",
    label: "BMI",
    unit: "kg/m²",
    decimals: 1,
    steadyThreshold: 0.2,
    worseningThreshold: 0.8,
    valueOf: _bmiValue,
    isAttention: _bmiAttention,
  ),
  _MetricSpec(
    key: "heartRate",
    label: "Nabiz",
    unit: "bpm",
    decimals: 0,
    steadyThreshold: 3,
    worseningThreshold: 8,
    valueOf: _heartRateValue,
    isAttention: _heartRateAttention,
  ),
];

const List<_MetricSpec> _trendSpecs = [
  _MetricSpec(
    key: "riskScore",
    label: "Risk skoru",
    unit: "%",
    decimals: 0,
    steadyThreshold: 0.02,
    worseningThreshold: 0.08,
    valueOf: _riskScoreValue,
    isAttention: _riskScoreAttention,
  ),
  ..._metricSpecs,
];

double? _riskScoreValue(WeekEntry entry) =>
    entry.riskScore == null ? null : entry.riskScore! * 100;
double? _systolicValue(WeekEntry entry) => entry.systolic;
double? _diastolicValue(WeekEntry entry) => entry.diastolic;
double? _bloodSugarValue(WeekEntry entry) => entry.bloodSugar;
double? _bodyTempValue(WeekEntry entry) => entry.bodyTemp;
double? _bmiValue(WeekEntry entry) => entry.bmi;
double? _heartRateValue(WeekEntry entry) => entry.heartRate;

bool _riskScoreAttention(double value, String medicalContext) => value >= 60;
bool _systolicAttention(double value, String medicalContext) {
  final hasHistory = medicalContext.contains("hipertansiyon") ||
      medicalContext.contains("tansiyon") ||
      medicalContext.contains("preeklampsi");
  return value >= (hasHistory ? 125 : 130);
}

bool _diastolicAttention(double value, String medicalContext) {
  final hasHistory = medicalContext.contains("hipertansiyon") ||
      medicalContext.contains("tansiyon") ||
      medicalContext.contains("preeklampsi");
  return value >= (hasHistory ? 82 : 85);
}

bool _bloodSugarAttention(double value, String medicalContext) {
  final hasHistory = medicalContext.contains("diyabet") ||
      medicalContext.contains("seker") ||
      medicalContext.contains("insulin");
  return value >= (hasHistory ? 100 : 110);
}

bool _bodyTempAttention(double value, String medicalContext) => value >= 37.2;

bool _bmiAttention(double value, String medicalContext) {
  final hasHistory = medicalContext.contains("obez") ||
      medicalContext.contains("insulin direnci") ||
      medicalContext.contains("kilo");
  return value >= (hasHistory ? 24 : 25);
}

bool _heartRateAttention(double value, String medicalContext) {
  final hasHistory = medicalContext.contains("kalp") ||
      medicalContext.contains("aritmi") ||
      medicalContext.contains("tasikardi");
  return value >= (hasHistory ? 92 : 98);
}
