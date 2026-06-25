import 'package:flutter/material.dart';

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

class NamesScreen extends StatefulWidget {
  const NamesScreen({super.key});

  @override
  State<NamesScreen> createState() => _NamesScreenState();
}

class _NamesScreenState extends State<NamesScreen> {
  final _api = ApiService(baseUrl: AppConfig.apiBaseUrl);
  final _name = TextEditingController();
  String _gender = "Kız";
  bool _onlyFav = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    if (!await ensureSignedIn(context,
        reason: "İsim listesi oluşturmak için giriş yapmalısın.")) {
      return;
    }
    if (!mounted) return;
    _name.clear();
    FocusScope.of(context).unfocus();
    await _api.addBabyName(name: name, gender: _gender);
  }

  Color _genderColor(AppPalette p, String? g) {
    if (g == "Erkek") return p.info;
    if (g == "Kız") return p.accent;
    return p.primary;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text("Bebek İsimleri")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxxl),
          children: [
            const SectionHeader(
              title: "İsim Ekle",
              subtitle: "Beğendiğin isimleri biriktir",
              icon: Icons.add_circle_outline_rounded,
            ),
            AppCard(
              child: Column(
                children: [
                  AppTextField(
                    controller: _name,
                    label: "İsim",
                    hint: "ör. Defne",
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      for (final g in const ["Kız", "Erkek", "Sürpriz"])
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: ChoiceChip(
                            label: Text(g),
                            selected: _gender == g,
                            onSelected: (_) => setState(() => _gender = g),
                          ),
                        ),
                      const Spacer(),
                      SizedBox(
                        width: 110,
                        child: PrimaryButton(
                          onPressed: _add,
                          label: "Ekle",
                          icon: Icons.add_rounded,
                          size: AppButtonSize.small,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: "Listem",
                    icon: Icons.list_alt_rounded,
                  ),
                ),
                FilterChip(
                  label: const Text("Favoriler"),
                  selected: _onlyFav,
                  avatar: Icon(Icons.star_rounded,
                      size: 16, color: _onlyFav ? p.warning : p.textMuted),
                  onSelected: (v) => setState(() => _onlyFav = v),
                ),
              ],
            ),
            StreamBuilder<List<BabyName>>(
              stream: _api.namesStream(),
              builder: (context, snapshot) {
                var items = snapshot.data ?? const <BabyName>[];
                if (_onlyFav) {
                  items = items.where((e) => e.isFavorite).toList();
                }
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.favorite_rounded,
                    title: _onlyFav ? "Favori isim yok" : "Henüz isim yok",
                    description: _onlyFav
                        ? "Yıldıza dokunarak favori ekleyebilirsin."
                        : "Beğendiğin bir isim ekleyerek başla.",
                  );
                }
                return Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final n in items)
                      Container(
                        padding:
                            const EdgeInsets.fromLTRB(AppSpacing.sm, 6, 4, 6),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: _genderColor(p, n.gender)
                                  .withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 8,
                              width: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _genderColor(p, n.gender),
                              ),
                            ),
                            Text(n.name,
                                style: TextStyle(
                                    color: p.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            const SizedBox(width: 4),
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  _api.setNameFavorite(n.id, !n.isFavorite),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  n.isFavorite
                                      ? Icons.star_rounded
                                      : Icons.star_outline_rounded,
                                  size: 18,
                                  color: n.isFavorite ? p.warning : p.textMuted,
                                ),
                              ),
                            ),
                            InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _api.deleteBabyName(n.id),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded,
                                    size: 16, color: p.textMuted),
                              ),
                            ),
                          ],
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
