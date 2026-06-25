import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_config.dart';
import '../core/guest_guard.dart';
import '../models/app_models.dart';
import '../services/api_service.dart';
import '../services/supabase_client.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import '../widgets/app_text_field.dart';

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key});

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  final _name = TextEditingController();
  final _dosage = TextEditingController();
  final _frequency = TextEditingController();
  final _times = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _start;
  DateTime? _end;

  List<Medication> _items = [];
  bool _loading = false;
  bool _reminder = true;
  StreamSubscription<List<Medication>>? _sub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _name.dispose();
    _dosage.dispose();
    _frequency.dispose();
    _times.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _api.restoreSession();
    if (SupabaseBootstrap.isReady) {
      _sub = _api.medicationsStream().listen((items) {
        if (!mounted) return;
        setState(() => _items = items);
      });
    } else {
      await _load();
    }
  }

  Future<void> _load() async {
    try {
      final items = await _api.getMedications();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {}
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text("Ilac adi zorunlu."),
            backgroundColor: context.palette.dangerBg,
          ),
        );
      return;
    }
    if (!await ensureSignedIn(context,
        reason: "İlaç eklemek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await _api.addMedication(
        name: _name.text.trim(),
        dosage: _dosage.text.trim(),
        frequency: _frequency.text.trim(),
        startDate: _start,
        endDate: _end,
        times: _times.text.trim(),
        notes: _notes.text.trim(),
      );
      _name.clear();
      _dosage.clear();
      _frequency.clear();
      _times.clear();
      _notes.clear();
      _start = null;
      _end = null;
      await _load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStart() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 720)),
    );
    if (pick != null) setState(() => _start = pick);
  }

  Future<void> _pickEnd() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: _end ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 720)),
    );
    if (pick != null) setState(() => _end = pick);
  }

  Future<void> _delete(Medication m) async {
    await _api.restoreSession();
    await _api.deleteMedication(m.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final startText =
        _start == null ? null : DateFormat("dd.MM.yyyy").format(_start!);
    final endText =
        _end == null ? null : DateFormat("dd.MM.yyyy").format(_end!);

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
            _summaryHero(),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Yeni Ilac",
              subtitle: "Tedavine yeni bir ilac ekle",
              icon: Icons.add_circle_outline_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _name,
                    label: "Ilac adi",
                    hint: "Ornegin: Folik Asit",
                    prefixIcon: Icons.medication_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _dosage,
                          label: "Doz",
                          hint: "500 mg",
                          prefixIcon: Icons.science_outlined,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppTextField(
                          controller: _frequency,
                          label: "Siklik",
                          hint: "Gunde 1",
                          prefixIcon: Icons.repeat_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _times,
                    label: "Saatler",
                    hint: "09:00, 21:00",
                    prefixIcon: Icons.access_time_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _notes,
                    label: "Not",
                    hint: "Ek bilgi veya uyari",
                    prefixIcon: Icons.notes_rounded,
                    minLines: 2,
                    maxLines: 3,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppSelectField(
                          label: "Baslangic",
                          value: startText,
                          onTap: _pickStart,
                          icon: Icons.play_arrow_rounded,
                          placeholder: "Sec",
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppSelectField(
                          label: "Bitis",
                          value: endText,
                          onTap: _pickEnd,
                          icon: Icons.stop_rounded,
                          placeholder: "Sec",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _reminderToggle(),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    onPressed: _loading ? null : _add,
                    loading: _loading,
                    label: "Ilac Ekle",
                    icon: Icons.check_rounded,
                    size: AppButtonSize.large,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: "Ilac Listesi",
              subtitle: _items.isEmpty
                  ? "Henuz ilac eklenmedi"
                  : "${_items.length} kayitli ilac",
              icon: Icons.local_pharmacy_rounded,
            ),
            if (_items.isEmpty)
              const EmptyState(
                icon: Icons.medication_outlined,
                title: "Henuz ilac kaydi yok",
                description:
                    "Yukaridaki formdan ilac eklemeye baslayabilirsin. Hatirlaticilar sayesinde dozlari atlamadan alabilirsin.",
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    _medicationTile(_items[i]),
                    if (i != _items.length - 1)
                      const SizedBox(height: AppSpacing.xs),
                  ],
                ],
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
            Icons.medication_liquid_rounded,
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
                "Ilaclarim",
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Aktif tedavini ve hatirlaticilari yonet",
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

  Widget _summaryHero() {
    final count = _items.length;
    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Ilac Ozeti",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 0
                      ? "Aktif ilac bulunmuyor"
                      : "$count aktif ilac takibi",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              "$count",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reminderToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.palette.bgElevated.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.alarm_on_rounded,
              size: 18, color: context.palette.primarySoft),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Ilac hatirlatici",
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Secilen saatlerde bildirim gonderir",
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _reminder,
            onChanged: (v) => setState(() => _reminder = v),
          ),
        ],
      ),
    );
  }

  Widget _medicationTile(Medication m) {
    final dosage = (m.dosage ?? "").trim();
    final freq = (m.frequency ?? "").trim();
    final sub = <String>[];
    if (dosage.isNotEmpty) sub.add(dosage);
    if (freq.isNotEmpty) sub.add(freq);
    final subText = sub.isEmpty ? "Detay eklenmedi" : sub.join(" • ");
    final times = m.times.where((t) => t.trim().isNotEmpty).toList();

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: context.palette.accentGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.medication_rounded,
                  color: Colors.white,
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
                      m.name,
                      style: TextStyle(
                        color: context.palette.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subText,
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _delete(m),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: context.palette.danger,
                  size: 20,
                ),
              ),
            ],
          ),
          if (times.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in times)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: context.palette.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                        color: context.palette.primary.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 12, color: context.palette.primarySoft),
                        const SizedBox(width: 4),
                        Text(
                          t,
                          style: TextStyle(
                            color: context.palette.primarySoft,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
