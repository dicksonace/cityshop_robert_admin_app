import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cityshop_admin/screens/auth_screens.dart';
import 'package:cityshop_admin/theme/app_theme.dart';

void main() {
  testWidgets('login screen shows admin branding', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const LoginScreen(),
      ),
    );

    expect(find.text('CityShop Admin'), findsOneWidget);
    expect(find.text('Login as admin'), findsOneWidget);
  });
}
