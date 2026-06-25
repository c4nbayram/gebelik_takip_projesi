import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_common.dart';

class KickCounterScreen extends StatefulWidget {
  const KickCounterScreen({super.key});

  @override
  State<KickCounterScreen> createState() => _KickCounterScreenState();
}

class _KickCounterScreenState extends State<KickCounterScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  Timer? _ticker;
  DateTime? _startedAt;
  int _count = 0;
  Duration _elapsed = Duration.zero;
  bool _saving = false;

  static const int _goal = 10;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _startedAt = DateTime.now();
      _count = 0;
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt!));
    });
  }

  void _tap() {
    if (_startedAt == null) {
      _start();
    }
    setState(() => _count++);
  }

  Future<void> _finish() async {
    if (_startedAt == null || _saving) return;
    if (!await ensureSignedIn(context,
        reason: "Tekme seansını kaydetmek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    _ticker?.cancel();
    try {
      await _api.addKickSession(
        startedAt: _startedAt!,
        endedAt: DateTime.now(),
        kickCount: _count,
        durationSeconds: _elapsed.inSeconds,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Seans kaydedildi 🤍")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _startedAt = null;
          _count = 0;
          _elapsed = Duration.zero;
          _saving = false;
        });
      }
    }
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _startedAt = null;
      _count = 0;
      _elapsed = Duration.zero;
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final s = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "${d.inHours > 0 ? "${d.inHours}:" : ""}$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final active = _startedAt != null;
    final progress = (_count / _goal).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(title: const Text("Tekme Sayar")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
          children: [
            const InfoBanner(
              message:
                  "Bebeğin hareket etmeye başladığında say. 10 hareketi ne kadar sürede yaptığını takip et.",
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: GestureDetector(
                onTap: _saving ? null : _tap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 230,
                  width: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: p.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: p.glow(p.primary, strength: 0.4),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 230,
                        width: 230,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("$_count",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 64,
                                  fontWeight: FontWeight.w900,
                                  height: 1)),
                          Text(active ? "dokun → say" : "başlamak için dokun",
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _stat(p, Icons.timer_outlined, "Süre", _fmt(_elapsed)),
                const SizedBox(width: AppSpacing.md),
                _stat(p, Icons.flag_rounded, "Hedef", "$_count / $_goal"),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    onPressed: active ? _reset : null,
                    label: "Sıfırla",
                    icon: Icons.refresh_rounded,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    onPressed: active ? _finish : null,
                    loading: _saving,
                    label: "Kaydet",
                    icon: Icons.check_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Geçmiş Seanslar",
              subtitle: "Son tekme seansların",
              icon: Icons.history_rounded,
            ),
            StreamBuilder<List<KickSession>>(
              stream: _api.kickSessionsStream(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.touch_app_rounded,
                    title: "Henüz seans yok",
                    description: "İlk tekme seansını kaydet, burada görünsün.",
                  );
                }
                return Column(
                  children: [
                    for (final s in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          child: Row(
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: p.primaryBg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                alignment: Alignment.center,
                                child: Text("${s.kickCount}",
                                    style: TextStyle(
                                        color: p.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16)),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("${s.kickCount} hareket",
                                        style: TextStyle(
                                            color: p.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14)),
                                    Text(
                                      "${DateFormat("dd MMM • HH:mm", "tr_TR").format(s.startedAt)} • ${_fmt(Duration(seconds: s.durationSeconds))}",
                                      style: TextStyle(
                                          color: p.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _api.deleteKickSession(s.id),
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: p.danger, size: 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(AppPalette p, IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: p.borderSoft),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: p.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: p.textMuted, fontSize: 11)),
              Text(value,
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
