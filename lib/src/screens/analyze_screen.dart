import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import 'analysis_result_screen.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({
    super.key,
    required this.api,
    required this.request,
    required this.selectedWeek,
  });

  final ApiService api;
  final HealthAnalyzeRequest request;
  final int selectedWeek;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen>
    with SingleTickerProviderStateMixin {
  String? _error;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _run();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() => _error = null);
    try {
      final result = await widget.api.analyzeWeek(widget.request);
      final entries = await widget.api.getWeekEntries();
      final insight = await widget.api.buildTrackingInsight(
        selectedWeek: widget.selectedWeek,
        weekEntries: entries,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AnalysisResultScreen(
            result: result,
            insight: insight,
            weekEntries: entries,
            selectedWeek: widget.selectedWeek,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analiz Ediliyor"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: _error == null ? _loadingState() : _errorState(),
          ),
        ),
      ),
    );
  }

  Widget _loadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 160 + (t * 20),
                  width: 160 + (t * 20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.palette.primary.withValues(alpha: 0.08),
                  ),
                ),
                Container(
                  height: 120 + (t * 12),
                  width: 120 + (t * 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.palette.primary.withValues(alpha: 0.12),
                  ),
                ),
                Container(
                  height: 92,
                  width: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: context.palette.brandGradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: AppShadows.glow(context.palette.primary,
                        strength: 0.45),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          "Veriler analiz ediliyor",
          style: TextStyle(
            color: context.palette.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          "Risk hesabi ve kisisel rehberlik notlari hazirlaniyor...",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: context.palette.textMuted,
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: 220,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 4,
              backgroundColor: context.palette.surface,
              color: context.palette.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: context.palette.dangerBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: context.palette.danger.withValues(alpha: 0.45),
              ),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: context.palette.danger,
              size: 32,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Analiz tamamlanamadi",
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? "Bilinmeyen bir hata olustu",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  onPressed: () => Navigator.pop(context),
                  label: "Geri Don",
                  icon: Icons.arrow_back_rounded,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: PrimaryButton(
                  onPressed: _run,
                  label: "Tekrar Dene",
                  icon: Icons.refresh_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
