import 'package:flutter_test/flutter_test.dart';

import 'package:mon_coloc/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    // Note: This test will work if Firebase is properly initialized.
    // If Firebase is not available, the app will still build.
    await tester.pumpWidget(const MonColocApp());

    // The initial screen should be a loading indicator or login screen
    // depending on Firebase initialization status
  });
}