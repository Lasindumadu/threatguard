import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/models/threat_analysis.dart';
import 'package:threatguard/core/models/threat_message.dart';
import 'package:threatguard/core/services/fake_sms_message_source.dart';
import 'package:threatguard/core/services/threat_engine.dart';
import 'package:threatguard/core/theme/app_theme.dart';
import 'package:threatguard/features/sms/application/inbox_controller.dart';
import 'package:threatguard/main.dart';

void main() {
  testWidgets('app boots on the dashboard with all navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const ThreatGuardApp());
    await tester.pump(const Duration(milliseconds: 600));

    // The app must not open straight into a bare permission prompt; the
    // dashboard is the product's front door.
    expect(find.text('ThreatGuard'), findsWidgets);

    // All five destinations of the security console must be reachable.
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Inbox'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    expect(find.text('Tools'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('the Tools tab lists the security toolkits', (tester) async {
    await tester.pumpWidget(const ThreatGuardApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Tools'));
    await tester.pumpAndSettle();

    // These are the tools that make this a security app rather than a message
    // classifier; if any becomes unreachable this test fails. The list scrolls,
    // so each target is scrolled into view before asserting.
    for (final title in [
      'Link scanner',
      'Password audit',
      'Breach check',
      'Device posture',
      'Threat awareness',
    ]) {
      final target = find.text(title);

      await tester.scrollUntilVisible(
        target,
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(target, findsOneWidget, reason: '$title must be reachable');
    }
  });

  testWidgets('the Shield tab exposes detection sensitivity', (tester) async {
    await tester.pumpWidget(const ThreatGuardApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Shield'));
    await tester.pumpAndSettle();

    expect(find.text('Protection active'), findsOneWidget);
    expect(find.text('Detection sensitivity'), findsOneWidget);
  });

  testWidgets('settings screen exposes the privacy guarantee', (tester) async {
    await tester.pumpWidget(const ThreatGuardApp());
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Your messages stay on your device'), findsOneWidget);

    // Detection sensitivity lives on the Shield tab, where the thresholds it
    // changes are displayed beside it. Settings must link there rather than
    // carry a second, divergent control.
    expect(find.text('Detection sensitivity'), findsOneWidget);
  });

  group('design system', () {
    test('every threat level maps to a distinct colour', () {
      final colours = {
        for (final level in ThreatLevel.values) AppTheme.levelColor(level),
      };

      expect(colours.length, ThreatLevel.values.length);
    });

    test('every threat type maps to a distinct colour', () {
      final colours = {
        for (final type in ThreatType.values) AppTheme.typeColor(type),
      };

      expect(colours.length, ThreatType.values.length);
    });

    test('both themes build without error', () {
      expect(AppTheme.light().brightness, Brightness.light);
      expect(AppTheme.dark().brightness, Brightness.dark);
    });
  });

  group('InboxController', () {
    test('caches reports instead of re-analysing on every read', () {
      final controller = InboxController(engine: ThreatEngine.instance);

      const messages = [
        ThreatMessage(
          id: 'cached_1',
          body: 'Your account is suspended, verify your password immediately.',
          sender: 'TestBank',
          source: MessageSource.sms,
        ),
      ];

      controller.addMessage(messages.first);

      final first = controller.reports;
      final second = controller.reports;

      // Same object identity proves the memoisation is working.
      expect(identical(first.first, second.first), isTrue);

      controller.dispose();
    });

    test('demo source provides analysable messages', () async {
      final messages = await const FakeSmsMessageSource().readMessages();
      expect(messages, isNotEmpty);

      final engine = ThreatEngine.instance;
      final reports = engine.analyzeAll(messages);

      expect(reports.length, messages.length);
      expect(reports.every((r) => r.analysis.ruleAnalysis.riskScore >= 0), isTrue);
    });
  });
}
