class UserProfile {
  final String id;
  final String name;
  final String email;
  final int? age;
  final String? medicalHistory;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.age,
    this.medicalHistory,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json["id"] ?? "").toString(),
      name: (json["name"] as String?)?.trim() ?? "",
      email: (json["email"] as String?)?.trim() ?? "",
      age: (json["age"] as num?)?.toInt(),
      medicalHistory: (json["medical_history"] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "email": email,
      "age": age,
      "medical_history": medicalHistory,
    };
  }
}

class HealthAnalyzeRequest {
  final int weekNo;
  final int? profileAge;
  final String? medicalHistory;
  final double systolic;
  final double diastolic;
  final double bloodSugar;
  final double bodyTemp;
  final double bmi;
  final double heartRate;
  final bool update;

  HealthAnalyzeRequest({
    required this.weekNo,
    this.profileAge,
    this.medicalHistory,
    required this.systolic,
    required this.diastolic,
    required this.bloodSugar,
    required this.bodyTemp,
    required this.bmi,
    required this.heartRate,
    this.update = false,
  });

  Map<String, dynamic> toJson() {
    return {
      "week_no": weekNo,
      "profile_age": profileAge,
      "medical_history": medicalHistory,
      "systolic_bp": systolic,
      "diastolic": diastolic,
      "bs": bloodSugar,
      "body_temp": bodyTemp,
      "bmi": bmi,
      "heart_rate": heartRate,
      "update": update ? "1" : "0",
    };
  }
}

class HealthAnalyzeResult {
  final int weekNo;
  final String riskLabel;
  final double riskScore;
  final int knnK;
  final int knnHigh;
  final int knnMid;
  final int knnLow;
  final double avgDistance;
  final String aiAdvice;

  final String source;

  HealthAnalyzeResult({
    required this.weekNo,
    required this.riskLabel,
    required this.riskScore,
    required this.knnK,
    required this.knnHigh,
    this.knnMid = 0,
    this.knnLow = 0,
    this.avgDistance = 0,
    required this.aiAdvice,
    this.source = "local",
  });

  bool get fromDataset => source == "dataset";

  factory HealthAnalyzeResult.fromJson(Map<String, dynamic> json) {
    final knn = json["knn"] as Map<String, dynamic>? ?? {};
    return HealthAnalyzeResult(
      weekNo: (json["week_no"] as num?)?.toInt() ?? 0,
      riskLabel: (json["risk_label"] as String?)?.trim() ?? "Low",
      riskScore: (json["risk_score"] as num?)?.toDouble() ?? 0.0,
      knnK: (knn["k"] as num?)?.toInt() ?? 0,
      knnHigh: (knn["high_count"] as num?)?.toInt() ?? 0,
      knnMid: (knn["mid_count"] as num?)?.toInt() ?? 0,
      knnLow: (knn["low_count"] as num?)?.toInt() ?? 0,
      avgDistance: (knn["avg_distance"] as num?)?.toDouble() ?? 0,
      aiAdvice: (json["ai_advice"] as String?)?.trim() ?? "",
      source: (json["source"] as String?)?.trim() ?? "local",
    );
  }
}

enum TrendDirection { up, down, steady }

class TrendPoint {
  final int weekNo;
  final double value;

  const TrendPoint({
    required this.weekNo,
    required this.value,
  });
}

class MetricTrendSeries {
  final String key;
  final String label;
  final String unit;
  final List<TrendPoint> points;

  const MetricTrendSeries({
    required this.key,
    required this.label,
    required this.unit,
    required this.points,
  });
}

class MetricComparison {
  final String key;
  final String label;
  final String unit;
  final double currentValue;
  final double? previousValue;
  final double delta;
  final TrendDirection direction;
  final String status;
  final String summary;

  const MetricComparison({
    required this.key,
    required this.label,
    required this.unit,
    required this.currentValue,
    required this.previousValue,
    required this.delta,
    required this.direction,
    required this.status,
    required this.summary,
  });
}

