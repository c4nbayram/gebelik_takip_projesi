import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_models.dart';
import 'api_service.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  StreamSubscription<int>? _remoteSub;

  static const String _channelId = "gebelik_reminders";
  static const String _channelName = "Hatırlatıcılar ve bildirimler";
  static const String _lastSeenKey = "gebelik_last_seen_notification_id";

  static const String _defaultZone = "Europe/Istanbul";

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation(_defaultZone));
    } catch (_) {}

    const androidInit = AndroidInitializationSettings("@mipmap/ic_launcher");
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidInit,
      iOS: darwinInit,
      macOS: darwinInit,
    );

    await _plugin.initialize(settings);
    await _createAndroidChannel();
    await requestPermission();
    _ready = true;
  }

  Future<void> _createAndroidChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: "Su, ölçüm ve uygulama bildirimleri",
        importance: Importance.high,
      ),
    );
  }

  Future<void> requestPermission() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {}
  }

  NotificationDetails _details() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: "Su, ölçüm ve uygulama bildirimleri",
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );

  Future<void> showNow(String title, String? body, {int? id}) async {
    if (!_ready) return;
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      _details(),
    );
  }

  Future<void> scheduleDailyReminders(
      List<NotificationTemplate> templates) async {
    if (!_ready) return;
    for (final t in templates) {
      final hour = t.scheduleHour;
      if (hour == null) continue;
      final id = _stableId(t.key);
      try {
        await _plugin.zonedSchedule(
          id,
          t.title,
          t.body,
          _nextInstanceOf(hour, t.scheduleMinute),
          _details(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      } catch (e) {
        if (kDebugMode) debugPrint("scheduleDailyReminders failed: $e");
      }
    }
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  int _stableId(String key) => key.hashCode & 0x7fffffff;

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  Future<void> attach(ApiService api) async {
    if (!_ready) return;
    try {
      final templates = await api.getNotificationTemplates();
      await scheduleDailyReminders(templates);
    } catch (_) {}
    await _catchUpRemote(api);

    await _remoteSub?.cancel();
    _remoteSub = api.unreadCountStream().listen((_) {
      _catchUpRemote(api);
    });
  }

  Future<void> detach() async {
    await _remoteSub?.cancel();
    _remoteSub = null;
  }

  Future<void> _catchUpRemote(ApiService api) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt(_lastSeenKey) ?? 0;
      final items = await api.getNotifications();
      var maxId = lastSeen;
      for (final n in items.reversed) {
        if (n.id > lastSeen) {
          await showNow(n.title, n.body, id: n.id & 0x7fffffff);
          if (n.id > maxId) maxId = n.id;
        }
      }
      if (maxId > lastSeen) {
        await prefs.setInt(_lastSeenKey, maxId);
      }
    } catch (_) {}
  }
}
