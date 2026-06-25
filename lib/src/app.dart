import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'core/entry_flow_signal.dart';
import 'providers/auth_provider.dart';
import 'providers/premium_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/initial_setup_screen.dart';
import 'screens/main_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'theme/app_palette.dart';
import 'theme/app_tokens.dart';
import 'theme/theme_controller.dart';
import 'widgets/calm_background.dart';

class BabTrackerApp extends StatelessWidget {
  const BabTrackerApp({super.key, required this.themeController});

  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(ApiService(
              baseUrl: AppConfig.apiBaseUrl, localOnly: AppConfig.localOnly))
            ..initialize(),
        ),
        ChangeNotifierProxyProvider<AuthProvider, PremiumProvider>(
          create: (_) => PremiumProvider(),
          update: (_, auth, premium) =>
              (premium ?? PremiumProvider())..syncWithAuth(auth),
        ),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (context, theme, _) => MaterialApp(
          title: "Gebelik Takip",
          debugShowCheckedModeBanner: false,
          builder: (context, child) => CalmAppBackground(
            child: child ?? const SizedBox.shrink(),
          ),
          themeMode: theme.mode,
          theme: _buildTheme(AppPalette.light),
          darkTheme: _buildTheme(AppPalette.dark),
          home: const _RootRouter(),
        ),
      ),
    );
  }

  TextTheme _buildTextTheme(AppPalette p) {
    final text = TextStyle(color: p.textPrimary);
    return TextTheme(
      displayLarge: text.copyWith(
          fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
      displayMedium: text.copyWith(
          fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.3),
      headlineLarge: text.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium: text.copyWith(fontSize: 21, fontWeight: FontWeight.w700),
      headlineSmall: text.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      titleLarge: text.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      titleMedium: text.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
      titleSmall: text.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
      bodyLarge: text.copyWith(fontSize: 15, height: 1.45),
      bodyMedium: text.copyWith(fontSize: 13.5, height: 1.45),
      bodySmall:
          text.copyWith(fontSize: 12.5, color: p.textSecondary, height: 1.4),
      labelLarge: text.copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
      labelMedium: text.copyWith(
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3),
      labelSmall: text.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: p.textMuted,
          letterSpacing: 0.3),
    );
  }

  ThemeData _buildTheme(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: p.brightness,
    ).copyWith(
      primary: p.primary,
      onPrimary: p.textOnPrimary,
      secondary: p.accent,
      onSecondary: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.surfaceHigh,
      outline: p.border,
      outlineVariant: p.borderSoft,
      error: p.danger,
    );
    final textTheme = _buildTextTheme(p);

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: p.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textPrimary,
          backgroundColor: p.surface.withValues(alpha: 0.6),
          shape: const CircleBorder(),
        ),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.borderSoft, width: 1),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.bgElevated,
        indicatorColor: p.primary.withValues(alpha: 0.20),
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dividerTheme: DividerThemeData(
        color: p.borderSoft,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          elevation: 0,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.borderStrong, width: 1.2),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.primary,
          textStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceHigh,
        selectedColor: p.primary.withValues(alpha: 0.22),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
          fontSize: 12.5,
        ),
        shape: StadiumBorder(side: BorderSide(color: p.borderSoft)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor:
            p.isDark ? p.bgElevated.withValues(alpha: 0.85) : p.surfaceHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: p.danger, width: 1.4),
        ),
        labelStyle: TextStyle(color: p.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
        prefixIconColor: p.textMuted,
        suffixIconColor: p.textMuted,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.surfaceHigh,
        circularTrackColor: p.surfaceHigh,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.primarySoft,
        textColor: p.textPrimary,
        titleTextStyle: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 12.5,
          color: p.textMuted,
          height: 1.4,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return p.primary.withValues(alpha: 0.55);
          }
          return p.surfaceHigh;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return p.primary;
          return p.textMuted;
        }),
        trackOutlineColor: WidgetStateProperty.all(p.borderSoft),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.isDark ? p.surfaceHigh : p.textPrimary,
        contentTextStyle: TextStyle(
          color: p.isDark ? p.textPrimary : Colors.white,
          fontSize: 13.5,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: p.borderSoft),
        ),
        titleTextStyle: TextStyle(
          color: p.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
        contentTextStyle: TextStyle(
          color: p.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.bgElevated,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.bgElevated,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        dragHandleColor: p.borderStrong,
      ),
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: p.textPrimary,
        unselectedLabelColor: p.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        dividerColor: Colors.transparent,
      ),
    );
  }
}

enum _EntryStage {
  onboarding,
  auth,
  setup,
  home,
}