class TrackingInsight {
  final int selectedWeek;
  final int? focusWeek;
  final bool selectedWeekHasEntry;
  final WeekEntry? focusEntry;
  final WeekEntry? previousEntry;
  final String headline;
  final String summary;
  final List<String> recommendations;
  final List<String> medicalFlags;
  final List<MetricComparison> comparisons;
  final List<MetricTrendSeries> trendSeries;
  final int trackedWeeks;
  final double averageRiskScore;
  final int? highestRiskWeek;
  final double? highestRiskScore;

  const TrackingInsight({
    required this.selectedWeek,
    required this.focusWeek,
    required this.selectedWeekHasEntry,
    required this.focusEntry,
    required this.previousEntry,
    required this.headline,
    required this.summary,
    required this.recommendations,
    required this.medicalFlags,
    required this.comparisons,
    required this.trendSeries,
    required this.trackedWeeks,
    required this.averageRiskScore,
    required this.highestRiskWeek,
    required this.highestRiskScore,
  });
}

class WeekInfo {
  final int weekNo;
  final String text;

  WeekInfo({required this.weekNo, required this.text});

  factory WeekInfo.fromJson(Map<String, dynamic> json) {
    return WeekInfo(
      weekNo: (json["week"] as num?)?.toInt() ?? 1,
      text: (json["text"] as String?)?.trim() ?? "",
    );
  }
}

class WeekEntry {
  final int weekNo;
  final double? riskScore;
  final String? riskLabel;
  final DateTime? updatedAt;
  final double? systolic;
  final double? diastolic;
  final double? bloodSugar;
  final double? bodyTemp;
  final double? bmi;
  final double? heartRate;

  WeekEntry({
    required this.weekNo,
    this.riskScore,
    this.riskLabel,
    this.updatedAt,
    this.systolic,
    this.diastolic,
    this.bloodSugar,
    this.bodyTemp,
    this.bmi,
    this.heartRate,
  });

  factory WeekEntry.fromJson(Map<String, dynamic> json) {
    return WeekEntry(
      weekNo: (json["week_no"] as num?)?.toInt() ?? 0,
      riskScore: (json["risk_score"] as num?)?.toDouble(),
      riskLabel: (json["risk_label"] as String?)?.trim(),
      updatedAt: DateTime.tryParse((json["updated_at"] as String?) ?? ""),
      systolic: (json["systolic_bp"] as num?)?.toDouble(),
      diastolic: (json["diastolic"] as num?)?.toDouble(),
      bloodSugar: (json["bs"] as num?)?.toDouble(),
      bodyTemp: (json["body_temp"] as num?)?.toDouble(),
      bmi: (json["bmi"] as num?)?.toDouble(),
      heartRate: (json["heart_rate"] as num?)?.toDouble(),
    );
  }
}

class ChatMessage {
  final String message;
  final bool fromUser;
  final DateTime createdAt;

  ChatMessage({
    required this.message,
    required this.fromUser,
    required this.createdAt,
  });
}

class Appointment {
  final int id;
  final String title;
  final DateTime appointmentAt;
  final String? notes;

  Appointment({
    required this.id,
    required this.title,
    required this.appointmentAt,
    this.notes,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: (json["id"] as num?)?.toInt() ?? 0,
      title: (json["title"] as String?)?.trim() ?? "",
      appointmentAt:
          DateTime.tryParse((json["appointment_at"] as String?) ?? "") ??
              DateTime.now(),
      notes: (json["notes"] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "appointment_at": appointmentAt.toIso8601String(),
      "notes": notes ?? "",
    };
  }
}

class Medication {
  final int id;
  final String name;
  final String? dosage;
  final String? frequency;
  final String? startDate;
  final String? endDate;
  final List<String> times;
  final String? notes;

  Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.frequency,
    this.startDate,
    this.endDate,
    required this.times,
    this.notes,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    final timesRaw = json["times_json"] ?? json["times"] ?? "[]";
    final parsed =
        (timesRaw is List) ? timesRaw : (timesRaw is String ? [] : []);
    final times = parsed.map((e) => e.toString()).toList();

