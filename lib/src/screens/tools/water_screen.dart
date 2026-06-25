import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_common.dart';

class WaterScreen extends StatefulWidget {
  const WaterScreen({super.key});

  @override
  State<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends State<WaterScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  int _glasses = 0;
  int _goal = 8;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await _api.getTodayWater();
    if (!mounted) return;
    setState(() {
      _glasses = log?.glasses ?? 0;
      _goal = log?.goal ?? 8;
      _loading = false;
    });
  }

  Future<void> _change(int delta) async {
    if (!await ensureSignedIn(context,
        reason: "Su takibini kaydetmek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _glasses = (_glasses + delta).clamp(0, 30));
    _api.setWater(glasses: _glasses, goal: _goal);
  }

  Future<void> _setGoal(int goal) async {
    if (!await ensureSignedIn(context,
        reason: "Su hedefini kaydetmek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _goal = goal);
    _api.setWater(glasses: _glasses, goal: _goal);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final progress = _goal == 0 ? 0.0 : (_glasses / _goal).clamp(0.0, 1.0);
    final ml = _glasses * 250;

    return Scaffold(
      appBar: AppBar(title: const Text("Su Takibi")),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
                    AppSpacing.md, AppSpacing.xxxl),
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: SizedBox(
                      height: 230,
                      width: 230,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            height: 230,
                            width: 230,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 14,
                              backgroundColor: p.info.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation(p.info),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_drink_rounded,
                                  color: p.info, size: 34),
                              const SizedBox(height: 4),
                              Text("$_glasses / $_goal",
                                  style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      height: 1)),
                              Text("bardak • $ml ml",
                                  style: TextStyle(
                                      color: p.textMuted, fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _roundBtn(p, Icons.remove_rounded, () => _change(-1),
                          filled: false),
                      const SizedBox(width: AppSpacing.lg),
                      _roundBtn(p, Icons.add_rounded, () => _change(1),
                          filled: true),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SectionHeader(
                    title: "Günlük hedef",
                    subtitle: "Bir bardak ≈ 250 ml",
                    icon: Icons.flag_rounded,
                  ),
                  AppCard(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final g in const [6, 8, 10, 12])
                          ChoiceChip(
                            label: Text("$g bardak"),
                            selected: _goal == g,
                            onSelected: (_) => _setGoal(g),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (progress >= 1)
                    const InfoBanner(
                      tone: PillTone.success,
                      icon: Icons.celebration_rounded,
                      message: "Bugünkü su hedefini tamamladın! Harikasın 💧",
                    )
                  else
                    const InfoBanner(
                      message:
                          "Gün içine yayarak su iç. İdrar rengi koyulaşıyorsa alımını artır.",
                      icon: Icons.info_outline_rounded,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _roundBtn(AppPalette p, IconData icon, VoidCallback onTap,
      {required bool filled}) {
    return Material(
      color: filled ? null : p.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Ink(
          height: 72,
          width: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled
                ? LinearGradient(
                    colors: [p.info, p.info.withValues(alpha: 0.8)])
                : null,
            color: filled ? null : p.surface,
            border:
                Border.all(color: filled ? Colors.transparent : p.borderSoft),
            boxShadow: filled ? p.glow(p.info, strength: 0.3) : null,
          ),
          child: Icon(icon,
              color: filled ? Colors.white : p.textPrimary, size: 32),
        ),
      ),
    );
  }
}
