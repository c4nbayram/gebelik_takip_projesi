import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/setup_options.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';
import '../widgets/app_text_field.dart';

class InitialSetupData {
  const InitialSetupData({
    required this.caregiverRole,
    required this.babyName,
    required this.city,
    required this.planningBaby,
    required this.maternalChronicCondition,
    this.birthDate,
    this.lastPeriodStart,
    this.estimatedDueDate,
  });

  final String caregiverRole;
  final String babyName;
  final String city;
  final bool planningBaby;
  final String? maternalChronicCondition;
  final DateTime? birthDate;
  final DateTime? lastPeriodStart;
  final DateTime? estimatedDueDate;
}

class InitialSetupScreen extends StatefulWidget {
  const InitialSetupScreen({super.key, required this.onCompleted});

  final Future<void> Function(InitialSetupData data) onCompleted;

  @override
  State<InitialSetupScreen> createState() => _InitialSetupScreenState();
}

class _InitialSetupScreenState extends State<InitialSetupScreen> {
  final TextEditingController _babyNameController = TextEditingController();
  final TextEditingController _maternalChronicController =
      TextEditingController();

  String _selectedRole = SetupOptions.caregiverRoles.first;
  String? _selectedCity;
  DateTime? _lastPeriodStart;
  DateTime? _estimatedDueDate;
  bool _planningBaby = false;
  bool _saving = false;

  @override
  void dispose() {
    _babyNameController.dispose();
    _maternalChronicController.dispose();
    super.dispose();
  }

  bool get _isMother => _selectedRole == SetupOptions.motherRole;

  String _roleDisplay(String role) {
    const map = {
      "Annesiyim": "Anne",
      "Babasiyim": "Baba",
      "Abisiyim": "Abi",
      "Halasiyim": "Hala",
      "Babannesiyim": "Babaanne",
      "Teyzesiyim": "Teyze",
    };
    return map[role] ?? role;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: firstDate ?? DateTime(now.year - 10),
      lastDate: lastDate ?? DateTime(now.year + 2),
    );
    if (picked == null) return;
    onPicked(picked);
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return "";
    return DateFormat("dd.MM.yyyy").format(date);
  }

  Future<void> _submit() async {
    final babyName = _babyNameController.text.trim();
    final city = (_selectedCity ?? "").trim();
    final maternalChronic = _maternalChronicController.text.trim();

    if (city.isEmpty) {
      _snack("Lütfen şehir bilgisini seç.");
      return;
    }
    if (_isMother &&
        !_planningBaby &&
        _lastPeriodStart == null &&
        _estimatedDueDate == null) {
      _snack(
        "Gebelik haftasını hesaplamak için son adet başlangıcı veya tahmini doğum tarihi seç.",
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onCompleted(
        InitialSetupData(
          caregiverRole: _selectedRole,
          babyName: babyName.isEmpty ? "Bebek" : babyName,
          city: city,
          planningBaby: _planningBaby,
          maternalChronicCondition:
              _isMother && maternalChronic.isNotEmpty ? maternalChronic : null,
          birthDate: null,
          lastPeriodStart: _planningBaby ? null : _lastPeriodStart,
          estimatedDueDate: _planningBaby ? null : _estimatedDueDate,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _profileSection(),
                    const SizedBox(height: AppSpacing.md),
                    _timelineSection(),
                    if (_isMother) ...[
                      const SizedBox(height: AppSpacing.md),
                      _healthSection(),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: PrimaryButton(
                onPressed: _saving ? null : _submit,
                label: "Baslayalim",
                icon: Icons.arrow_forward_rounded,
                loading: _saving,
                size: AppButtonSize.large,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: GradientHeroCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
              ),
              child: const Icon(Icons.child_friendly_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Takibi kişiselleştirelim",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Rolüne göre sadece gerekli soruları göstereceğiz.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: "Profil bilgileri",
            subtitle: "Rol, bebek adı ve şehir",
            icon: Icons.person_outline_rounded,
          ),
          _dropdownField<String>(
            label: "Rolün",
            value: _selectedRole,
            icon: Icons.badge_outlined,
            items: SetupOptions.caregiverRoles
                .map((r) =>
                    DropdownMenuItem(value: r, child: Text(_roleDisplay(r))))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _selectedRole = v;
                if (!_isMother) _maternalChronicController.clear();
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _babyNameController,
            label: "Bebeğin adı veya takma adı",
            hint: "Bilmiyorsan boş bırakabilirsin",
            prefixIcon: Icons.toys_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _dropdownField<String>(
            label: "Yaşadığın şehir",
            value: _selectedCity,
            icon: Icons.location_on_outlined,
            hint: "Şehir seç",
            items: SetupOptions.turkishCities
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _selectedCity = v),
          ),
        ],
      ),
    );
  }

  Widget _timelineSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: "Gebelik durumu",
            subtitle: "Sürecin hangi aşamada olduğunu seç",
            icon: Icons.timeline_rounded,
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: context.palette.surfaceHigh.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: context.palette.borderSoft),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isMother
                            ? "Hamile değilim, bebek planlıyorum"
                            : "Bebek planlama sürecindeyiz",
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Açılırsa gebelik tarihleri istenmez.",
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _planningBaby,
                  onChanged: (v) {
                    setState(() {
                      _planningBaby = v;
                      if (v) {
                        _lastPeriodStart = null;
                        _estimatedDueDate = null;
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          if (!_planningBaby) ...[
            const SizedBox(height: AppSpacing.sm),
            AppSelectField(
              label: _isMother
                  ? "Son adet başlangıç günü"
                  : "Son adet başlangıcı (biliyorsan)",
              placeholder: "Seç",
              value: _dateLabel(_lastPeriodStart),
              onTap: () => _pickDate(
                current: _lastPeriodStart,
                firstDate: DateTime.now().subtract(const Duration(days: 730)),
                lastDate: DateTime.now(),
                onPicked: (p) => setState(() => _lastPeriodStart = p),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Divider(color: context.palette.borderSoft, height: 1),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Text(
                    "veya",
                    style: TextStyle(
                      color: context.palette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: context.palette.borderSoft, height: 1),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AppSelectField(
              label: "Bebeğin tahmini doğum tarihi",
              placeholder: "Seç",
              value: _dateLabel(_estimatedDueDate),
              onTap: () => _pickDate(
                current: _estimatedDueDate,
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 320)),
                onPicked: (p) => setState(() => _estimatedDueDate = p),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _healthSection() {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: "Sağlık notu",
            subtitle: "Opsiyonel",
            icon: Icons.health_and_safety_outlined,
          ),
          AppTextField(
            controller: _maternalChronicController,
            hint: "Kronik rahatsızlıklar ve geçirilen ameliyatlar (opsiyonel)",
            prefixIcon: Icons.notes_rounded,
            minLines: 2,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _dropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    IconData? icon,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: context.palette.bgElevated.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: context.palette.textMuted, size: 20),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                iconEnabledColor: context.palette.textSecondary,
                dropdownColor: context.palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                hint: hint == null
                    ? null
                    : Text(
                        hint,
                        style: TextStyle(
                          color: context.palette.textMuted,
                          fontSize: 15,
                        ),
                      ),
                items: items,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
