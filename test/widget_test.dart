// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:civic_admin_app/main.dart';
import 'package:civic_admin_app/ae_dashboard/ae_login_screen.dart';

void main() {
  testWidgets('App loads AE login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ElectricityAdminApp(firebaseReady: false));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(AeLoginScreen), findsOneWidget);
  });
}
