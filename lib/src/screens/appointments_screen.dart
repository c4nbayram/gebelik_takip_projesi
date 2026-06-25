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

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );
  final _title = TextEditingController();
  final _notes = TextEditingController();
  DateTime? _selected;
  TimeOfDay? _time;
  List<Appointment> _items = [];
  bool _loading = false;
  bool _notify = true;
  StreamSubscription<List<Appointment>>? _sub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _api.restoreSession();
    if (SupabaseBootstrap.isReady) {
      _sub = _api.appointmentsStream().listen((items) {
        final sorted = [...items]
          ..sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
        if (!mounted) return;
        setState(() => _items = sorted);
      });
    } else {
      await _load();
    }
  }

  Future<void> _load() async {
    try {
      final items = await _api.getAppointments();
      items.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
      if (!mounted) return;
      setState(() => _items = items);
    } catch (_) {}
  }

  Future<void> _add() async {
    if (_title.text.trim().isEmpty || _selected == null || _time == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text("Baslik, tarih ve saat zorunlu."),
            backgroundColor: context.palette.dangerBg,
          ),
        );
      return;
    }
    if (!await ensureSignedIn(context,
        reason: "Randevu eklemek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    final date = DateTime(
      _selected!.year,
      _selected!.month,
      _selected!.day,
      _time!.hour,
      _time!.minute,
    );
    final model = Appointment(
      id: 0,
      title: _title.text.trim(),
      appointmentAt: date,
      notes: _notes.text.trim(),
    );
    setState(() => _loading = true);
    try {
      await _api.addAppointment(model);
      _title.clear();
      _notes.clear();
      _selected = null;
      _time = null;
      await _load();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final pick = await showDatePicker(
      context: context,
      initialDate: _selected ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 720)),
    );
    if (pick != null) setState(() => _selected = pick);
  }

  Future<void> _pickTime() async {
    final pick = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (pick != null) setState(() => _time = pick);
  }

  Future<void> _delete(Appointment a) async {
    await _api.restoreSession();
    await _api.deleteAppointment(a.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate =
        _selected == null ? null : DateFormat("dd.MM.yyyy").format(_selected!);
    final selectedTime = _time?.format(context);
    final next = _items.isEmpty ? null : _items.first;

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
            _nextSummary(next),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Yeni Randevu",
              subtitle: "Doktor kontrolu veya hatirlatici ekle",
              icon: Icons.add_circle_outline_rounded,
            ),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _title,
                    label: "Baslik",
                    hint: "Ornegin: Aylik kontrol",
                    prefixIcon: Icons.title_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _notes,
                    label: "Not",
                    hint: "Klinik adresi, hekim notu vs.",
                    prefixIcon: Icons.notes_rounded,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: AppSelectField(
                          label: "Tarih",
                          value: selectedDate,
                          onTap: _pickDate,
                          placeholder: "Sec",
                          icon: Icons.calendar_month_rounded,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppSelectField(
                          label: "Saat",
                          value: selectedTime,
                          onTap: _pickTime,
                          placeholder: "Sec",
                          icon: Icons.access_time_rounded,
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
                    label: "Randevu Ekle",
                    icon: Icons.event_available_rounded,
                    size: AppButtonSize.large,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: "Yaklasan Randevular",
              subtitle: _items.isEmpty
                  ? "Henuz randevu eklenmedi"
                  : "${_items.length} planli randevu",
              icon: Icons.event_note_rounded,
            ),
            if (_items.isEmpty)
              const EmptyState(
                icon: Icons.event_available_rounded,
                title: "Henuz randevu yok",
                description:
                    "Yukaridaki formdan ilk randevunu ekleyerek takvimine baslayabilirsin.",
              )
            else
              Column(
                children: [
                  for (int i = 0; i < _items.length; i++) ...[
                    _appointmentTile(_items[i]),
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
            Icons.event_rounded,
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
                "Randevular",
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "Doktor ve kontrol takvimini yonet",
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

  Widget _nextSummary(Appointment? next) {
    if (next == null) {
      return GradientHeroCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Planli randevu yok",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Yeni randevu olusturarak takvimini dolduralim.",
                    style: TextStyle(color: Colors.white70, fontSize: 12.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final date = DateFormat("dd MMM yyyy", "tr_TR").format(next.appointmentAt);
    final time = DateFormat("HH:mm").format(next.appointmentAt);
    final days = next.appointmentAt.difference(DateTime.now()).inDays;
    final countdown = days < 0
        ? "Bugun"
        : days == 0
            ? "Bugun"
            : "$days gun sonra";

    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 5),
                    Text(
                      "SONRAKI RANDEVU",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                countdown,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            next.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 6),
              Text(
                "$date  •  $time",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (next.notes != null && next.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              next.notes!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
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
          Icon(Icons.notifications_active_rounded,
              size: 18, color: context.palette.primarySoft),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Hatirlatici",
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  "Randevudan once bildirim gonderir",
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
        ],
      ),
    );
  }

  Widget _appointmentTile(Appointment a) {
    final date = DateFormat("dd MMM", "tr_TR").format(a.appointmentAt);
    final time = DateFormat("HH:mm").format(a.appointmentAt);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 60,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: context.palette.brandGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  date.split(" ").first,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date.split(" ").last.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.title,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 13, color: context.palette.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(
                        color: context.palette.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.notes != null && a.notes!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.notes_rounded,
                          size: 13, color: context.palette.textMuted),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          a.notes!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.palette.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _loading ? null : () => _delete(a),
            icon: Icon(
              Icons.delete_outline_rounded,
              color: context.palette.danger,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
