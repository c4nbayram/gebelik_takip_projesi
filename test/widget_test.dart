// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gebelik_bebek_takip/src/app.dart';
import 'package:gebelik_bebek_takip/src/theme/theme_controller.dart';

void main() {
  testWidgets('Uygulama temel olarak açılabilmeli',
      (WidgetTester tester) async {
    await tester.pumpWidget(BabTrackerApp(themeController: ThemeController()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
