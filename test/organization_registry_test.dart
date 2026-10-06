import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/services/organization_registry.dart';

void main() {
  const registry = OrganizationRegistry();

  test('registry contains organization profiles', () {
    expect(registry.profiles, isNotEmpty);
  });

  test('HNB profile contains official domain', () {
    final profile = registry.profiles.firstWhere(
      (profile) => profile.id == 'hnb',
    );

    expect(profile.officialDomains, contains('hnb.lk'));
  });

  test('Hutch profile has no unverified sender identity', () {
    final profile = registry.profiles.firstWhere(
      (profile) => profile.id == 'hutch',
    );

    expect(profile.senderPatterns, isEmpty);
    expect(profile.officialDomains, contains('hutch.lk'));
  });

  test('SLT-MOBITEL profile contains official domain', () {
    final profile = registry.profiles.firstWhere(
      (profile) => profile.id == 'slt_mobitel',
    );

    expect(profile.officialDomains, contains('sltmobitel.lk'));
  });
}
