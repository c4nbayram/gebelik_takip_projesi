import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../appointments_screen.dart';
import '../doctor_report_screen.dart';
import '../food_safety_screen.dart';
import '../medications_screen.dart';
import '../premium_content_screen.dart';
import '../prenatal_calendar_screen.dart';
import '../red_flag_screen.dart';
import 'baby_mode_screen.dart';
import 'checklist_screen.dart';
import 'contraction_timer_screen.dart';
import 'journal_screen.dart';
import 'kick_counter_screen.dart';
import 'names_screen.dart';
import 'symptoms_screen.dart';
import 'water_screen.dart';
import 'weight_screen.dart';

class _Tool {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final WidgetBuilder builder;
  const _Tool(
      this.icon, this.title, this.subtitle, this.gradient, this.builder);
}

class ToolsHubScreen extends StatelessWidget {
  const ToolsHubScreen({super.key});

  List<_Tool> _tools() => [
        _Tool(
            Icons.touch_app_rounded,
            "Tekme Sayar",
            "Bebek hareketlerini say",
            const [Color(0xFF8C7BFF), Color(0xFF6F5AE0)],
            (_) => const KickCounterScreen()),
        _Tool(
            Icons.timer_rounded,
            "Kasılma Zamanlayıcı",
            "Süre ve aralık ölç",
            const [Color(0xFFFF8FB1), Color(0xFFF2689A)],
            (_) => const ContractionTimerScreen()),
        _Tool(
            Icons.monitor_weight_rounded,
            "Kilo Takibi",
            "Haftalık kilo & grafik",
            const [Color(0xFF36C39A), Color(0xFF1FB68A)],
            (_) => const WeightScreen()),
        _Tool(
            Icons.local_drink_rounded,
            "Su Takibi",
            "Günlük su hedefin",
            const [Color(0xFF5B8DEF), Color(0xFF4F86E8)],
            (_) => const WaterScreen()),
        _Tool(
            Icons.auto_stories_rounded,
            "Günlük",
            "Ruh hali & not",
            const [Color(0xFFF0A93D), Color(0xFFE2912F)],
            (_) => const JournalScreen()),
        _Tool(
            Icons.healing_rounded,
            "Belirti Takibi",
            "Semptom & check-in",
            const [Color(0xFF8C7BFF), Color(0xFFF2689A)],
            (_) => const SymptomsScreen()),
        _Tool(
            Icons.checklist_rounded,
            "Kontrol Listeleri",
            "Çanta, plan, alışveriş",
            const [Color(0xFF36C39A), Color(0xFF1FB68A)],
            (_) => const ChecklistScreen()),
        _Tool(
            Icons.event_note_rounded,
            "Prenatal Takvim",
            "Test & aşı zamanları",
            const [Color(0xFF5B8DEF), Color(0xFF4F86E8)],
            (_) => const PrenatalCalendarScreen()),
        _Tool(
            Icons.restaurant_rounded,
            "Beslenme & İlaç",
            "Güvenli mi rehberi",
            const [Color(0xFFF0A93D), Color(0xFFE2912F)],
            (_) => const FoodSafetyScreen()),
        _Tool(
            Icons.summarize_rounded,
            "Doktora Özet",
            "Ölçüm raporu oluştur",
            const [Color(0xFF7C6CF0), Color(0xFF9B7BF0)],
            (_) => const DoctorReportScreen()),
        _Tool(
            Icons.child_friendly_rounded,
            "Bebek Takibi",
            "Beslenme/uyku/bez",
            const [Color(0xFFFF7C91), Color(0xFFEE7CA2)],
            (_) => const BabyModeScreen()),
        _Tool(
            Icons.emergency_rounded,
            "Acil Belirtiler",
            "Ne zaman doktora?",
            const [Color(0xFFB84A5E), Color(0xFFFF7E8C)],
            (_) => const RedFlagScreen()),
        _Tool(
            Icons.favorite_rounded,
            "Bebek İsimleri",
            "Favori isim listesi",
            const [Color(0xFFFF7C91), Color(0xFFEE7CA2)],
            (_) => const NamesScreen()),
        _Tool(
            Icons.event_rounded,
            "Randevular",
            "Doktor takvimin",
            const [Color(0xFF7C6CF0), Color(0xFF9B7BF0)],
            (_) => const AppointmentsScreen()),
        _Tool(
            Icons.medication_rounded,
            "İlaçlar",
            "İlaç & vitamin takibi",
            const [Color(0xFF36C39A), Color(0xFF5B8DEF)],
            (_) => const MedicationsScreen()),
        _Tool(
            Icons.workspace_premium_rounded,
            "Premium İçerik",
            "Uzman rehberleri",
            const [Color(0xFFF0A93D), Color(0xFFEE7CA2)],
            (_) => const PremiumContentScreen()),
      ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final tools = _tools();
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: p.brandGradient),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: p.glow(p.primary, strength: 0.25),
                      ),
                      child: const Icon(Icons.widgets_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Araçlar",
                              style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          Text("Gebelik yolculuğun için yardımcılar",
                              style: TextStyle(
                                  color: p.textMuted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 120),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  childAspectRatio: 1.08,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _ToolCard(tool: tools[i]),
                  childCount: tools.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: tool.builder),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: p.borderSoft),
            boxShadow: p.softShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: tool.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: p.glow(tool.gradient.first, strength: 0.28),
                  ),
                  child: Icon(tool.icon, color: Colors.white, size: 26),
                ),
                const Spacer(),
                Text(
                  tool.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tool.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(color: p.textMuted, fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
