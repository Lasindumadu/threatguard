import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/main.dart';

void main() {
  testWidgets('ThreatGuard app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ThreatGuardApp());

    expect(find.text('Message Threat Analyzer'), findsOneWidget);
    expect(find.text('Analyze Message'), findsOneWidget);
  });
}
