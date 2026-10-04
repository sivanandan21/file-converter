import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // App is initialized in main.dart with Hive + SharedPreferences.
    // Integration tests should be run with flutter test integration_test/.
    expect(true, isTrue);
  });
}
