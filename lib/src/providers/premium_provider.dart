import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class PremiumProvider extends ChangeNotifier {
  PremiumProvider()
      : _api = ApiService(
          baseUrl: AppConfig.apiBaseUrl,
          localOnly: AppConfig.localOnly,
        );

  final ApiService _api;
  Subscription? subscription;
  bool loading = false;
  String? _lastUid;

  bool get isPremium =>
      subscription?.isActive == true &&
      (subscription?.features.isNotEmpty ?? false);

  bool hasFeature(String key) {
    if (subscription?.isActive != true) return false;
    final features = subscription?.features ?? const <String>[];
    if (features.contains(key)) return true;

    const legacyKeys = {
      "guide": "ai_chat",
      "detailed_assessment": "ai_advice",
    };
    return features.contains(legacyKeys[key]);
  }

  String get planLabel =>
      isPremium ? (subscription?.planName ?? "Premium") : "Ücretsiz";

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      subscription = await _api.getActiveSubscription();
    } catch (_) {
      subscription = null;
    }
    loading = false;
    notifyListeners();
  }

  void applyPurchase(Subscription sub) {
    subscription = sub;
    notifyListeners();
  }

  void syncWithAuth(AuthProvider auth) {
    final uid = auth.currentUser?.id;
    if (uid == _lastUid) return;
    _lastUid = uid;
    if (uid == null) {
      subscription = null;
      notifyListeners();
    } else {
      refresh();
    }
  }
}
