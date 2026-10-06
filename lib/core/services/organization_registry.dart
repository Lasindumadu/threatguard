import '../models/organization_profile.dart';

class OrganizationRegistry {
  const OrganizationRegistry();

  List<OrganizationProfile> get profiles => const [
    OrganizationProfile(
      id: 'hnb',
      name: 'Hatton National Bank',
      category: OrganizationCategory.bank,
      senderPatterns: ['hnbpromo'],
      officialDomains: ['hnb.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'hutch',
      name: 'Hutch',
      category: OrganizationCategory.telecom,
      senderPatterns: [],
      officialDomains: ['hutch.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'slt_mobitel',
      name: 'SLT-MOBITEL',
      category: OrganizationCategory.telecom,
      senderPatterns: ['slt-mobitel'],
      officialDomains: ['sltmobitel.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
  ];
}
