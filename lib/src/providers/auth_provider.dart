import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase/supabase.dart' show AuthChangeEvent;

import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/supabase_client.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.api) {
    _subscribe();
  }

  final ApiService api;
  UserProfile? currentUser;
  bool initializing = true;
  bool busy = false;
  String? error;

  StreamSubscription<dynamic>? _authSub;

  void _subscribe() {
    if (!SupabaseBootstrap.isReady) return;
    _authSub = SupabaseBootstrap.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        currentUser = null;
        notifyListeners();
      } else if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.userUpdated) {
        try {
          currentUser = await api.fetchMe();
        } catch (_) {}
        notifyListeners();
      }
    });
  }

  Future<void> initialize() async {
    await api.restoreSession();
    if (api.hasToken) {
      try {
        currentUser = await api.fetchMe();
      } catch (e) {
        await api.clearSession();
      }
    }
    initializing = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      busy = true;
      error = null;
      notifyListeners();
      final user = await api.login(email: email, password: password);
      currentUser = user;
      return true;
    } catch (e) {
      error = _readableError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> register(String name, String email, String password) async {
    try {
      busy = true;
      error = null;
      notifyListeners();
      final user =
          await api.register(name: name, email: email, password: password);
      currentUser = user;
      return true;
    } catch (e) {
      error = _readableError(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await api.logout();
    currentUser = null;
    notifyListeners();
  }

  void markSignedOut() {
    currentUser = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  String _readableError(Object e) {
    final raw = e.toString();
    const prefix = "Exception: ";
    if (raw.startsWith(prefix)) return raw.substring(prefix.length);
    return raw;
  }
}