    return Medication(
      id: (json["id"] as num?)?.toInt() ?? 0,
      name: (json["name"] as String?)?.trim() ?? "",
      dosage: (json["dosage"] as String?)?.trim(),
      frequency: (json["frequency"] as String?)?.trim(),
      startDate: (json["start_date"] as String?)?.trim(),
      endDate: (json["end_date"] as String?)?.trim(),
      times: times,
      notes: (json["notes"] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson({
    required DateTime? start,
    required DateTime? end,
    required String timesCsv,
  }) {
    return {
      "name": name,
      "dosage": dosage ?? "",
      "frequency": frequency ?? "",
      "start_date":
          start == null ? "" : start.toIso8601String().split("T").first,
      "end_date": end == null ? "" : end.toIso8601String().split("T").first,
      "times": timesCsv,
      "notes": notes ?? "",
    };
  }
}

class KickSession {
  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int kickCount;
  final int durationSeconds;

  KickSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.kickCount,
    required this.durationSeconds,
  });

  factory KickSession.fromRow(Map<String, dynamic> r) => KickSession(
        id: (r["id"] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(r["started_at"]?.toString() ?? "") ??
            DateTime.now(),
        endedAt: DateTime.tryParse(r["ended_at"]?.toString() ?? ""),
        kickCount: (r["kick_count"] as num?)?.toInt() ?? 0,
        durationSeconds: (r["duration_seconds"] as num?)?.toInt() ?? 0,
      );
}

class ContractionLog {
  final int id;
  final DateTime startedAt;
  final int durationSeconds;

  ContractionLog({
    required this.id,
    required this.startedAt,
    required this.durationSeconds,
  });

  factory ContractionLog.fromRow(Map<String, dynamic> r) => ContractionLog(
        id: (r["id"] as num?)?.toInt() ?? 0,
        startedAt: DateTime.tryParse(r["started_at"]?.toString() ?? "") ??
            DateTime.now(),
        durationSeconds: (r["duration_seconds"] as num?)?.toInt() ?? 0,
      );
}

class WeightEntry {
  final int id;
  final DateTime recordedOn;
  final double weightKg;
  final int? weekNo;
  final String? note;

  WeightEntry({
    required this.id,
    required this.recordedOn,
    required this.weightKg,
    this.weekNo,
    this.note,
  });

  factory WeightEntry.fromRow(Map<String, dynamic> r) => WeightEntry(
        id: (r["id"] as num?)?.toInt() ?? 0,
        recordedOn: DateTime.tryParse(r["recorded_on"]?.toString() ?? "") ??
            DateTime.now(),
        weightKg: (r["weight_kg"] as num?)?.toDouble() ?? 0,
        weekNo: (r["week_no"] as num?)?.toInt(),
        note: (r["note"] as String?)?.trim(),
      );
}

class WaterLog {
  final int id;
  final DateTime day;
  final int glasses;
  final int goal;

  WaterLog({
    required this.id,
    required this.day,
    required this.glasses,
    required this.goal,
  });

  factory WaterLog.fromRow(Map<String, dynamic> r) => WaterLog(
        id: (r["id"] as num?)?.toInt() ?? 0,
        day: DateTime.tryParse(r["day"]?.toString() ?? "") ?? DateTime.now(),
        glasses: (r["glasses"] as num?)?.toInt() ?? 0,
        goal: (r["goal"] as num?)?.toInt() ?? 8,
      );
}

class JournalEntry {
  final int id;
  final String? mood;
  final String? note;
  final DateTime createdAt;

  JournalEntry({
    required this.id,
    this.mood,
    this.note,
    required this.createdAt,
  });

  factory JournalEntry.fromRow(Map<String, dynamic> r) => JournalEntry(
        id: (r["id"] as num?)?.toInt() ?? 0,
        mood: (r["mood"] as String?)?.trim(),
        note: (r["note"] as String?)?.trim(),
        createdAt: DateTime.tryParse(r["created_at"]?.toString() ?? "") ??
            DateTime.now(),
      );
}

class BabyName {
  final int id;
  final String name;
  final String? gender;
  final bool isFavorite;
  final String? note;

