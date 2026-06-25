import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/icon_catalog.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  List<AppNotification> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await _api.getNotifications();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
    final unreadIds =
        items.where((n) => !n.read).map((n) => n.id).toList(growable: false);
    if (unreadIds.isNotEmpty) {
      await _api.markAllNotificationsRead(unreadIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bildirimler"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: p.primary,
          backgroundColor: p.surface,
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: const [
                        SizedBox(height: AppSpacing.xxl),
                        EmptyState(
                          icon: Icons.notifications_off_rounded,
                          title: "Henüz bildirim yok",
                          description:
                              "Hatırlatıcıların ve uygulama duyuruların burada görünür.",
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xxl,
                      ),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, i) => _tile(p, _items[i]),
                    ),
        ),
      ),
    );
  }

  Widget _tile(AppPalette p, AppNotification n) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: p.primaryBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(iconForName(n.icon), color: p.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        n.title,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!n.read)
                      Container(
                        height: 8,
                        width: 8,
                        decoration: BoxDecoration(
                          color: p.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (n.body != null && n.body!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.body!,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  DateFormat("dd MMM yyyy • HH:mm", "tr_TR")
                      .format(n.createdAt),
                  style: TextStyle(color: p.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
