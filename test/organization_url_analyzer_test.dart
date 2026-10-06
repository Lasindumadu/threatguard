import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/organization_url_check.dart';
import 'package:threatguard/core/services/organization_url_analyzer.dart';
import 'package:threatguard/core/services/sender_analyzer.dart';

void main() {
  const senderAnalyzer = SenderAnalyzer();
  const urlAnalyzer = OrganizationUrlAnalyzer();

  test('HNB sender with official HNB URL is consistent', () {
    final sender = senderAnalyzer.analyze('HNBPROMO');

    final result = urlAnalyzer.analyze(
      senderAnalysis: sender,
      urls: ['https://www.hnb.lk/offers'],
    );

    expect(result.consistency, OrganizationUrlConsistency.consistent);
    expect(result.organization, 'Hatton National Bank');
    expect(result.matchedDomain, 'hnb.lk');
  });

  test('HNB subdomain is consistent with official HNB domain', () {
    final sender = senderAnalyzer.analyze('HNBPROMO');

    final result = urlAnalyzer.analyze(
      senderAnalysis: sender,
      urls: ['https://secure.hnb.lk/login'],
    );

    expect(result.consistency, OrganizationUrlConsistency.consistent);
    expect(result.matchedDomain, 'hnb.lk');
  });

  test('HNB sender with unrelated domain is inconsistent', () {
    final sender = senderAnalyzer.analyze('HNBPROMO');

    final result = urlAnalyzer.analyze(
      senderAnalysis: sender,
      urls: ['https://hnb-login.example.com/verify'],
    );

    expect(result.consistency, OrganizationUrlConsistency.inconsistent);
    expect(result.matchedDomain, isNull);
  });

  test('HNB domain inside attacker domain is not accepted', () {
    final sender = senderAnalyzer.analyze('HNBPROMO');

    final result = urlAnalyzer.analyze(
      senderAnalysis: sender,
      urls: ['https://hnb.lk.attacker.com/login'],
    );

    expect(result.consistency, OrganizationUrlConsistency.inconsistent);
  });

  test('SLT-MOBITEL official domain is consistent', () {
    final sender = senderAnalyzer.analyze('SLT-Mobitel');

    final result = urlAnalyzer.analyze(
      senderAnalysis: sender,
      urls: ['https://sltmobitel.lk/services'],
    );

    expect(result.consistency, OrganizationUrlConsistency.consistent);
    expect(result.organization, 'SLT-MOBITEL');
    expect(result.matchedDomain, 'sltmobitel.lk');
  });

  test('unknown sender cannot establish organization URL consistency', () {
    final sender = senderAnalyzer.analyze('Free Calls');

    final result = urlAnalyzer.analyze(
      senderAnalysis: sender,
      urls: ['https://hutch.lk/offers'],
    );

    expect(result.consistency, OrganizationUrlConsistency.unknown);
    expect(result.organization, isNull);
  });

  test('no URL returns noUrl', () {
    final sender = senderAnalyzer.analyze('HNBPROMO');

    final result = urlAnalyzer.analyze(senderAnalysis: sender, urls: const []);

    expect(result.consistency, OrganizationUrlConsistency.noUrl);
    expect(result.organization, 'Hatton National Bank');
  });
}
