import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_buttons.dart';
import 'entry_flow_signal.dart';

Future<bool> ensureSignedIn(
  BuildContext context, {
  String reason = "Bu özelliği kullanmak için bir hesabın olması gerekiyor.",
}) async {
  final auth = context.read<AuthProvider>();
  if (auth.currentUser != null) return true;

  final signedIn = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.bgBase,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (sheetContext) => _GuestPromptSheet(reason: reason),
  );

  return signedIn == true && context.mounted && auth.currentUser != null;
}

class _GuestPromptSheet extends StatelessWidget {
  const _GuestPromptSheet({required this.reason});

  final String reason;

  Future<void> _openAuth(BuildContext context) async {
    final navigator = Navigator.of(context);
    final completed = await navigator.push<bool>(
      MaterialPageRoute(
        builder: (routeContext) => AuthScreen(
          showSkipAction: false,
          onCompleted: () => Navigator.of(routeContext).pop(true),
        ),
      ),
    );
    if (completed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConfig.guestModeKey, false);
      await prefs.setBool(AppConfig.authStepDoneKey, true);
      EntryFlowSignal.notifyChanged();
    }
    navigator.pop(completed == true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.xs,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: p.brandGradient),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: p.glow(p.primary, strength: 0.3),
              ),
              child: const Icon(Icons.lock_open_rounded,
                  color: Colors.white, size: 30),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            "Giriş yapman gerekiyor",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "$reason Misafir modunda verilerin kaydedilmez.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            onPressed: () => _openAuth(context),
            label: "Giriş Yap / Kayıt Ol",
            icon: Icons.login_rounded,
            size: AppButtonSize.large,
          ),
          const SizedBox(height: AppSpacing.xs),
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            label: "Vazgeç",
            icon: Icons.close_rounded,
          ),
        ],
      ),
    );
  }
}