  BabyName({
    required this.id,
    required this.name,
    this.gender,
    required this.isFavorite,
    this.note,
  });

  factory BabyName.fromRow(Map<String, dynamic> r) => BabyName(
        id: (r["id"] as num?)?.toInt() ?? 0,
        name: (r["name"] as String?)?.trim() ?? "",
        gender: (r["gender"] as String?)?.trim(),
        isFavorite: r["is_favorite"] == true,
        note: (r["note"] as String?)?.trim(),
      );
}

class SymptomLog {
  final int id;
  final DateTime loggedOn;
  final int? weekNo;
  final List<String> symptoms;
  final int? severity;
  final String? note;
  final DateTime createdAt;

  SymptomLog({
    required this.id,
    required this.loggedOn,
    this.weekNo,
    required this.symptoms,
    this.severity,
    this.note,
    required this.createdAt,
  });

  factory SymptomLog.fromRow(Map<String, dynamic> r) {
    final raw = r["symptoms"];
    final list = (raw is List)
        ? raw.map((e) => e.toString()).toList(growable: false)
        : const <String>[];
    return SymptomLog(
      id: (r["id"] as num?)?.toInt() ?? 0,
      loggedOn:
          DateTime.tryParse(r["logged_on"]?.toString() ?? "") ?? DateTime.now(),
      weekNo: (r["week_no"] as num?)?.toInt(),
      symptoms: list,
      severity: (r["severity"] as num?)?.toInt(),
      note: (r["note"] as String?)?.trim(),
      createdAt: DateTime.tryParse(r["created_at"]?.toString() ?? "") ??
          DateTime.now(),
    );
  }
}

class ChecklistItem {
  final int id;
  final String category;
  final String title;
  final bool isDone;
  final int sortOrder;

  ChecklistItem({
    required this.id,
    required this.category,
    required this.title,
    required this.isDone,
    required this.sortOrder,
  });

  factory ChecklistItem.fromRow(Map<String, dynamic> r) => ChecklistItem(
        id: (r["id"] as num?)?.toInt() ?? 0,
        category: (r["category"] as String?)?.trim() ?? "",
        title: (r["title"] as String?)?.trim() ?? "",
        isDone: r["is_done"] == true,
        sortOrder: (r["sort_order"] as num?)?.toInt() ?? 0,
      );
}

class BabyLog {
  final int id;
  final String type;
  final DateTime occurredAt;
  final String? amount;
  final String? note;

  BabyLog({
    required this.id,
    required this.type,
    required this.occurredAt,
    this.amount,
    this.note,
  });

  factory BabyLog.fromRow(Map<String, dynamic> r) => BabyLog(
        id: (r["id"] as num?)?.toInt() ?? 0,
        type: (r["type"] as String?)?.trim() ?? "",
        occurredAt: DateTime.tryParse(r["occurred_at"]?.toString() ?? "") ??
            DateTime.now(),
        amount: (r["amount"] as String?)?.trim(),
        note: (r["note"] as String?)?.trim(),
      );
}

class AppNotification {
  final int id;
  final String title;
  final String? body;
  final String? category;
  final String? icon;
  final DateTime createdAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.category,
    this.icon,
    required this.createdAt,
    this.read = false,
  });

  factory AppNotification.fromRow(Map<String, dynamic> r,
          {bool read = false}) =>
      AppNotification(
        id: (r["id"] as num?)?.toInt() ?? 0,
        title: (r["title"] as String?)?.trim() ?? "",
        body: (r["body"] as String?)?.trim(),
        category: (r["category"] as String?)?.trim(),
        icon: (r["icon"] as String?)?.trim(),
        createdAt: DateTime.tryParse(r["created_at"]?.toString() ?? "") ??
            DateTime.now(),
        read: read,
      );
}

class NotificationTemplate {
  final String key;
  final String title;
  final String? body;
  final String? icon;
  final int? scheduleHour;
  final int scheduleMinute;

  NotificationTemplate({
    required this.key,
    required this.title,
    this.body,
    this.icon,
    this.scheduleHour,
    this.scheduleMinute = 0,
  });

