import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this.api);

  final ApiService api;
  UserProfile? currentUser;
  bool initializing = true;
  bool busy = false;
  String? error;

  Future<void> initialize() async {
    await api.restoreSession();
    if (api.hasToken) {
      try {
        currentUser = await api.fetchMe();
      } catch (e) {
        // If token is invalid, clear it and continue with guest mode.
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
      error = e.toString();
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
      final user = await api.register(name: name, email: email, password: password);
      currentUser = user;
      return true;
    } catch (e) {
      error = e.toString();
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
}

