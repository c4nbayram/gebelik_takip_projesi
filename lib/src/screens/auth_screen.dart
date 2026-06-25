import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import '../widgets/app_card.dart';
import '../widgets/app_text_field.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.onCompleted,
    this.onSkip,
    this.showSkipAction = false,
  });

  final VoidCallback? onCompleted;
  final VoidCallback? onSkip;
  final bool showSkipAction;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _pass = TextEditingController();
  bool _obscurePassword = true;
  int _tab = 0;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    final isLogin = _tab == 0;
    final mail = _email.text.trim();
    final pass = _pass.text;
    if (!isLogin && _name.text.trim().isEmpty) {
      _showError("Lutfen adinizi girin.");
      return;
    }
    if (mail.isEmpty || pass.isEmpty) {
      _showError("E-posta ve sifre zorunludur.");
      return;
    }

    bool ok;
    if (isLogin) {
      ok = await auth.login(mail, pass);
    } else {
      ok = await auth.register(_name.text.trim(), mail, pass);
    }

    if (!mounted) return;
    if (ok) {
      widget.onCompleted?.call();
      return;
    }
    if (auth.error != null) {
      _showError(auth.error!);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.palette.dangerBg.withValues(alpha: 0.95),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isLogin = _tab == 0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xs),
              _HeaderHero(theme: theme, isLogin: isLogin),
              const SizedBox(height: AppSpacing.lg),
              _segmentedTab(),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isLogin) ...[
                      AppTextField(
                        controller: _name,
                        label: "Ad Soyad",
                        prefixIcon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    AppTextField(
                      controller: _email,
                      label: "E-posta",
                      prefixIcon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    AppTextField(
                      controller: _pass,
                      label: "Sifre",
                      prefixIcon: Icons.lock_outline_rounded,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: context.palette.textMuted,
                          size: 20,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    if (isLogin) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GhostButton(
                          onPressed: () {},
                          label: "Sifreni mi unuttun?",
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      onPressed: auth.busy ? null : () => _submit(auth),
                      label: isLogin ? "Giris Yap" : "Hesap Olustur",
                      icon: isLogin
                          ? Icons.login_rounded
                          : Icons.person_add_alt_1_rounded,
                      loading: auth.busy,
                      size: AppButtonSize.large,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.showSkipAction)
                Center(
                  child: TextButton.icon(
                    onPressed: widget.onSkip ?? widget.onCompleted,
                    icon: Icon(Icons.arrow_forward_rounded,
                        size: 16, color: context.palette.textSecondary),
                    label: Text(
                      "Simdilik atla",
                      style: TextStyle(color: context.palette.textSecondary),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              _privacyNote(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmentedTab() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.palette.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: context.palette.borderSoft),
      ),
      child: Row(
        children: [
          _tabButton(label: "Giris", index: 0),
          _tabButton(label: "Kayit", index: 1),
        ],
      ),
    );
  }

  Widget _tabButton({required String label, required int index}) {
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 42,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(colors: context.palette.brandGradient)
                : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            boxShadow: selected
                ? AppShadows.glow(context.palette.primary, strength: 0.25)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : context.palette.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  Widget _privacyNote() {
    return Row(
      children: [
        Icon(Icons.shield_outlined, size: 14, color: context.palette.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            "Bilgilerin yalnizca uygulamada saklanir ve guvende tutulur.",
            style: TextStyle(
              color: context.palette.textMuted,
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderHero extends StatelessWidget {
  const _HeaderHero({required this.theme, required this.isLogin});
  final ThemeData theme;
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return GradientHeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(Icons.favorite_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLogin ? "Tekrar hos geldin" : "Hesabini olustur",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLogin
                          ? "Yolculugunu kaldigin yerden surdur."
                          : "Takibi baslatmak icin birkac adim kaldi.",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
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
    );
  }
}
