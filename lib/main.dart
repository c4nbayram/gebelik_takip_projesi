import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/services/notification_service.dart';
import 'src/services/supabase_client.dart';
import 'src/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
  }

  await initializeDateFormatting('tr_TR', null);
  await SupabaseBootstrap.ensureInitialized();

  try {
    await NotificationService.instance.init();
  } catch (_) {}

  final themeController = ThemeController();
  await themeController.load();

  runApp(BabTrackerApp(themeController: themeController));
}
