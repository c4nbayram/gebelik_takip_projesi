import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';

class BabTrackerApp extends StatelessWidget {
  const BabTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(ApiService(baseUrl: AppConfig.apiBaseUrl))..initialize(),
      child: MaterialApp(
        title: "Gebelik Takip",
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF3A5A98),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF5F7FF),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF3A5A98),
            foregroundColor: Colors.white,
          ),
        ),
        home: const _RootRouter(),
      ),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.initializing) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (auth.currentUser == null) {
          return const AuthScreen();
        }
        return const MainShell();
      },
    );
  }
}

