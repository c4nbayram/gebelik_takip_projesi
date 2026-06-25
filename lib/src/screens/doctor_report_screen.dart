import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/api_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_common.dart';

class DoctorReportScreen extends StatefulWidget {
  const DoctorReportScreen({super.key});

  @override
  State<DoctorReportScreen> createState() => _DoctorReportScreenState();
}

class _DoctorReportScreenState extends State<DoctorReportScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  String? _report;

  @override
  void initState() {
    super.initState();
    _build();
  }

  int? _currentWeek(DateTime? lastPeriod, DateTime? dueDate) {
    if (lastPeriod != null) {
      final days = DateTime.now().difference(lastPeriod).inDays;
      if (days >= 0) return ((days ~/ 7) + 1).clamp(1, 42);
    }
    if (dueDate != null) {
      final daysToDue = dueDate.difference(DateTime.now()).inDays;
      return (40 - (daysToDue / 7).ceil()).clamp(1, 42);
    }
    return null;
  }

  Future<void> _build() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await _api.getWeekEntries();

    DateTime? readDate(String key) {
      final ms = prefs.getInt(key);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    }

    final name = prefs.getString(AppConfig.profileNameKey) ?? "-";
    final age = prefs.getInt(AppConfig.profileAgeKey);
    final role = prefs.getString(AppConfig.caregiverRoleKey) ?? "-";
    final babyName = prefs.getString(AppConfig.babyNameKey) ?? "-";
    final city = prefs.getString(AppConfig.babyCityKey) ?? "-";
    final lastPeriod = readDate(AppConfig.lastPeriodStartKey);
    final dueDate = readDate(AppConfig.estimatedDueDateKey);
    final medical = prefs.getString(AppConfig.profileMedicalKey) ?? "";
    final maternal = prefs.getString(AppConfig.maternalChronicKey) ?? "";
    final week = _currentWeek(lastPeriod, dueDate);

    String fmt(DateTime? d) =>
        d == null ? "-" : DateFormat("dd.MM.yyyy").format(d);

    final b = StringBuffer();
    b.writeln("GEBELİK TAKİP — DOKTOR ÖZETİ");
    b.writeln(
        "Oluşturulma: ${DateFormat("dd.MM.yyyy HH:mm").format(DateTime.now())}");
    b.writeln("");
    b.writeln("— PROFİL —");
    b.writeln("Ad: $name");
    b.writeln("Yaş: ${age?.toString() ?? "-"}");
    b.writeln("Rol: $role");
    b.writeln("Bebek adı: $babyName");
    b.writeln("Şehir: $city");
    b.writeln("Güncel hafta: ${week?.toString() ?? "-"}");
    b.writeln("Son adet: ${fmt(lastPeriod)}");
    b.writeln("Tahmini doğum: ${fmt(dueDate)}");
    if (medical.trim().isNotEmpty) {
      b.writeln("Sağlık geçmişi: ${medical.trim()}");
    }
    if (maternal.trim().isNotEmpty) {
      b.writeln("Kronik rahatsızlık: ${maternal.trim()}");
    }
    b.writeln("");
    b.writeln("— SON ÖLÇÜMLER —");
    if (entries.isEmpty) {
      b.writeln("Kayıt yok.");
    } else {
      final recent = [...entries]..sort((a, c) => c.weekNo.compareTo(a.weekNo));
      for (final e in recent.take(6)) {
        final parts = <String>[];
        if (e.systolic != null && e.diastolic != null) {
          parts.add(
              "TA ${e.systolic!.toStringAsFixed(0)}/${e.diastolic!.toStringAsFixed(0)}");
        }
        if (e.bloodSugar != null) {
          parts.add("Şeker ${e.bloodSugar!.toStringAsFixed(0)}");
        }
        if (e.bodyTemp != null) {
          parts.add("Ateş ${e.bodyTemp!.toStringAsFixed(1)}");
        }
        if (e.bmi != null) parts.add("BMI ${e.bmi!.toStringAsFixed(1)}");
        if (e.heartRate != null) {
          parts.add("Nabız ${e.heartRate!.toStringAsFixed(0)}");
        }
        final risk = e.riskLabel == null
            ? ""
            : " | Risk: ${e.riskLabel} (%${((e.riskScore ?? 0) * 100).toStringAsFixed(0)})";
        b.writeln("Hafta ${e.weekNo}: ${parts.join(", ")}$risk");
      }
    }
    b.writeln("");
    b.writeln("Not: Bu özet bilgilendirme amaçlıdır, tıbbi teşhis değildir.");

    if (mounted) setState(() => _report = b.toString());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Doktora Özet")),
      body: SafeArea(
        child: _report == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
                    AppSpacing.md, AppSpacing.xxl),
                children: [
                  const InfoBanner(
                    message:
                        "Bu özeti doktor ziyaretinde gösterebilir veya kopyalayıp paylaşabilirsin.",
                    icon: Icons.summarize_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    child: SelectableText(
                      _report!,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13,
                        height: 1.55,
                        fontFeatures: const [],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await Clipboard.setData(ClipboardData(text: _report!));
                      messenger.showSnackBar(
                        const SnackBar(content: Text("Özet kopyalandı.")),
                      );
                    },
                    label: "Kopyala",
                    icon: Icons.copy_rounded,
                  ),
                ],
              ),
      ),
    );
  }
}
