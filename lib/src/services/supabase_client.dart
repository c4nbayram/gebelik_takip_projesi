import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';

import '../config/app_config.dart';

class SupabaseBootstrap {
  SupabaseBootstrap._();

  static SupabaseClient? _client;
  static const String _sessionKey = "gebelik_supabase_session";

  static bool get isReady => _client != null && AppConfig.hasSupabase;

  static String get _apiKey => AppConfig.supabaseAnonKey.isNotEmpty
      ? AppConfig.supabaseAnonKey
      : AppConfig.supabasePublishableKey;

  static Future<void> ensureInitialized() async {
    if (_client != null || !AppConfig.hasSupabase) return;

    final client = SupabaseClient(
      AppConfig.supabaseUrl,
      _apiKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );
    _client = client;

    client.auth.onAuthStateChange.listen((data) async {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = data.session?.refreshToken;
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString(_sessionKey, refreshToken);
      } else if (data.event == AuthChangeEvent.signedOut) {
        await prefs.remove(_sessionKey);
      }
    });

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_sessionKey);
    if (stored != null && stored.isNotEmpty) {
      try {
        await client.auth.setSession(stored);
      } catch (_) {}
    }
  }

  static SupabaseClient get client => _client!;
  static GoTrueClient get auth => client.auth;
}