class _RootRouter extends StatefulWidget {
  const _RootRouter();

  @override
  State<_RootRouter> createState() => _RootRouterState();
}

class _RootRouterState extends State<_RootRouter> {
  bool _loading = true;
  _EntryStage _stage = _EntryStage.onboarding;
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    EntryFlowSignal.tick.addListener(_loadEntryState);
    _loadEntryState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (_authProvider == auth) return;
    _authProvider?.removeListener(_loadEntryState);
    _authProvider = auth;
    _authProvider?.addListener(_loadEntryState);
    _loadEntryState();
  }

  @override
  void dispose() {
    EntryFlowSignal.tick.removeListener(_loadEntryState);
    _authProvider?.removeListener(_loadEntryState);
    super.dispose();
  }

  Future<void> _loadEntryState() async {
    final auth = context.read<AuthProvider>();
    if (auth.initializing) {
      if (mounted && !_loading) {
        setState(() => _loading = true);
      }
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding =
        prefs.getBool(AppConfig.seenOnboardingKey) ?? false;
    final storedAuthStep = prefs.getBool(AppConfig.authStepDoneKey) ?? false;
    final hasCompletedSetup =
        prefs.getBool(AppConfig.firstSetupDoneKey) ?? false;
    final hasUserSession = auth.currentUser != null;
    final hasCompletedAuth = hasUserSession;

    if (storedAuthStep != hasCompletedAuth) {
      await prefs.setBool(AppConfig.authStepDoneKey, hasCompletedAuth);
    }

    if (!mounted) return;
    setState(() {
      _stage = _resolveStage(
        seenOnboarding: hasSeenOnboarding,
        completedAuth: hasCompletedAuth,
        completedSetup: hasCompletedSetup,
      );
      _loading = false;
    });
  }

  _EntryStage _resolveStage({
    required bool seenOnboarding,
    required bool completedAuth,
    required bool completedSetup,
  }) {
    if (!seenOnboarding) return _EntryStage.onboarding;
    if (!completedAuth) return _EntryStage.auth;
    if (!completedSetup) return _EntryStage.setup;
    return _EntryStage.home;
  }

  Future<void> _handleOnboardingFinished() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.seenOnboardingKey, true);
    if (!mounted) return;
    setState(() => _stage = _EntryStage.auth);
  }

  Future<void> _handleAuthCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.guestModeKey, false);
    await prefs.setBool(AppConfig.authStepDoneKey, true);
    final hasCompletedSetup =
        prefs.getBool(AppConfig.firstSetupDoneKey) ?? false;
    if (!mounted) return;
    setState(() =>
        _stage = hasCompletedSetup ? _EntryStage.home : _EntryStage.setup);
  }

  Future<void> _handleSetupCompleted(InitialSetupData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.caregiverRoleKey, data.caregiverRole);
    await prefs.setString(AppConfig.babyNameKey, data.babyName);
    await prefs.setString(AppConfig.babyCityKey, data.city);

    Future<void> writeDate(String key, DateTime? value) async {
      if (value == null) {
        await prefs.remove(key);
      } else {
        await prefs.setInt(key, value.millisecondsSinceEpoch);
      }
    }

    await writeDate(AppConfig.babyBirthDateKey, data.birthDate);
    await writeDate(AppConfig.lastPeriodStartKey, data.lastPeriodStart);
    await writeDate(AppConfig.estimatedDueDateKey, data.estimatedDueDate);
    await prefs.setBool(AppConfig.planningBabyKey, data.planningBaby);
    if (data.maternalChronicCondition != null &&
        data.maternalChronicCondition!.trim().isNotEmpty) {
      await prefs.setString(
        AppConfig.maternalChronicKey,
        data.maternalChronicCondition!.trim(),
      );
    } else {
      await prefs.remove(AppConfig.maternalChronicKey);
    }
    await prefs.setBool(AppConfig.firstSetupDoneKey, true);

    if (mounted) {
      final api = context.read<AuthProvider>().api;
      await api.syncProfileToBackend();
    }

    if (!mounted) return;
    setState(() => _stage = _EntryStage.home);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (_stage) {
      case _EntryStage.onboarding:
        return OnboardingScreen(onFinished: _handleOnboardingFinished);
      case _EntryStage.auth:
        return AuthScreen(
          onCompleted: _handleAuthCompleted,
          showSkipAction: false,
        );
      case _EntryStage.setup:
        return InitialSetupScreen(onCompleted: _handleSetupCompleted);
      case _EntryStage.home:
        return const MainShell();
    }
  }
}
