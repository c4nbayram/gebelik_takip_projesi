import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_common.dart';
import '../../widgets/app_text_field.dart';

const _commonSymptoms = <String>[
  "Bulantı",
  "Kusma",
  "Yorgunluk",
  "Baş ağrısı",
  "Bel/sırt ağrısı",
  "Mide yanması",
  "Kabızlık",
  "Ödem / şişlik",
  "Baş dönmesi",
  "Uykusuzluk",
  "Sık idrar",
  "Nefes darlığı",
  "Kramp",
  "Göğüs hassasiyeti",
  "İştahsızlık",
  "Ruh hali değişimi",
];

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _note = TextEditingController();
  final Set<String> _selected = {};
  int _severity = 1;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selected.isEmpty && _note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("En az bir belirti seç veya not yaz.")),
      );
      return;
    }
    if (!await ensureSignedIn(context,
        reason: "Belirti kaydı için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final week = prefs.getInt("gebelik_current_week");
      await _api.addSymptomLog(
        symptoms: _selected.toList(),
        severity: _severity,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        weekNo: week,
      );
      _selected.clear();
      _note.clear();
      _severity = 1;
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _severityLabel(int? s) {
    switch (s) {
      case 3:
        return "Şiddetli";
      case 2:
        return "Orta";
      default:
        return "Hafif";
    }
  }

  PillTone _severityTone(int? s) {
    switch (s) {
      case 3:
        return PillTone.danger;
      case 2:
        return PillTone.warning;
      default:
        return PillTone.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Belirti Takibi")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
          children: [
            const SectionHeader(
              title: "Bugün ne hissediyorsun?",
              subtitle: "Belirtilerini seç, şiddetini belirt",
              icon: Icons.healing_rounded,
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final s in _commonSymptoms)
                        FilterChip(
                          label: Text(s),
                          selected: _selected.contains(s),
                          onSelected: (v) => setState(() {
                            if (v) {
                              _selected.add(s);
                            } else {
                              _selected.remove(s);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text("Şiddet",
                      style: TextStyle(
                          color: p.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      for (final lvl in const [1, 2, 3])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: ChoiceChip(
                            label: Text(_severityLabel(lvl)),
                            selected: _severity == lvl,
                            onSelected: (_) => setState(() => _severity = lvl),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _note,
                    label: "Not (isteğe bağlı)",
                    hint: "Detay eklemek istersen...",
                    prefixIcon: Icons.edit_note_rounded,
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    onPressed: _saving ? null : _save,
                    loading: _saving,
                    label: "Kaydet",
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Geçmiş Kayıtlar",
              icon: Icons.history_rounded,
            ),
            StreamBuilder<List<SymptomLog>>(
              stream: _api.symptomLogsStream(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <SymptomLog>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.healing_rounded,
                    title: "Henüz belirti kaydı yok",
                    description: "Bugünkü belirtilerini ekleyerek başla.",
                  );
                }
                return Column(
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat("dd MMMM yyyy", "tr_TR")
                                          .format(e.loggedOn),
                                      style: TextStyle(
                                          color: p.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5),
                                    ),
                                  ),
                                  StatPill(
                                    label: "",
                                    value: _severityLabel(e.severity),
                                    tone: _severityTone(e.severity),
                                  ),
                                  IconButton(
                                    onPressed: () =>
                                        _api.deleteSymptomLog(e.id),
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: p.danger, size: 19),
                                  ),
                                ],
                              ),
                              if (e.symptoms.isNotEmpty)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final s in e.symptoms)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: p.surfaceHigh,
                                          borderRadius: BorderRadius.circular(
                                              AppRadius.pill),
                                          border:
                                              Border.all(color: p.borderSoft),
                                        ),
                                        child: Text(s,
                                            style: TextStyle(
                                                color: p.textSecondary,
                                                fontSize: 12)),
                                      ),
                                  ],
                                ),
                              if ((e.note ?? "").isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(e.note!,
                                    style: TextStyle(
                                        color: p.textMuted,
                                        fontSize: 12.5,
                                        height: 1.4)),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
