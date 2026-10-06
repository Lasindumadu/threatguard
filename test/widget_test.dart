import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/main.dart';

void main() {
  testWidgets('ThreatGuard app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThreatGuardApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('SMS Inbox'), findsOneWidget);
  });
}
