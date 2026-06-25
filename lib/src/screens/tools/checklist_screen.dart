import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_config.dart';
import '../../core/guest_guard.dart';
import '../../models/app_models.dart';
import '../../services/api_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_common.dart';

const _categories = <(String, String, IconData)>[
  ("hospital_bag", "Hastane Çantası", Icons.luggage_rounded),
  ("birth_plan", "Doğum Planı", Icons.assignment_rounded),
  ("todo", "Yapılacaklar", Icons.checklist_rounded),
  ("shopping", "Alışveriş", Icons.shopping_bag_rounded),
];

const Map<String, List<String>> _defaults = {
  "hospital_bag": [
    "Kimlik & sağlık karnesi",
    "Gebelik takip kartı",
    "Rahat gecelik / pijama",
    "Terlik",
    "Hırka",
    "Emzirme sütyeni",
    "Lohusa pedi",
    "Diş fırçası & kişisel bakım",
    "Telefon şarj aleti",
    "Bebek body & zıbın",
    "Bebek battaniyesi",
    "Bebek çıkış kıyafeti",
    "Islak mendil & bez",
    "Su & atıştırmalık",
  ],
  "birth_plan": [
    "Doğum şekli tercihi (normal/sezaryen)",
    "Ağrı yönetimi tercihi (epidural vb.)",
    "Refakatçi kim olacak",
    "Doğum sonrası ten tene temas",
    "Emzirmeye hemen başlama",
    "Kordon klempleme tercihi",
    "Acil durum iletişim kişisi",
  ],
  "todo": [
    "Doğum hastanesini seç",
    "Pediatrist araştır",
    "Bebek odasını hazırla",
    "Oto koltuğu al & tak",
    "Doğum iznini ayarla",
    "Gerekli belgeleri hazırla",
    "Emzirme hakkında bilgi al",
  ],
  "shopping": [
    "Bebek bezi",
    "Biberon & sterilizatör",
    "Bebek arabası",
    "Beşik / portbebe",
    "Bebek giysileri (mevsimlik)",
    "Banyo küveti",
    "Termometre",
    "Emzik",
  ],
};

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key});

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _add = TextEditingController();
  String _cat = _categories.first.$1;
  bool _seeding = true;

  static const String _seededKey = "gebelik_checklist_seeded";

  @override
  void initState() {
    super.initState();
    _ensureSeeded();
  }

  @override
  void dispose() {
    _add.dispose();
    super.dispose();
  }

  Future<void> _ensureSeeded() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_seededKey) ?? false) {
      if (mounted) setState(() => _seeding = false);
      return;
    }
    final existing = await _api.getChecklistItems();
    if (existing.isEmpty) {
      await _api.seedDefaultChecklist(_defaults);
    }
    await prefs.setBool(_seededKey, true);
    if (mounted) setState(() => _seeding = false);
  }

  Future<void> _addItem() async {
    final title = _add.text.trim();
    if (title.isEmpty) return;
    if (!await ensureSignedIn(context,
        reason: "Liste düzenlemek için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    _add.clear();
    FocusScope.of(context).unfocus();
    await _api.addChecklistItem(category: _cat, title: title);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Kontrol Listeleri")),
      body: SafeArea(
        top: false,
        child: _seeding
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _categories)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.xs),
                              child: ChoiceChip(
                                avatar: Icon(c.$3,
                                    size: 16,
                                    color: _cat == c.$1
                                        ? Colors.white
                                        : p.textMuted),
                                label: Text(c.$2),
                                selected: _cat == c.$1,
                                onSelected: (_) => setState(() => _cat = c.$1),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<ChecklistItem>>(
                      stream: _api.checklistStream(),
                      builder: (context, snapshot) {
                        final all = snapshot.data ?? const <ChecklistItem>[];
                        final items =
                            all.where((e) => e.category == _cat).toList();
                        final done = items.where((e) => e.isDone).length;
                        final ratio = items.isEmpty ? 0.0 : done / items.length;
                        return ListView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                              AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
                          children: [
                            _progress(p, done, items.length, ratio),
                            const SizedBox(height: AppSpacing.sm),
                            if (items.isEmpty)
                              const EmptyState(
                                icon: Icons.checklist_rounded,
                                title: "Liste boş",
                                description:
                                    "Aşağıdan yeni madde ekleyebilirsin.",
                              )
                            else
                              for (final e in items) _row(p, e),
                          ],
                        );
                      },
                    ),
                  ),
                  _addBar(p),
                ],
              ),
      ),
    );
  }

  Widget _progress(AppPalette p, int done, int total, double ratio) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("$done / $total tamamlandı",
                    style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    backgroundColor: p.surfaceHigh,
                    color: p.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text("%${(ratio * 100).round()}",
              style: TextStyle(
                  color: p.primary, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _row(AppPalette p, ChecklistItem e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: AppCard(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: e.isDone,
              onChanged: (v) => _api.setChecklistDone(e.id, v ?? false),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            Expanded(
              child: Text(
                e.title,
                style: TextStyle(
                  color: e.isDone ? p.textMuted : p.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: e.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _api.deleteChecklistItem(e.id),
              icon:
                  Icon(Icons.delete_outline_rounded, color: p.danger, size: 19),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addBar(AppPalette p) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: p.bgElevated,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: p.borderSoft),
              ),
              child: TextField(
                controller: _add,
                onSubmitted: (_) => _addItem(),
                textInputAction: TextInputAction.done,
                style: TextStyle(color: p.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Yeni madde ekle...",
                  hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _addItem,
              child: Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: p.brandGradient),
                  shape: BoxShape.circle,
                  boxShadow: p.glow(p.primary, strength: 0.3),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
