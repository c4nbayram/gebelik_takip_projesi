class UserProfile {
  final int id;
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
      id: (json["id"] as num?)?.toInt() ?? 0,
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
  final String aiAdvice;

  HealthAnalyzeResult({
    required this.weekNo,
    required this.riskLabel,
    required this.riskScore,
    required this.knnK,
    required this.knnHigh,
    required this.aiAdvice,
  });

  factory HealthAnalyzeResult.fromJson(Map<String, dynamic> json) {
    final knn = json["knn"] as Map<String, dynamic>? ?? {};
    return HealthAnalyzeResult(
      weekNo: (json["week_no"] as num?)?.toInt() ?? 0,
      riskLabel: (json["risk_label"] as String?)?.trim() ?? "Low",
      riskScore: (json["risk_score"] as num?)?.toDouble() ?? 0.0,
      knnK: (knn["k"] as num?)?.toInt() ?? 0,
      knnHigh: (knn["high_count"] as num?)?.toInt() ?? 0,
      aiAdvice: (json["ai_advice"] as String?)?.trim() ?? "",
    );
  }
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
      appointmentAt: DateTime.tryParse((json["appointment_at"] as String?) ?? "") ??
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
    final parsed = (timesRaw is List)
        ? timesRaw
        : (timesRaw is String ? [] : []);
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
      "start_date": start == null ? "" : start.toIso8601String().split("T").first,
      "end_date": end == null ? "" : end.toIso8601String().split("T").first,
      "times": timesCsv,
      "notes": notes ?? "",
    };
  }
}

