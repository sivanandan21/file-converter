import 'package:file_converter_admin/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin login screen renders', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Admin Panel'), findsOneWidget);
    expect(find.text('File Format Converter Dashboard'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
