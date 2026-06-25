import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/entry_flow_signal.dart';
import '../core/setup_options.dart';
import '../providers/auth_provider.dart';
import '../providers/premium_provider.dart';
import '../services/api_service.dart';
import 'membership_screen.dart';
import 'premium_content_screen.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import '../widgets/app_text_field.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService(
    baseUrl: AppConfig.apiBaseUrl,
    localOnly: AppConfig.localOnly,
  );

  String _name = "";
  int? _age;
  String _medical = "";

  String _setupRole = SetupOptions.caregiverRoles.first;
  String _setupBabyName = "";
  String _setupCity = "";
  bool _setupPlanningBaby = false;
  String _maternalChronic = "";

  bool _loggingOut = false;

  bool get _isMother => _setupRole == SetupOptions.motherRole;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final storedRole = prefs.getString(AppConfig.caregiverRoleKey);
    final storedCity = prefs.getString(AppConfig.babyCityKey);

    _name = prefs.getString(AppConfig.profileNameKey) ?? "";
    _age = prefs.getInt(AppConfig.profileAgeKey);
    _medical = prefs.getString(AppConfig.profileMedicalKey) ?? "";
    _setupRole = SetupOptions.caregiverRoles.contains(storedRole)
        ? storedRole!
        : SetupOptions.caregiverRoles.first;
    _setupBabyName = prefs.getString(AppConfig.babyNameKey) ?? "";
    _setupCity =
        SetupOptions.turkishCities.contains(storedCity) ? storedCity! : "";
    _setupPlanningBaby = prefs.getBool(AppConfig.planningBabyKey) ?? false;
    _maternalChronic = prefs.getString(AppConfig.maternalChronicKey) ?? "";

    if (mounted) setState(() {});
  }

  double _completionRatio() {
    var filled = 0;
    if (_name.trim().isNotEmpty) filled += 1;
    if ((_age ?? 0) > 0) filled += 1;
    if (_setupBabyName.trim().isNotEmpty) filled += 1;
    if (_setupCity.trim().isNotEmpty) filled += 1;
    return filled / 4;
  }

  String _roleTag() {
    const map = {
      "Annesiyim": "Anne",
      "Babasiyim": "Baba",
      "Abisiyim": "Abi",
      "Halasiyim": "Hala",
      "Babannesiyim": "Babaanne",
      "Teyzesiyim": "Teyze",
    };
    return map[_setupRole] ?? _setupRole;
  }

  @override
  Widget build(BuildContext context) {
    final completionLabel = "%${(_completionRatio() * 100).round()} tamamlandi";

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _titleBar(),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: _tabs(),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _profileTab(completionLabel),
                    _membershipTab(),
                    _settingsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titleBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
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
              Icons.person_rounded,
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
                  "Profil",
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Hesap ve uygulama ayarlari",
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
      ),
    );
  }

  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: TabBar(
        indicator: BoxDecoration(
          gradient: LinearGradient(colors: context.palette.brandGradient),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.glow(context.palette.primary, strength: 0.25),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: context.palette.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13.5,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
        ),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: const [
          Tab(text: "Profil"),
          Tab(text: "Üyelik"),
          Tab(text: "Ayarlar"),
        ],
      ),
    );
  }

  Widget _membershipTab() {
    final premium = context.watch<PremiumProvider>();
    final p = context.palette;
    final isPremium = premium.isPremium;
    final sub = premium.subscription;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl + AppSpacing.xxl,
      ),
      children: [
        GradientHeroCard(
          gradient: isPremium ? null : p.heroGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28)),
                    ),
                    child: Icon(
                      isPremium
                          ? Icons.workspace_premium_rounded
                          : Icons.lock_open_rounded,
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
                        Text(
                          isPremium ? "Premium üyelik aktif" : "Ücretsiz plan",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPremium
                              ? (sub?.planName ?? "Premium")
                              : "Gebelik Rehberi, detaylı değerlendirme ve premium içerik kilitli",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: "Üyelik",
          subtitle: "Paketler ve premium içerik",
          icon: Icons.workspace_premium_outlined,
        ),
        _actionTile(
          icon: Icons.workspace_premium_rounded,
          title: isPremium ? "Planı Yönet" : "Üyelik Paketleri",
          subtitle: isPremium
              ? "Mevcut planını gör ve yükselt"
              : "Detaylı değerlendirme ve ekstra içerik için paket seç",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MembershipScreen()),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.menu_book_rounded,
          title: "Premium İçerik",
          subtitle: "Uzman rehberleri ve özel içerikler",
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PremiumContentScreen()),
          ),
        ),
      ],
    );
  }

  Widget _profileTab(String completionLabel) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl + AppSpacing.xxl,
      ),
      children: [
        _heroHeader(completionLabel),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: "Profil Ozeti",
          subtitle: "Aktif bilgilerin",
          icon: Icons.badge_outlined,
        ),
        AppCard(child: _summaryWrap()),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: "Durum",
          subtitle: "Bebek ve saglik durumu",
          icon: Icons.insights_rounded,
        ),
        Row(
          children: [
            Expanded(
              child: _statusCard(
                icon: Icons.favorite_rounded,
                title:
                    _setupBabyName.isEmpty ? "Bebek profili" : _setupBabyName,
                subtitle:
                    _setupPlanningBaby ? "Planlama sureci" : "Aktif takip",
                accent: context.palette.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _statusCard(
                icon: Icons.health_and_safety_rounded,
                title: "Saglik",
                subtitle: _medical.isEmpty ? "Bilgi yok" : "Bilgi mevcut",
                accent: context.palette.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _themeSelector() {
    final p = context.palette;
    final theme = context.watch<ThemeController>();

    Widget seg(String label, IconData icon, ThemeMode mode) {
      final selected = theme.mode == mode;
      return Expanded(
        child: GestureDetector(
          onTap: () => context.read<ThemeController>().setMode(mode),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient:
                  selected ? LinearGradient(colors: p.brandGradient) : null,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: selected ? p.glow(p.primary, strength: 0.22) : null,
            ),
            child: Column(
              children: [
                Icon(icon,
                    size: 20, color: selected ? Colors.white : p.textMuted),
                const SizedBox(height: 4),
                Text(label,
                    style: TextStyle(
                        color: selected ? Colors.white : p.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: "Görünüm",
          subtitle: "Açık, koyu veya sistem teması",
          icon: Icons.palette_outlined,
        ),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: p.borderSoft),
          ),
          child: Row(
            children: [
              seg("Açık", Icons.light_mode_rounded, ThemeMode.light),
              seg("Koyu", Icons.dark_mode_rounded, ThemeMode.dark),
              seg("Sistem", Icons.brightness_auto_rounded, ThemeMode.system),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingsTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xxxl + AppSpacing.xxl,
      ),
      children: [
        _themeSelector(),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: "Hesap",
          subtitle: "Profil ve saglik bilgilerini duzenle",
          icon: Icons.manage_accounts_rounded,
        ),
        _actionTile(
          icon: Icons.person_outline_rounded,
          title: "Profil ve Kullanici Bilgileri",
          subtitle: "Isim, yas, rol, bebek adi ve sehir duzenle",
          onTap: _showUserAndProfileEditor,
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.health_and_safety_outlined,
          title: "Saglik Bilgileri",
          subtitle: "Saglik gecmisi ve anneye ozel saglik notlari",
          onTap: _showHealthEditor,
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.lock_outline_rounded,
          title: "Sifre Degisikligi",
          subtitle: "Hesap sifreni guncelle",
          onTap: _showPasswordEditor,
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.delete_forever_outlined,
          title: "Verilerimi Sil (KVKK)",
          subtitle: "Hesap ve veri silme talebi oluştur",
          onTap: _requestDataDeletion,
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: "Destek ve Bilgi",
          subtitle: "Yardim ve uygulama detaylari",
          icon: Icons.help_outline_rounded,
        ),
        _actionTile(
          icon: Icons.support_agent_rounded,
          title: "Destek",
          subtitle: "İletişim formu — ekibe doğrudan ulaş",
          onTap: _showSupportForm,
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.question_answer_outlined,
          title: "Sık Sorulan Sorular",
          subtitle: "Kullanım, risk analizi ve premium",
          onTap: () => _showInfo("Sık Sorulan Sorular", _faqText),
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.privacy_tip_outlined,
          title: "Gizlilik ve Güvenlik",
          subtitle: "Verilerin nasıl tutulur ve korunur",
          onTap: () => _showInfo("Gizlilik ve Güvenlik", _privacyText),
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.info_outline_rounded,
          title: "Uygulama Hakkında",
          subtitle: "Gebelik Takip — özellikler ve amaç",
          onTap: () => _showInfo("Uygulama Hakkında", _aboutText),
        ),
        const SizedBox(height: AppSpacing.xs),
        _actionTile(
          icon: Icons.new_releases_outlined,
          title: "Surum",
          subtitle: "v1.0.0",
          onTap: () => _showInfo("Surum Bilgisi", "Surum: v1.0.0"),
          trailingLabel: "v1.0.0",
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionHeader(
          title: "Oturum",
          subtitle: "Hesap ve giris akisi islemleri",
          icon: Icons.power_settings_new_rounded,
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              SecondaryButton(
                onPressed: () async {
                  await _restartEntryFlow();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Ilk giris akisi yeniden etkinlestirildi.",
                      ),
                    ),
                  );
                },
                label: "Ilk Giris Ekranlarini Ac",
                icon: Icons.refresh_rounded,
              ),
              const SizedBox(height: AppSpacing.xs),
              SecondaryButton(
                onPressed: _loggingOut ? null : _logout,
                label: _loggingOut ? "Cikis yapiliyor..." : "Cikis Yap",
                icon: Icons.logout_rounded,
                foregroundColor: context.palette.danger,
                borderColor: context.palette.danger.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroHeader(String completionLabel) {
    return GradientHeroCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.32),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _initials(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
                        horizontal: AppSpacing.xs,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Text(
                        "${_roleTag().toUpperCase()} PROFILI",
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
                      _name.isEmpty ? "Profilini olustur" : _name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _setupPlanningBaby
                          ? "Bebek planlama modu"
                          : "Aktif gebelik takibi",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: InkWell(
                  onTap: _showUserAndProfileEditor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text(
                "Profil tamamlanmasi",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Text(
                completionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: Colors.white.withValues(alpha: 0.14),
                ),
                FractionallySizedBox(
                  widthFactor: _completionRatio().clamp(0.0, 1.0),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFC1D8), Colors.white],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials() {
    final parts = _name.trim().split(RegExp(r"\s+")).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return "?";
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : "";
    return (first + last).toUpperCase();
  }

  Widget _summaryWrap() {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        StatPill(
          label: "Rol",
          value: _setupRole,
          icon: Icons.person_outline_rounded,
          tone: PillTone.primary,
        ),
        StatPill(
          label: "Bebek",
          value: _setupBabyName.isEmpty ? "-" : _setupBabyName,
          icon: Icons.child_care_rounded,
          tone: PillTone.accent,
        ),
        StatPill(
          label: "Sehir",
          value: _setupCity.isEmpty ? "-" : _setupCity,
          icon: Icons.location_on_outlined,
          tone: PillTone.neutral,
        ),
        StatPill(
          label: "Mod",
          value: _setupPlanningBaby ? "Planlama" : "Takip",
          icon: Icons.calendar_month_rounded,
          tone: PillTone.neutral,
        ),
        StatPill(
          label: "Yas",
          value: _age == null ? "-" : "$_age",
          icon: Icons.cake_outlined,
          tone: PillTone.neutral,
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? trailingLabel,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: context.palette.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(color: context.palette.borderSoft),
            ),
            child: Icon(icon, color: context.palette.primarySoft, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.palette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: context.palette.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (trailingLabel != null) ...[
            Text(
              trailingLabel,
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Icon(
            Icons.chevron_right_rounded,
            color: context.palette.textMuted,
            size: 20,
          ),
        ],
      ),
    );
  }

  Future<void> _showUserAndProfileEditor() async {
    final nameController = TextEditingController(text: _name);
    final ageController = TextEditingController(text: _age?.toString() ?? "");
    final babyNameController = TextEditingController(text: _setupBabyName);
    var selectedRole = _setupRole;
    var selectedCity = _setupCity.isEmpty ? null : _setupCity;
    var planning = _setupPlanningBaby;
    var saving = false;
    final messenger = ScaffoldMessenger.of(context);

    await _showThemedSheet(
      title: "Profil ve Kullanici Bilgileri",
      icon: Icons.person_outline_rounded,
      builder: (sheetContext, setInner) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: nameController,
              label: "Isim",
              prefixIcon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: ageController,
              label: "Yas",
              prefixIcon: Icons.cake_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            _dropdownBlock(
              label: "Rol",
              value: selectedRole,
              items: SetupOptions.caregiverRoles,
              onChanged: (v) {
                if (v != null) setInner(() => selectedRole = v);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: babyNameController,
              label: "Bebeginizin Adi",
              prefixIcon: Icons.child_care_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            _dropdownBlock(
              label: "Yasadiginiz Sehir",
              value: selectedCity,
              items: SetupOptions.turkishCities,
              onChanged: (v) => setInner(() => selectedCity = v),
              hint: "Sec",
            ),
            const SizedBox(height: AppSpacing.sm),
            _switchTile(
              label: "Hamile degilim, bebek planliyorum",
              value: planning,
              onChanged: (v) => setInner(() => planning = v),
            ),
            const SizedBox(height: AppSpacing.md),
            _sheetActions(
              onCancel: saving ? null : () => Navigator.of(sheetContext).pop(),
              saving: saving,
              onSave: () async {
                final name = nameController.text.trim();
                final age = int.tryParse(ageController.text.trim());
                final babyName = babyNameController.text.trim();
                final city = (selectedCity ?? "").trim();

                if (name.isEmpty || babyName.isEmpty || city.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Lutfen isim, bebek adi ve sehir bilgisini gir.",
                      ),
                    ),
                  );
                  return;
                }

                setInner(() => saving = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString(AppConfig.profileNameKey, name);
                  if (age != null) {
                    await prefs.setInt(AppConfig.profileAgeKey, age);
                  } else {
                    await prefs.remove(AppConfig.profileAgeKey);
                  }

                  await prefs.setString(
                      AppConfig.caregiverRoleKey, selectedRole);
                  await prefs.setString(AppConfig.babyNameKey, babyName);
                  await prefs.setString(AppConfig.babyCityKey, city);
                  await prefs.setBool(AppConfig.planningBabyKey, planning);

                  if (planning) {
                    await prefs.remove(AppConfig.lastPeriodStartKey);
                    await prefs.remove(AppConfig.estimatedDueDateKey);
                  }

                  if (selectedRole != SetupOptions.motherRole) {
                    await prefs.remove(AppConfig.maternalChronicKey);
                  }

                  await _api.saveLocalIdentity(name: name);
                  if (age != null) {
                    await _api.saveWeekProfile(
                      age,
                      _medical.isEmpty ? null : _medical,
                    );
                  }

                  _name = name;
                  _age = age;
                  _setupRole = selectedRole;
                  _setupBabyName = babyName;
                  _setupCity = city;
                  _setupPlanningBaby = planning;
                  if (selectedRole != SetupOptions.motherRole) {
                    _maternalChronic = "";
                  }

                  if (!context.mounted) return;
                  setState(() {});
                  Navigator.of(sheetContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Profil ve kullanici bilgileri guncellendi.",
                      ),
                    ),
                  );
                } finally {
                  if (context.mounted) setInner(() => saving = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHealthEditor() async {
    final medicalController = TextEditingController(text: _medical);
    final maternalController = TextEditingController(text: _maternalChronic);
    var saving = false;
    final messenger = ScaffoldMessenger.of(context);

    await _showThemedSheet(
      title: "Saglik Bilgileri",
      icon: Icons.health_and_safety_outlined,
      builder: (sheetContext, setInner) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: medicalController,
              label: "Saglik gecmisi",
              prefixIcon: Icons.medical_information_outlined,
              minLines: 2,
              maxLines: 4,
            ),
            if (_isMother) ...[
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: maternalController,
                label: "Kronik rahatsizliklar ve ameliyatlar",
                prefixIcon: Icons.monitor_heart_outlined,
                minLines: 2,
                maxLines: 4,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _sheetActions(
              onCancel: saving ? null : () => Navigator.of(sheetContext).pop(),
              saving: saving,
              onSave: () async {
                setInner(() => saving = true);
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final medical = medicalController.text.trim();
                  final maternal = maternalController.text.trim();

                  await prefs.setString(AppConfig.profileMedicalKey, medical);
                  if (_isMother && maternal.isNotEmpty) {
                    await prefs.setString(
                      AppConfig.maternalChronicKey,
                      maternal,
                    );
                  } else {
                    await prefs.remove(AppConfig.maternalChronicKey);
                  }

                  final age = prefs.getInt(AppConfig.profileAgeKey);
                  if (age != null) {
                    await _api.saveWeekProfile(
                      age,
                      medical.isEmpty ? null : medical,
                    );
                  }

                  _medical = medical;
                  _maternalChronic = _isMother ? maternal : "";

                  if (!context.mounted) return;
                  setState(() {});
                  Navigator.of(sheetContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Saglik bilgileri guncellendi."),
                    ),
                  );
                } finally {
                  if (context.mounted) setInner(() => saving = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPasswordEditor() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    var saving = false;
    var obscureCurrent = true;
    var obscureNew = true;
    var obscureConfirm = true;
    final messenger = ScaffoldMessenger.of(context);

    await _showThemedSheet(
      title: "Sifre Degisikligi",
      icon: Icons.lock_outline_rounded,
      builder: (sheetContext, setInner) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: currentController,
              label: "Mevcut sifre",
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: obscureCurrent,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureCurrent
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: context.palette.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setInner(() => obscureCurrent = !obscureCurrent),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: newController,
              label: "Yeni sifre",
              prefixIcon: Icons.lock_reset_rounded,
              obscureText: obscureNew,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureNew
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: context.palette.textMuted,
                  size: 20,
                ),
                onPressed: () => setInner(() => obscureNew = !obscureNew),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: confirmController,
              label: "Yeni sifre (tekrar)",
              prefixIcon: Icons.check_circle_outline_rounded,
              obscureText: obscureConfirm,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureConfirm
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: context.palette.textMuted,
                  size: 20,
                ),
                onPressed: () =>
                    setInner(() => obscureConfirm = !obscureConfirm),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _sheetActions(
              onCancel: saving ? null : () => Navigator.of(sheetContext).pop(),
              saving: saving,
              saveLabel: "Guncelle",
              onSave: () async {
                final newPass = newController.text.trim();
                final confirmPass = confirmController.text.trim();

                if (newPass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Yeni sifre en az 6 karakter olmalidir.",
                      ),
                    ),
                  );
                  return;
                }

                if (newPass != confirmPass) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Sifreler eslesmiyor."),
                    ),
                  );
                  return;
                }

                setInner(() => saving = true);
                await Future<void>.delayed(const Duration(milliseconds: 450));

                if (!context.mounted) return;
                Navigator.of(sheetContext).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text("Sifre degisikligi talebi alindi."),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  static const String _faqText = "• Uygulama ne işe yarar?\n"
      "Gebelik sürecinde haftalık sağlık ölçümlerini kaydeder, doğrulanmış bir veri setine dayanan risk değerlendirmesi yapar ve kural tabanlı rehberlik sunar.\n\n"
      "• Risk skoru nasıl hesaplanır?\n"
      "Girdiğin ölçümler (tansiyon, kan şekeri, ateş, nabız, BMI, yaş) doğrulanmış maternal sağlık veri setindeki en yakın örneklerle karşılaştırılır (KNN yöntemi).\n\n"
      "• Rehberlik notları doktorun yerine geçer mi?\n"
      "Hayır. Öneriler yalnızca bilgilendirme amaçlıdır. Şüpheli veya acil bir durumda mutlaka doktoruna başvur.\n\n"
      "• Premium ne sağlar?\n"
      "Gebelik Rehberi ile sınırsız kullanım, detaylı değerlendirme notları ve premium içerik kütüphanesine erişim.\n\n"
      "• Verilerim güvende mi?\n"
      "Verilerin hesabına bağlı olarak güvenli şekilde tutulur; başka kullanıcılar erişemez. Ayrıntı için Gizlilik ve Güvenlik bölümüne bak.";

  static const String _privacyText = "Gizliliğine önem veriyoruz.\n\n"
      "• Hangi veriler tutulur: Ad, e-posta, yaş, şehir, bebek/gebelik bilgileri, sağlık notların ve girdiğin haftalık ölçümler.\n\n"
      "• Nerede tutulur: Veriler güvenli sunucuda (Supabase), satır düzeyinde güvenlik (RLS) ile korunur. Yalnızca sen ve yetkili yönetim erişebilir; başka kullanıcılar verilerini göremez.\n\n"
      "• Nasıl kullanılır: Yalnızca sana risk analizi ve kişisel öneri sunmak için. Verilerin pazarlama amacıyla üçüncü taraflarla paylaşılmaz.\n\n"
      "• Sağlık uyarısı: Bu uygulama tıbbi teşhis aracı değildir; acil durumda en yakın sağlık kuruluşuna başvur.\n\n"
      "• Hesabını veya verilerini silmek istersen Destek formundan bize ulaşabilirsin.";

  static const String _aboutText =
      "Gebelik Takip, gebelik ve bebek yolculuğunu daha düzenli sürdürmek için geliştirilmiş bir mobil uygulamadır.\n\n"
      "Özellikler:\n"
      "• Haftalık ölçüm girişi ve KNN tabanlı risk analizi\n"
      "• Kural tabanlı gebelik rehberi ve kişiselleştirilmiş notlar\n"
      "• Su, kilo, tekme, kasılma, günlük ve isim araçları\n"
      "• Randevu ve ilaç takibi, hatırlatıcı bildirimler\n"
      "• Premium içerik kütüphanesi (uzman rehberleri)\n\n"
      "Bu uygulama bilgilendirme amaçlıdır ve tıbbi tavsiyenin yerini tutmaz.";

  Future<void> _requestDataDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.palette.surface,
        title: const Text("Verilerimi Sil"),
        content: const Text(
          "Hesabının ve tüm verilerinin silinmesi için bir talep oluşturulacak. "
          "Talebin yönetim ekibine iletilir ve işleme alınır. Devam etmek istiyor musun?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text("Vazgeç"),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: context.palette.danger),
            child: const Text("Talep Oluştur"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.requestAccountAction("deletion");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Silme talebin alındı. En kısa sürede işlenecek."),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Talep oluşturulamadı: $e")),
      );
    }
  }

  Future<void> _showSupportForm() async {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    var sending = false;
    final messenger = ScaffoldMessenger.of(context);

    await _showThemedSheet(
      title: "Destek / İletişim",
      icon: Icons.support_agent_rounded,
      builder: (sheetContext, setInner) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InfoBanner(
              message: _name.trim().isEmpty
                  ? "Mesajın yönetim ekibine iletilir ve en kısa sürede yanıtlanır."
                  : "${_name.trim()} adına gönderilecek. Mesajın yönetim ekibine iletilir.",
              icon: Icons.info_outline_rounded,
              tone: PillTone.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: subjectController,
              label: "Konu (isteğe bağlı)",
              prefixIcon: Icons.title_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: messageController,
              label: "Mesajın",
              hint: "Sorunu veya geri bildirimini yaz...",
              prefixIcon: Icons.chat_bubble_outline_rounded,
              minLines: 3,
              maxLines: 6,
            ),
            const SizedBox(height: AppSpacing.md),
            _sheetActions(
              onCancel: sending ? null : () => Navigator.of(sheetContext).pop(),
              saving: sending,
              saveLabel: "Gönder",
              onSave: () async {
                final msg = messageController.text.trim();
                if (msg.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Lütfen bir mesaj yaz.")),
                  );
                  return;
                }
                setInner(() => sending = true);
                try {
                  final subject = subjectController.text.trim();
                  await _api.submitSupportMessage(
                    subject: subject.isEmpty ? "Destek talebi" : subject,
                    message: msg,
                  );
                  if (!context.mounted) return;
                  Navigator.of(sheetContext).pop();
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text("Mesajın iletildi. Teşekkürler! 💜"),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text("Gönderilemedi: $e")),
                  );
                  setInner(() => sending = false);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showInfo(String title, String description) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: context.palette.bgElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: context.palette.borderSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 36,
                      width: 36,
                      decoration: BoxDecoration(
                        color: context.palette.surfaceHigh,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                        border: Border.all(color: context.palette.borderSoft),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        color: context.palette.primarySoft,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 13.5,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  onPressed: () => Navigator.of(context).pop(),
                  label: "Tamam",
                  icon: Icons.check_rounded,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    final auth = context.read<AuthProvider>();
    try {
      await auth.logout();
    } catch (e) {
      await auth.api.clearSession();
      auth.markSignedOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ag baglantisi yoksa da cikis tamamlandi: $e"),
          ),
        );
      }
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.guestModeKey, false);
      await prefs.setBool(AppConfig.authStepDoneKey, false);
      EntryFlowSignal.notifyChanged();
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  Future<void> _restartEntryFlow() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.seenOnboardingKey, false);
    await prefs.setBool(AppConfig.authStepDoneKey, false);
    await prefs.setBool(AppConfig.firstSetupDoneKey, false);
    await prefs.setBool(AppConfig.guestModeKey, false);
    EntryFlowSignal.notifyChanged();
  }

  Future<void> _showThemedSheet({
    required String title,
    required IconData icon,
    required Widget Function(BuildContext, StateSetter) builder,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.bgBase,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setInner) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                top: AppSpacing.xs,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          height: 36,
                          width: 36,
                          decoration: BoxDecoration(
                            color: context.palette.surfaceHigh,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                            border:
                                Border.all(color: context.palette.borderSoft),
                          ),
                          child: Icon(
                            icon,
                            color: context.palette.primarySoft,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    builder(sheetContext, setInner),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dropdownBlock({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: context.palette.bgElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Text(
                hint ?? "Sec",
                style: TextStyle(
                  color: context.palette.textMuted,
                  fontSize: 14.5,
                ),
              ),
              dropdownColor: context.palette.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.palette.textSecondary,
              ),
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
              items: items
                  .map(
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(i),
                    ),
                  )
                  .toList(growable: false),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchTile({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _sheetActions({
    required VoidCallback? onCancel,
    required VoidCallback onSave,
    required bool saving,
    String saveLabel = "Kaydet",
  }) {
    return Row(
      children: [
        Expanded(
          child: SecondaryButton(
            onPressed: onCancel,
            label: "Vazgec",
            icon: Icons.close_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: PrimaryButton(
            onPressed: saving ? null : onSave,
            loading: saving,
            label: saveLabel,
            icon: Icons.check_rounded,
          ),
        ),
      ],
    );
  }
}
