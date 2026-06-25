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

const _moods = <String, String>{
  "😊": "Mutlu",
  "😌": "Huzurlu",
  "😐": "Normal",
  "😟": "Endişeli",
  "😢": "Üzgün",
  "😴": "Yorgun",
};

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _note = TextEditingController();
  String? _mood;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_mood == null && _note.text.trim().isEmpty) return;
    if (!await ensureSignedIn(context,
        reason: "Günlük kaydetmek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await _api.addJournal(mood: _mood, note: _note.text.trim());
      _note.clear();
      setState(() => _mood = null);
      if (mounted) FocusScope.of(context).unfocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Günlük")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
          children: [
            const SectionHeader(
              title: "Bugün nasıl hissediyorsun?",
              icon: Icons.emoji_emotions_rounded,
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      for (final entry in _moods.entries)
                        GestureDetector(
                          onTap: () => setState(() => _mood = entry.key),
                          child: Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _mood == entry.key
                                  ? p.primaryBg
                                  : p.surfaceHigh,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _mood == entry.key
                                    ? p.primary
                                    : p.borderSoft,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(entry.key,
                                    style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 2),
                                Text(entry.value,
                                    style: TextStyle(
                                        color: p.textMuted, fontSize: 10.5)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _note,
                    label: "Not (isteğe bağlı)",
                    hint: "Bugün aklından geçenler...",
                    prefixIcon: Icons.edit_note_rounded,
                    minLines: 2,
                    maxLines: 5,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    onPressed: _saving ? null : _save,
                    loading: _saving,
                    label: "Günlüğe Ekle",
                    icon: Icons.add_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
              title: "Geçmiş Notlar",
              icon: Icons.history_rounded,
            ),
            StreamBuilder<List<JournalEntry>>(
              stream: _api.journalStream(),
              builder: (context, snapshot) {
                final items = snapshot.data ?? const <JournalEntry>[];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.auto_stories_rounded,
                    title: "Henüz günlük yok",
                    description: "İlk notunu ekleyerek başla.",
                  );
                }
                return Column(
                  children: [
                    for (final e in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: AppCard(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.mood ?? "📝",
                                  style: const TextStyle(fontSize: 26)),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat(
                                              "dd MMMM yyyy • HH:mm", "tr_TR")
                                          .format(e.createdAt),
                                      style: TextStyle(
                                          color: p.textMuted, fontSize: 11.5),
                                    ),
                                    if ((e.note ?? "").isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(e.note!,
                                          style: TextStyle(
                                              color: p.textSecondary,
                                              fontSize: 13.5,
                                              height: 1.4)),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _api.deleteJournal(e.id),
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
