import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/week_size.dart';
import '../models/app_models.dart';
import '../providers/premium_provider.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import 'membership_screen.dart';
import 'notifications_screen.dart';
import 'red_flag_screen.dart';
import 'tools/journal_screen.dart';
import 'tools/kick_counter_screen.dart';
import 'tools/water_screen.dart';
import 'tools/weight_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  late Future<void> _init;
  late final Stream<int> _unreadStream = _api.unreadCountStream();
  int _selectedWeek = 1;
  WeekInfo? _weekInfo;
  List<WeekEntry> _entries = [];
  String _caregiverRole = "";
  String _babyName = "";
  bool _planningBaby = false;
  DateTime? _lastPeriod;
  DateTime? _dueDate;
  Appointment? _nextAppointment;
  List<Medication> _meds = [];

  @override
  void initState() {
    super.initState();
    _init = _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowConsent());
  }

  static const String _consentText = "Gebelik Takip'i kullanmadan önce:\n\n"
      "• Tıbbi uyarı: Bu uygulama bilgilendirme amaçlıdır; tıbbi teşhis veya tedavi aracı değildir. Risk analizi ve öneriler doktor muayenesinin yerini tutmaz. Acil bir durumda en yakın sağlık kuruluşuna başvur.\n\n"
      "• KVKK / veri kullanımı: Girdiğin kişisel ve sağlık verileri (ad, e-posta, ölçümler, sağlık notların) yalnızca sana hizmet sunmak için güvenli şekilde işlenir ve hesabına bağlı tutulur. Verilerin pazarlama amacıyla üçüncü taraflarla paylaşılmaz. İstediğin zaman Profil → Ayarlar'dan veri silme talebinde bulunabilirsin.\n\n"
      "Devam ederek bu koşulları okuduğunu ve onayladığını kabul edersin.";

  Future<void> _maybeShowConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool("gebelik_consent_v1") ?? false) return;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.palette.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetCtx) {
        final p = sheetCtx.palette;
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: p.brandGradient),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.verified_user_rounded,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text("Onay ve Bilgilendirme",
                        style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetCtx).size.height * 0.5),
                child: SingleChildScrollView(
                  child: Text(
                    _consentText,
                    style: TextStyle(
                        color: p.textSecondary, fontSize: 13.5, height: 1.55),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool("gebelik_consent_v1", true);
                  await _api.acceptConsent("v1");
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
                label: "Okudum, onaylıyorum",
                icon: Icons.check_rounded,
                size: AppButtonSize.large,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    await _api.restoreSession();
    final prefs = await SharedPreferences.getInstance();
    _caregiverRole = prefs.getString(AppConfig.caregiverRoleKey) ?? "";
    _babyName = prefs.getString(AppConfig.babyNameKey) ?? "";
    _planningBaby = prefs.getBool(AppConfig.planningBabyKey) ?? false;

    final lpMs = prefs.getInt(AppConfig.lastPeriodStartKey);
    final dueMs = prefs.getInt(AppConfig.estimatedDueDateKey);
    _lastPeriod =
        lpMs != null ? DateTime.fromMillisecondsSinceEpoch(lpMs) : null;
    _dueDate =
        dueMs != null ? DateTime.fromMillisecondsSinceEpoch(dueMs) : null;
    final autoWeek = _computeGestWeek();
    if (autoWeek != null) _selectedWeek = autoWeek;

    try {
      _weekInfo = await _api.getWeekInfo(_selectedWeek);
      _entries = await _api.getWeekEntries();
      final appts = await _api.getAppointments();
      appts.sort((a, b) => a.appointmentAt.compareTo(b.appointmentAt));
      final now = DateTime.now();
      Appointment? next;
      for (final a in appts) {
        if (a.appointmentAt.isAfter(now)) {
          next = a;
          break;
        }
      }
      _nextAppointment = next;
      _meds = await _api.getMedications();
    } catch (_) {}

    try {
      await NotificationService.instance.attach(_api);
    } catch (_) {}
  }

  int? _computeGestWeek() {
    if (_lastPeriod != null) {
      final days = DateTime.now().difference(_lastPeriod!).inDays;
      if (days < 0) return null;
      return ((days ~/ 7) + 1).clamp(1, 42);
    }
    if (_dueDate != null) {
      final daysToDue = _dueDate!.difference(DateTime.now()).inDays;
      return (40 - (daysToDue / 7).ceil()).clamp(1, 42);
    }
    return null;
  }

  int? get _daysToDue => _dueDate?.difference(DateTime.now()).inDays;

  Future<void> _reload() async => setState(() => _init = _load());

  String _roleTag() {
    final raw = _caregiverRole.trim();
    if (raw.isEmpty) return "Aile";
    const map = {
      "Annesiyim": "Anne",
      "Babasiyim": "Baba",
      "Abisiyim": "Abi",
      "Halasiyim": "Hala",
      "Babannesiyim": "Babaanne",
      "Teyzesiyim": "Teyze",
    };
    return map[raw] ?? raw;
  }

  String _babyPossessive() {
    final name = _babyName.trim();
    return name.isEmpty ? "Bebeğinizin" : "$name'in";
  }

  String _weekImagePath(int week) => "assets/week/${week}_hafta.png";

  PillTone _riskTone(String? label) {
    final l = (label ?? "").toLowerCase();
    if (l.contains("high") || l.contains("yuksek")) return PillTone.danger;
    if (l.contains("mid") || l.contains("orta")) return PillTone.warning;
    if (l.contains("low") || l.contains("dusuk")) return PillTone.success;
    return PillTone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<void>(
          future: _init,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState == ConnectionState.waiting;
            return RefreshIndicator(
              color: p.primary,
              backgroundColor: p.surface,
              onRefresh: _reload,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
                children: [
                  _header(p),
                  const SizedBox(height: AppSpacing.md),
                  if (loading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: p.surfaceHigh,
                        color: p.primary,
                      ),
                    ),
                  _heroCard(p),
                  const SizedBox(height: AppSpacing.lg),
                  _quickActions(p),
                  const SizedBox(height: AppSpacing.sm),
                  _redFlagBanner(p),
                  if (!context.watch<PremiumProvider>().isPremium) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _premiumCta(p),
                  ],
                  ..._remindersChildren(p),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: "${_babyPossessive()} bu haftası",
                    subtitle: "$_selectedWeek. hafta gelişimi",
                    icon: Icons.eco_rounded,
                  ),
                  AppCard(
                    child: Text(
                      _weekInfo?.text.isNotEmpty == true
                          ? _weekInfo!.text
                          : "Bebek gelişim bilgisi yükleniyor...",
                      style: TextStyle(
                          color: p.textSecondary, fontSize: 13.5, height: 1.55),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SectionHeader(
                    title: "Son ölçümler",
                    subtitle: _entries.isEmpty
                        ? "Henüz ölçüm yok"
                        : "${_entries.length} hafta kaydı",
                    icon: Icons.history_rounded,
                  ),
                  _entriesList(p),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header(AppPalette p) {
    final theme = context.watch<ThemeController>();
    final greeting = _babyName.trim().isEmpty
        ? "Hoş geldin"
        : "${_babyPossessive()} günlüğü";
    return Row(
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: p.brandGradient),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: p.glow(p.primary, strength: 0.25),
          ),
          child:
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Merhaba, ${_roleTag()}",
                  style: TextStyle(color: p.textMuted, fontSize: 12.5)),
              Text(greeting,
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        _bell(p),
        const SizedBox(width: AppSpacing.xs),
        _iconChip(
          p,
          theme.mode == ThemeMode.dark
              ? Icons.dark_mode_rounded
              : theme.mode == ThemeMode.light
                  ? Icons.light_mode_rounded
                  : Icons.brightness_auto_rounded,
          () => theme.cycle(),
        ),
      ],
    );
  }

  Widget _bell(AppPalette p) {
    return StreamBuilder<int>(
      stream: _unreadStream,
      builder: (context, snapshot) {
        final unread = snapshot.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _iconChip(p, Icons.notifications_rounded, () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
            }),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints:
                      const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: p.danger,
                    shape: unread > 9 ? BoxShape.rectangle : BoxShape.circle,
                    borderRadius: unread > 9 ? BorderRadius.circular(9) : null,
                    border: Border.all(color: p.bgBase, width: 1.5),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 9 ? "9+" : "$unread",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _iconChip(AppPalette p, IconData icon, VoidCallback onTap) {
    return Material(
      color: p.surface,
      shape: CircleBorder(side: BorderSide(color: p.borderSoft)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: p.primary),
        ),
      ),
    );
  }

  Widget _heroCard(AppPalette p) {
    final progress = (_selectedWeek / 40).clamp(0.0, 1.0);
    return GradientHeroCard(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 560;
          final image = _WeekImage(
            path: _weekImagePath(_selectedWeek),
            size: wide ? 188 : 156,
          );
          final details = Column(
            crossAxisAlignment:
                wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Text(
                  _planningBaby ? "PLANLAMA" : "AKTİF TAKİP",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _planningBaby ? "Planlama süreci" : "$_selectedWeek. Hafta",
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _planningBaby
                    ? "Gebelik başladığında tarih ekleyip haftalık takibe geçebilirsin."
                    : (_daysToDue == null
                        ? "Tahmini doğum tarihi eklenmedi."
                        : (_daysToDue! >= 0
                            ? "Doğuma $_daysToDue gün kaldı."
                            : "Tahmini doğum tarihi geçti.")),
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontSize: 13.5,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_planningBaby) ...[
                const SizedBox(height: AppSpacing.sm),
                _sizeChip(),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text(
                      "Yolculuk",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      "%${(progress * 100).toInt()}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            ],
          );

          return Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: wide
                ? Row(
                    children: [
                      image,
                      const SizedBox(width: AppSpacing.xl),
                      Expanded(child: details),
                    ],
                  )
                : Column(
                    children: [
                      image,
                      const SizedBox(height: AppSpacing.lg),
                      details,
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _redFlagBanner(AppPalette p) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderColor: p.danger.withValues(alpha: 0.35),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const RedFlagScreen())),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: p.dangerBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(Icons.emergency_rounded, color: p.danger, size: 22),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Acil belirtiler",
                    style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                Text("Ne zaman doktora başvurmalısın?",
                    style: TextStyle(color: p.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: p.textMuted, size: 20),
        ],
      ),
    );
  }

  Widget _sizeChip() {
    final s = weekSizeFor(_selectedWeek);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        "${s.emoji} Bu hafta ${s.fruit} kadar · ${s.size}",
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _premiumCta(AppPalette p) {
    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.workspace_premium_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Premium'a geç",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  "Gebelik rehberi, detaylı değerlendirme ve uzman içeriklerini aç.",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MembershipScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Text(
                  "İncele",
                  style: TextStyle(
                    color: p.primaryDeep,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(AppPalette p) {
    final actions = [
      (_QA(
          Icons.touch_app_rounded,
          "Tekme",
          const [Color(0xFF8C7BFF), Color(0xFF6F5AE0)],
          (_) => const KickCounterScreen())),
      (_QA(
          Icons.local_drink_rounded,
          "Su",
          const [Color(0xFF5B8DEF), Color(0xFF4F86E8)],
          (_) => const WaterScreen())),
      (_QA(
          Icons.monitor_weight_rounded,
          "Kilo",
          const [Color(0xFF36C39A), Color(0xFF1FB68A)],
          (_) => const WeightScreen())),
      (_QA(
          Icons.auto_stories_rounded,
          "Günlük",
          const [Color(0xFFF0A93D), Color(0xFFE2912F)],
          (_) => const JournalScreen())),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, i) => _quickActionCard(p, actions[i]),
    );
  }

  Widget _quickActionCard(AppPalette p, _QA qa) {
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: qa.builder)),
        child: Ink(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: p.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: qa.gradient),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(qa.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    qa.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _remindersChildren(AppPalette p) {
    final hasAppt = _nextAppointment != null;
    final medCount = _meds.length;
    if (!hasAppt && medCount == 0) return const [];
    return [
      const SizedBox(height: AppSpacing.lg),
      const SectionHeader(
        title: "Yaklaşan hatırlatıcılar",
        subtitle: "Randevu ve ilaç takibin",
        icon: Icons.notifications_active_rounded,
      ),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasAppt)
              _reminderRow(p, Icons.event_rounded, _nextAppointment!.title,
                  _appointmentSubtitle(_nextAppointment!)),
            if (hasAppt && medCount > 0)
              Divider(height: AppSpacing.md, color: p.borderSoft),
            if (medCount > 0)
              _reminderRow(p, Icons.medication_rounded,
                  "$medCount ilaç takipte", _medsSubtitle()),
          ],
        ),
      ),
    ];
  }

  String _appointmentSubtitle(Appointment a) {
    final date =
        DateFormat("dd MMM yyyy • HH:mm", "tr_TR").format(a.appointmentAt);
    final days = a.appointmentAt.difference(DateTime.now()).inDays;
    return "$date (${days <= 0 ? "bugün" : "$days gün sonra"})";
  }

  String _medsSubtitle() {
    final names =
        _meds.map((m) => m.name).where((n) => n.isNotEmpty).take(3).toList();
    if (names.isEmpty) return "İlaç listesi güncel";
    final extra =
        _meds.length > names.length ? " +${_meds.length - names.length}" : "";
    return "${names.join(", ")}$extra";
  }

  Widget _reminderRow(
      AppPalette p, IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: p.primaryBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: p.primary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.textMuted, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _entriesList(AppPalette p) {
    if (_entries.isEmpty) {
      return const EmptyState(
        icon: Icons.stacked_line_chart_rounded,
        title: "Henüz ölçüm kaydı yok",
        description:
            "Takip ekranında haftalık değerlerini girerek geçmişini burada takip edebilirsin.",
      );
    }
    final recent = _entries.reversed.take(4).toList();
    return Column(
      children: [
        for (final e in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: AppCard(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: p.brandGradient),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    alignment: Alignment.center,
                    child: Text("${e.weekNo}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("${e.weekNo}. hafta",
                            style: TextStyle(
                                color: p.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5)),
                        Text(
                          e.updatedAt == null
                              ? "-"
                              : "Güncelleme: ${DateFormat("dd.MM.yyyy").format(e.updatedAt!)}",
                          style: TextStyle(color: p.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (e.riskLabel != null)
                    StatPill(
                      label: "",
                      value:
                          "${e.riskLabel} ${((e.riskScore ?? 0) * 100).toInt()}%",
                      tone: _riskTone(e.riskLabel),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekImage extends StatelessWidget {
  const _WeekImage({required this.path, required this.size});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.32),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.child_friendly_rounded,
            color: Colors.white,
            size: 44,
          ),
        ),
      ),
    );
  }
}

class _QA {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final WidgetBuilder builder;
  const _QA(this.icon, this.label, this.gradient, this.builder);
}
