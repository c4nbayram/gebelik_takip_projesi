import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_common.dart';

class ContractionTimerScreen extends StatefulWidget {
  const ContractionTimerScreen({super.key});

  @override
  State<ContractionTimerScreen> createState() => _ContractionTimerScreenState();
}

class _ContractionTimerScreenState extends State<ContractionTimerScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  Timer? _ticker;
  DateTime? _runningStart;
  Duration _elapsed = Duration.zero;
  bool _busy = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_runningStart == null) {
      if (!await ensureSignedIn(context,
          reason: "Kasılma kaydı için giriş yapmalısın.")) {
        return;
      }
      if (!mounted) return;
    }
    if (_runningStart == null) {
      setState(() {
        _runningStart = DateTime.now();
        _elapsed = Duration.zero;
      });
      _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_runningStart == null) return;
        setState(() => _elapsed = DateTime.now().difference(_runningStart!));
      });
    } else {
      final start = _runningStart!;
      final dur = DateTime.now().difference(start).inSeconds;
      _ticker?.cancel();
      setState(() {
        _busy = true;
        _runningStart = null;
        _elapsed = Duration.zero;
      });
      await _api.addContraction(startedAt: start, durationSeconds: dur);
      if (mounted) setState(() => _busy = false);
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, "0");
    final s = d.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$m:$s";
  }

  String _interval(int seconds) {
    if (seconds <= 0) return "-";
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? "$m dk $s sn" : "$s sn";
  }

  bool _shouldAlert(List<ContractionLog> sorted) {
    final now = DateTime.now();
    final lastHour = sorted
        .where((c) => now.difference(c.startedAt).inMinutes <= 60)
        .toList();
    if (lastHour.length < 8) return false;
    final avgDur =
        lastHour.map((c) => c.durationSeconds).reduce((a, b) => a + b) /
            lastHour.length;
    var intervals = <int>[];
    for (int i = 0; i < lastHour.length - 1; i++) {
      intervals.add(lastHour[i]
          .startedAt
          .difference(lastHour[i + 1].startedAt)
          .inSeconds
          .abs());
    }
    if (intervals.isEmpty) return false;
    final avgInt = intervals.reduce((a, b) => a + b) / intervals.length;
    return avgDur >= 45 && avgInt <= 330;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final running = _runningStart != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Kasılma Zamanlayıcı")),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<ContractionLog>>(
          stream: _api.contractionsStream(),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <ContractionLog>[];
            final alert = _shouldAlert(items);
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
              children: [
                if (alert)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: InfoBanner(
                      tone: PillTone.danger,
                      icon: Icons.local_hospital_rounded,
                      message:
                          "Kasılmaların 5-1-1 düzenine yaklaşıyor (sık, uzun ve düzenli). Doktorunu arayıp hastaneye gitmeyi değerlendir.",
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: InfoBanner(
                      message:
                          "Kasılma başlayınca başlat, bitince durdur. Süre ve aralık otomatik hesaplanır.",
                    ),
                  ),
                Center(
                  child: GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      height: 210,
                      width: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: running
                              ? const [Color(0xFFF2689A), Color(0xFFFF8FB1)]
                              : p.brandGradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: p.glow(running ? p.accent : p.primary,
                            strength: 0.4),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              running
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 48),
                          Text(running ? _fmt(_elapsed) : "Başlat",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900)),
                          Text(
                              running
                                  ? "durdurmak için dokun"
                                  : "kasılma başladığında dokun",
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader(
                  title: "Kasılmalar",
                  subtitle: "Süre ve önceki kasılmaya aralık",
                  icon: Icons.list_alt_rounded,
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.timer_outlined,
                    title: "Henüz kasılma kaydı yok",
                    description:
                        "Bir kasılmayı zamanlayınca burada listelenir.",
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < items.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: AppCard(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: p.accentBg,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(Icons.bolt_rounded,
                                      color: p.accentDeep, size: 20),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Süre ${_fmt(Duration(seconds: items[i].durationSeconds))}",
                                        style: TextStyle(
                                            color: p.textPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                      ),
                                      Text(
                                        "${DateFormat("HH:mm:ss").format(items[i].startedAt)}  •  aralık: ${i < items.length - 1 ? _interval(items[i].startedAt.difference(items[i + 1].startedAt).inSeconds.abs()) : "-"}",
                                        style: TextStyle(
                                            color: p.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      _api.deleteContraction(items[i].id),
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: p.danger, size: 20),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
