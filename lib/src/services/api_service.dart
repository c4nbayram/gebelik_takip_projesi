import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';

class ApiService {
  ApiService({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _token;

  static const String _authTokenKey = "gebelik_auth_token";
  static const String _userNameKey = "gebelik_user_name";
  static const String _userEmailKey = "gebelik_user_email";
  static const String _userIdKey = "gebelik_user_id";

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_authTokenKey);
  }

  Future<void> _saveSession(UserProfile user, {String? token}) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null && token.isNotEmpty) {
      await prefs.setString(_authTokenKey, token);
    }
    await prefs.setInt(_userIdKey, user.id);
    await prefs.setString(_userNameKey, user.name);
    await prefs.setString(_userEmailKey, user.email);
  }

  Future<void> clearSession() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
  }

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<Map<String, String>> _headers([bool auth = true]) async {
    final headers = {
      "Content-Type": "application/json; charset=UTF-8",
      "Accept": "application/json",
    };
    if (auth && _token != null && _token!.isNotEmpty) {
      headers["Authorization"] = "Bearer $_token";
    }
    return headers;
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final uri = Uri.parse("$baseUrl/$path");
    final headers = await _headers(auth);
    late final http.Response response;

    try {
      switch (method) {
        case "GET":
          response = await _client.get(uri, headers: headers);
          break;
        case "POST":
          response = await _client.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
          break;
        case "DELETE":
          response = await _client.delete(uri, headers: headers);
          break;
        default:
          throw Exception("Unsupported method: $method");
      }
    } catch (err) {
      throw Exception("Baglanti hatasi: $err");
    }

    if (response.statusCode >= 500) {
      throw Exception("Sunucu hatasi: ${response.statusCode}");
    }

    final dynamic payload = response.body.isEmpty
        ? {"ok": true}
        : jsonDecode(response.body) as dynamic;

    if (payload is Map<String, dynamic> && payload["ok"] == false) {
      throw Exception(payload["message"] ?? "Sunucu istegi basarisiz oldu.");
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception("Yetkisiz istek. Lutfen giris yapin.");
    }
    if (response.statusCode >= 400) {
      final msg = payload is Map<String, dynamic>
          ? (payload["message"] ?? "Bilinmeyen hata")
          : "HTTP ${response.statusCode}";
      throw Exception(msg);
    }

    return payload;
  }

  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final payload = await _request(
      method: "POST",
      path: "api/auth_register.php",
      auth: false,
      body: {
        "name": name,
        "email": email,
        "password": password,
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw Exception("Gecersiz yanit formatı.");
    }

    final user = UserProfile.fromJson(payload["user"] as Map<String, dynamic>);
    final token = payload["token"] as String?;
    await _saveSession(user, token: token);
    return user;
  }

  Future<UserProfile> login({
    required String email,
    required String password,
  }) async {
    final payload = await _request(
      method: "POST",
      path: "api/auth_login.php",
      auth: false,
      body: {
        "email": email,
        "password": password,
      },
    );

    if (payload is! Map<String, dynamic>) {
      throw Exception("Gecersiz yanit formatı.");
    }

    final user = UserProfile.fromJson(payload["user"] as Map<String, dynamic>);
    final token = payload["token"] as String?;
    await _saveSession(user, token: token);
    return user;
  }

  Future<UserProfile> fetchMe() async {
    final payload = await _request(
      method: "GET",
      path: "api/auth_me.php",
      auth: true,
    );
    if (payload is! Map<String, dynamic>) {
      throw Exception("Gecersiz yanit formatı.");
    }
    return UserProfile.fromJson(payload["user"] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await _request(method: "POST", path: "api/auth_logout.php", auth: true, body: {});
    await clearSession();
  }

  Future<WeekInfo> getWeekInfo(int weekNo) async {
    final payload = await _request(
      method: "GET",
      path: "api/week_info.php?week=$weekNo",
      auth: false,
    );
    return WeekInfo.fromJson(payload as Map<String, dynamic>);
  }

  Future<List<WeekEntry>> getWeekEntries() async {
    final payload = await _request(
      method: "GET",
      path: "api/week_entries.php",
      auth: true,
    );
    if (payload is! List<dynamic>) return [];
    return payload
        .map((e) => WeekEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<HealthAnalyzeResult> analyzeWeek(HealthAnalyzeRequest request) async {
    final payload = await _request(
      method: "POST",
      path: "api/analyze.php",
      auth: true,
      body: request.toJson(),
    );
    return HealthAnalyzeResult.fromJson(payload as Map<String, dynamic>);
  }

  Future<void> saveWeekProfile(int age, String? medicalHistory) async {
    await _request(
      method: "POST",
      path: "api/profile.php",
      auth: true,
      body: {
        "age": age,
        "medical_history": medicalHistory ?? "",
      },
    );
  }

  Future<String> sendChat(String message, {bool includeLatest = false}) async {
    final payload = await _request(
      method: "POST",
      path: "api/chat.php",
      auth: true,
      body: {
        "message": message,
        "include_latest": includeLatest ? 1 : 0,
      },
    );
    return (payload is Map<String, dynamic>) ? (payload["reply"] as String? ?? "") : "";
  }

  Future<List<Appointment>> getAppointments() async {
    final payload = await _request(
      method: "GET",
      path: "api/appointments.php",
      auth: true,
    );
    if (payload is! List<dynamic>) return [];
    return payload
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<void> addAppointment(Appointment appointment) async {
    await _request(
      method: "POST",
      path: "api/appointments.php",
      auth: true,
      body: appointment.toJson(),
    );
  }

  Future<void> deleteAppointment(int id) async {
    await _request(
      method: "DELETE",
      path: "api/appointments.php?id=$id",
      auth: true,
    );
  }

  Future<List<Medication>> getMedications() async {
    final payload = await _request(
      method: "GET",
      path: "api/medications.php",
      auth: true,
    );
    if (payload is! List<dynamic>) return [];
    return payload
        .map((e) => Medication.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
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
    await _request(
      method: "POST",
      path: "api/medications.php",
      auth: true,
      body: {
        "name": name,
        "dosage": dosage ?? "",
        "frequency": frequency ?? "",
        "start_date": startDate == null
            ? ""
            : "${startDate.year.toString().padLeft(4, "0")}-${startDate.month.toString().padLeft(2, "0")}-${startDate.day.toString().padLeft(2, "0")}",
        "end_date": endDate == null
            ? ""
            : "${endDate.year.toString().padLeft(4, "0")}-${endDate.month.toString().padLeft(2, "0")}-${endDate.day.toString().padLeft(2, "0")}",
        "times": times,
        "notes": notes ?? "",
      },
    );
  }

  Future<void> deleteMedication(int id) async {
    await _request(
      method: "DELETE",
      path: "api/medications.php?id=$id",
      auth: true,
    );
  }
}

