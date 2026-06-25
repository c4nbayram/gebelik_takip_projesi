import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/guest_guard.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import '../widgets/app_text_field.dart';
import '../widgets/tracking_insight_sections.dart';
import 'analyze_screen.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  final _form = GlobalKey<FormState>();
  final _sistolik = TextEditingController();
  final _diastolik = TextEditingController();
  final _bs = TextEditingController();
  final _temp = TextEditingController();
  final _bmi = TextEditingController();
  final _nabiz = TextEditingController();

  final Map<int, WeekEntry> _entryByWeek = {};
  TrackingInsight? _insight;
  int _selectedWeek = 1;
  bool _loading = false;

  static const String _weekKey = "gebelik_current_week";

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _sistolik.dispose();
    _diastolik.dispose();
    _bs.dispose();
    _temp.dispose();
    _bmi.dispose();
    _nabiz.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _api.restoreSession();
    final prefs = await SharedPreferences.getInstance();
    final storedWeek = prefs.getInt(_weekKey);
    if (storedWeek != null && storedWeek >= 1 && storedWeek <= 40) {
      _selectedWeek = storedWeek;
    }

    await _loadEntries();
    if (_entryByWeek.isNotEmpty) {
      final maxWeek = _entryByWeek.keys.reduce(max);
      _selectedWeek = max(_selectedWeek, maxWeek);
    }
    await _refreshInsight();
    _applyWeekToForm();
    if (mounted) setState(() {});
  }

  Future<void> _loadEntries() async {
    try {
      final entries = await _api.getWeekEntries();
      _entryByWeek
        ..clear()
        ..addEntries(entries.map((e) => MapEntry(e.weekNo, e)));
    } catch (_) {}
  }

  Future<void> _refreshInsight() async {
    try {
      final insight = await _api.buildTrackingInsight(
        selectedWeek: _selectedWeek,
        weekEntries: _entryByWeek.values.toList(),
      );
      if (mounted) {
        setState(() => _insight = insight);
      } else {
        _insight = insight;
      }
    } catch (_) {}
  }

  void _applyWeekToForm() {
    final entry = _entryByWeek[_selectedWeek];
    _sistolik.text = entry?.systolic?.toString() ?? "";
    _diastolik.text = entry?.diastolic?.toString() ?? "";
    _bs.text = entry?.bloodSugar?.toString() ?? "";
    _temp.text = entry?.bodyTemp?.toString() ?? "";
    _bmi.text = entry?.bmi?.toString() ?? "";
    _nabiz.text = entry?.heartRate?.toString() ?? "";
  }

  Future<void> _pickWeek() async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.palette.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.xs,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded,
                        color: context.palette.primarySoft, size: 20),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      "Hafta Sec",
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "${_entryByWeek.length}/40 kayit",
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.palette.borderSoft),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  itemCount: 40,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xxs),
                  itemBuilder: (context, i) {
                    final week = i + 1;
                    final hasData = _entryByWeek.containsKey(week);
                    final isCurrent = week == _selectedWeek;
                    return Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: InkWell(
                        onTap: () => Navigator.pop(context, week),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: isCurrent
                                ? context.palette.primary
                                    .withValues(alpha: 0.12)
                                : context.palette.surface
                                    .withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: isCurrent
                                  ? context.palette.primary
                                      .withValues(alpha: 0.5)
                                  : context.palette.borderSoft,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  gradient: hasData
                                      ? LinearGradient(
                                          colors: context.palette.brandGradient,
                                        )
                                      : null,
                                  color: hasData
                                      ? null
                                      : context.palette.surfaceHigh,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.xs),
                                  border: Border.all(
                                    color: hasData
                                        ? Colors.transparent
                                        : context.palette.borderSoft,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "$week",
                                  style: TextStyle(
                                    color: hasData
                                        ? Colors.white
                                        : context.palette.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "$week. Hafta",
                                      style: TextStyle(
                                        color: context.palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      hasData
                                          ? "Kayit var • duzenlenebilir"
                                          : "Bos",
                                      style: TextStyle(
                                        color: context.palette.textMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                hasData
                                    ? Icons.edit_rounded
                                    : Icons.add_rounded,
                                size: 18,
                                color: hasData
                                    ? context.palette.primarySoft
                                    : context.palette.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weekKey, picked);
    setState(() {
      _selectedWeek = picked;
      _applyWeekToForm();
    });
    await _refreshInsight();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_form.currentState?.validate() ?? false)) return;
    if (!await ensureSignedIn(context,
        reason: "Haftalık ölçümlerini kaydetmek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final ageVal = prefs.getInt(AppConfig.profileAgeKey);
    final medicalVal = prefs.getString(AppConfig.profileMedicalKey);

    final req = HealthAnalyzeRequest(
      weekNo: _selectedWeek,
      profileAge: ageVal,
      medicalHistory: (medicalVal?.isNotEmpty ?? false) ? medicalVal : null,
      systolic: double.parse(_sistolik.text.trim()),
      diastolic: double.parse(_diastolik.text.trim()),
      bloodSugar: double.parse(_bs.text.trim()),
      bodyTemp: double.parse(_temp.text.trim()),
      bmi: double.parse(_bmi.text.trim()),
      heartRate: double.parse(_nabiz.text.trim()),
      update: _entryByWeek.containsKey(_selectedWeek),
    );

    setState(() => _loading = true);
    if (!mounted) return;
    final picked = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnalyzeScreen(
          api: _api,
          request: req,
          selectedWeek: _selectedWeek,
        ),
      ),
    );
    await _loadEntries();
    if (picked is int) {
      _selectedWeek = picked;
    }
    _applyWeekToForm();
    await _refreshInsight();
    if (mounted) setState(() => _loading = false);
  }

  String _weekImagePath(int week) => "assets/week/${week}_hafta.png";

  String? _numValidator(String? v) {
    if (v == null || v.trim().isEmpty) return "Zorunlu alan";
    if (double.tryParse(v.trim()) == null) return "Gecerli sayi girin";
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasEntry = _entryByWeek.containsKey(_selectedWeek);
    final insight = _insight;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xxxl + AppSpacing.xxl,
          ),
          children: [
            _titleBar(),
            const SizedBox(height: AppSpacing.md),
            _weekSelectorCard(hasEntry),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Haftalik Risk Degerlendirmesi",
              subtitle:
                  "Gecmis haftalar ve saglik notlarin birlikte yorumlaniyor",
              icon: Icons.auto_awesome_rounded,
            ),
            if (insight != null)
              TrackingInsightCard(insight: insight)
            else
              AppCard(
                child: Text(
                  "Takip paneli hazirlaniyor...",
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Tum Haftalarin Karsilastirmasi",
              subtitle: "Grafiksel olarak risk ve tum olcum degerleri",
              icon: Icons.stacked_line_chart_rounded,
            ),
            if (insight != null)
              TrackingTrendsCard(insight: insight)
            else
              const SizedBox.shrink(),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Secili Hafta Kiyaslamasi",
              subtitle: "Secili hafta ve onceki kayit arasindaki farklar",
              icon: Icons.compare_arrows_rounded,
            ),
            if (insight != null)
              TrackingComparisonsCard(insight: insight)
            else
              const SizedBox.shrink(),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: "Haftalik Olcumler",
              subtitle: hasEntry
                  ? "Mevcut kaydi duzenliyorsun"
                  : "Bu hafta icin yeni kayit olustur",
              icon: Icons.monitor_heart_rounded,
              trailing: hasEntry
                  ? Icon(
                      Icons.edit_note_rounded,
                      color: context.palette.primarySoft,
                      size: 22,
                    )
                  : null,
            ),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _pairedFields(
                      left: _numField(
                        label: "Sistolik",
                        hint: "mmHg",
                        example: "110",
                        icon: Icons.arrow_upward_rounded,
                        controller: _sistolik,
                      ),
                      right: _numField(
                        label: "Diastolik",
                        hint: "mmHg",
                        example: "70",
                        icon: Icons.arrow_downward_rounded,
                        controller: _diastolik,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _pairedFields(
                      left: _numField(
                        label: "Kan sekeri",
                        hint: "mg/dL",
                        example: "95",
                        icon: Icons.bloodtype_outlined,
                        controller: _bs,
                      ),
                      right: _numField(
                        label: "Vucut sicakligi",
                        hint: "°C",
                        icon: Icons.thermostat_rounded,
                        example: "36.7",
                        controller: _temp,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _pairedFields(
                      left: _numField(
                        label: "BMI",
                        hint: "kg/m²",
                        icon: Icons.scale_rounded,
                        example: "24.1",
                        controller: _bmi,
                      ),
                      right: _numField(
                        label: "Nabiz",
                        hint: "bpm",
                        example: "82",
                        icon: Icons.favorite_rounded,
                        controller: _nabiz,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const InfoBanner(
                      message:
                          "Degerleri eksiksiz gir. Risk hesabi ve rehberlik notlari bu olcumlere gore hazirlanir.",
                      icon: Icons.auto_awesome_rounded,
                      tone: PillTone.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      onPressed: _loading ? null : _submit,
                      loading: _loading,
                      label: hasEntry ? "Analiz Et ve Guncelle" : "Analiz Et",
                      icon: Icons.auto_awesome_rounded,
                      size: AppButtonSize.large,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBar() {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: context.palette.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: context.palette.borderSoft),
          ),
          child: Icon(
            Icons.monitor_heart_rounded,
            color: context.palette.primarySoft,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Haftalik Takip",
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Olcumlerini gir, risk degerlendirmesi ve rehberlik notu al",
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekSelectorCard(bool hasEntry) {
    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: _pickWeek,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Row(
              children: [
                Container(
                  height: 64,
                  width: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _weekImagePath(_selectedWeek),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.child_friendly_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          hasEntry ? "MEVCUT KAYIT" : "YENI KAYIT",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        "$_selectedWeek. Hafta",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasEntry
                            ? "Kayitli degerleri duzenle"
                            : "Yeni hafta kaydi olustur",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pairedFields({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 390) {
          return Column(
            children: [
              left,
              const SizedBox(height: AppSpacing.sm),
              right,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _numField({
    required String label,
    required String hint,
    required String example,
    required IconData icon,
    required TextEditingController controller,
  }) {
    return AppTextField(
      controller: controller,
      label: label,
      hint: hint,
      helperText: "Ornek: $example",
      prefixIcon: icon,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _numValidator,
    );
  }
}
