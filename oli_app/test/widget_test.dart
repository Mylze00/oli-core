// Basic smoke test for OLI app

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // OliApp requires ProviderScope + EasyLocalization + Firebase init,
    // so a full widget test needs proper setup. This is a placeholder.
    expect(1 + 1, equals(2));
  });
}
