import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

const _types = <(String, String, String, IconData)>[
  ("feeding", "Beslenme", "ör. 120 ml veya sol/sağ", Icons.local_drink_rounded),
  ("sleep", "Uyku", "ör. 45 dk", Icons.bedtime_rounded),
  ("diaper", "Bez", "ör. kaka / çiş", Icons.baby_changing_station_rounded),
];

class BabyModeScreen extends StatefulWidget {
  const BabyModeScreen({super.key});

  @override
  State<BabyModeScreen> createState() => _BabyModeScreenState();
}

class _BabyModeScreenState extends State<BabyModeScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _type = _types.first.$1;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  (String, String, String, IconData) get _typeDef =>
      _types.firstWhere((t) => t.$1 == _type);

  String _typeLabel(String t) =>
      _types.firstWhere((e) => e.$1 == t, orElse: () => _types.first).$2;

  IconData _typeIcon(String t) =>
      _types.firstWhere((e) => e.$1 == t, orElse: () => _types.first).$4;

  Future<void> _save() async {
    if (!await ensureSignedIn(context,
        reason: "Bebek kaydı için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await _api.addBabyLog(
        type: _type,
        amount: _amount.text.trim().isEmpty ? null : _amount.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      _amount.clear();
      _note.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Bebek Takibi")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
          children: [
            const InfoBanner(
              message:
                  "Doğum sonrası beslenme, uyku ve bez değişimlerini hızlıca kaydet.",
              icon: Icons.child_friendly_rounded,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      for (final t in _types)
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.only(right: AppSpacing.xs),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.$4,
                                      size: 15,
                                      color: _type == t.$1
                                          ? Colors.white
                                          : p.textMuted),
                                  const SizedBox(width: 4),
                                  Flexible(
                                      child: Text(t.$2,
                                          overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                              selected: _type == t.$1,
                              onSelected: (_) => setState(() => _type = t.$1),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _amount,
                    label: "Miktar / süre",
                    hint: _typeDef.$3,
                    prefixIcon: Icons.straighten_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _note,
                    label: "Not (isteğe bağlı)",
                    prefixIcon: Icons.edit_note_rounded,
                    minLines: 1,
                    maxLines: 3,
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
              title: "Bugünün Kayıtları",
              icon: Icons.history_rounded,
            ),
            StreamBuilder<List<BabyLog>>(
              stream: _api.babyLogsStream(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <BabyLog>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.child_care_rounded,
                    title: "Henüz kayıt yok",
                    description: "İlk beslenme, uyku veya bez kaydını ekle.",
                  );
                }
                return Column(
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs),
                          child: Row(
                            children: [
                              Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  color: p.primaryBg,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Icon(_typeIcon(e.type),
                                    color: p.primary, size: 20),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "${_typeLabel(e.type)}${e.amount != null ? " · ${e.amount}" : ""}",
                                      style: TextStyle(
                                          color: p.textPrimary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                    ),
                                    Text(
                                      DateFormat("dd MMM • HH:mm", "tr_TR")
                                              .format(e.occurredAt) +
                                          ((e.note ?? "").isNotEmpty
                                              ? " · ${e.note}"
                                              : ""),
                                      style: TextStyle(
                                          color: p.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _api.deleteBabyLog(e.id),
                                icon: Icon(Icons.delete_outline_rounded,
                                    color: p.danger, size: 19),
                              ),
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
