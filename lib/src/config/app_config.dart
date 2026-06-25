import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String _read(String key, {String fallback = ""}) {
    final fromEnv = dotenv.isInitialized ? (dotenv.env[key] ?? "") : "";
    if (fromEnv.trim().isNotEmpty) return fromEnv.trim();
    final fromDefine = String.fromEnvironment(key);
    if (fromDefine.trim().isNotEmpty) return fromDefine.trim();
    return fallback;
  }

  static String get supabaseUrl => _read("SUPABASE_URL");
  static String get supabaseAnonKey => _read("SUPABASE_ANON_KEY");
  static String get supabasePublishableKey => _read("SUPABASE_PUBLISHABLE_KEY");

  static String get supabaseClientKey => supabasePublishableKey.isNotEmpty
      ? supabasePublishableKey
      : supabaseAnonKey;

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseClientKey.isNotEmpty;

  static bool get localOnly => !hasSupabase;

  static String get apiBaseUrl => supabaseUrl;

  static const String profileNameKey = "gebelik_profile_name";
  static const String profileAgeKey = "gebelik_profile_age";
  static const String profileMedicalKey = "gebelik_profile_medical";
  static const String seenOnboardingKey = "gebelik_seen_onboarding";
  static const String authStepDoneKey = "gebelik_auth_step_done";
  static const String firstSetupDoneKey = "gebelik_first_setup_done";
  static const String guestModeKey = "gebelik_guest_mode";
  static const String caregiverRoleKey = "gebelik_caregiver_role";
  static const String babyNameKey = "gebelik_baby_name";
  static const String babyCityKey = "gebelik_baby_city";
  static const String babyBirthDateKey = "gebelik_baby_birth_date";
  static const String lastPeriodStartKey = "gebelik_last_period_start";
  static const String estimatedDueDateKey = "gebelik_estimated_due_date";
  static const String planningBabyKey = "gebelik_planning_baby";
  static const String maternalChronicKey = "gebelik_maternal_chronic";
}