  factory NotificationTemplate.fromRow(Map<String, dynamic> r) =>
      NotificationTemplate(
        key: (r["key"] as String?)?.trim() ?? "",
        title: (r["title"] as String?)?.trim() ?? "",
        body: (r["body"] as String?)?.trim(),
        icon: (r["icon"] as String?)?.trim(),
        scheduleHour: (r["schedule_hour"] as num?)?.toInt(),
        scheduleMinute: (r["schedule_minute"] as num?)?.toInt() ?? 0,
      );
}

class Plan {
  final String code;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final String period;
  final int? durationMonths;
  final List<String> features;
  final List<String> perks;

  Plan({
    required this.code,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.period,
    this.durationMonths,
    required this.features,
    required this.perks,
  });

  bool get isFree => price <= 0 || features.isEmpty;

  String get periodLabel {
    final m = durationMonths;
    if (m == null) return "";
    if (m == 1) return "/ay";
    return " / $m ay";
  }

  String get durationLabel {
    final m = durationMonths;
    if (m == null) return isFree ? "Süresiz" : "Ömür boyu";
    if (m == 1) return "1 ay erişim";
    if (m == 9) return "Doğuma kadar (9 ay)";
    return "$m ay erişim";
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  factory Plan.fromRow(Map<String, dynamic> r) => Plan(
        code: (r["code"] as String?)?.trim() ?? "",
        name: (r["name"] as String?)?.trim() ?? "",
        description: (r["description"] as String?)?.trim(),
        price: (r["price"] as num?)?.toDouble() ?? 0,
        currency: (r["currency"] as String?)?.trim() ?? "TRY",
        period: (r["period"] as String?)?.trim() ?? "monthly",
        durationMonths: (r["duration_months"] as num?)?.toInt(),
        features: _stringList(r["features"]),
        perks: _stringList(r["perks"]),
      );
}

class PremiumContent {
  final int id;
  final String title;
  final String? summary;
  final String? body;
  final String? category;
  final String? icon;
  final String requiredFeature;

  PremiumContent({
    required this.id,
    required this.title,
    this.summary,
    this.body,
    this.category,
    this.icon,
    this.requiredFeature = "premium_content",
  });

  factory PremiumContent.fromRow(Map<String, dynamic> r) => PremiumContent(
        id: (r["id"] as num?)?.toInt() ?? 0,
        title: (r["title"] as String?)?.trim() ?? "",
        summary: (r["summary"] as String?)?.trim(),
        body: (r["body"] as String?)?.trim(),
        category: (r["category"] as String?)?.trim(),
        icon: (r["icon"] as String?)?.trim(),
        requiredFeature:
            (r["required_feature"] as String?)?.trim() ?? "premium_content",
      );
}

class Subscription {
  final int id;
  final String planCode;
  final String planName;
  final double price;
  final String currency;
  final String status;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final List<String> features;

  Subscription({
    required this.id,
    required this.planCode,
    required this.planName,
    this.price = 0,
    this.currency = "TRY",
    this.status = "active",
    this.startedAt,
    this.expiresAt,
    this.features = const [],
  });

  bool get isActive {
    if (status != "active") return false;
    final exp = expiresAt;
    if (exp == null) return true;
    return exp.isAfter(DateTime.now());
  }

  factory Subscription.fromRow(
    Map<String, dynamic> r, {
    List<String> features = const [],
  }) =>
      Subscription(
        id: (r["id"] as num?)?.toInt() ?? 0,
        planCode: (r["plan_code"] as String?)?.trim() ?? "",
        planName: (r["plan_name"] as String?)?.trim() ?? "",
        price: (r["price"] as num?)?.toDouble() ?? 0,
        currency: (r["currency"] as String?)?.trim() ?? "TRY",
        status: (r["status"] as String?)?.trim() ?? "active",
        startedAt: DateTime.tryParse(r["started_at"]?.toString() ?? ""),
        expiresAt: DateTime.tryParse(r["expires_at"]?.toString() ?? ""),
        features: features,
      );
}
