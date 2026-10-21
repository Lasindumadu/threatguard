import '../models/organization_profile.dart';

class OrganizationRegistry {
  const OrganizationRegistry();

  List<OrganizationProfile> get profiles => const [
    // ------------------------------------------------------------ banking
    OrganizationProfile(
      id: 'hnb',
      name: 'Hatton National Bank',
      category: OrganizationCategory.bank,
      senderPatterns: ['hnbpromo', 'hnb'],
      officialDomains: ['hnb.lk', 'hnbnet.com'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'commercial_bank',
      name: 'Commercial Bank of Ceylon',
      category: OrganizationCategory.bank,
      senderPatterns: ['combank', 'commercialbank'],
      officialDomains: ['combank.lk', 'combank.net'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'sampath_bank',
      name: 'Sampath Bank',
      category: OrganizationCategory.bank,
      senderPatterns: ['sampathbank'],
      officialDomains: ['sampath.lk', 'sampathbank.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'seylan_bank',
      name: 'Seylan Bank',
      category: OrganizationCategory.bank,
      senderPatterns: ['seylanbank'],
      officialDomains: ['seylan.lk', 'seylanbank.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'boc',
      name: 'Bank of Ceylon',
      category: OrganizationCategory.bank,
      senderPatterns: ['boc', 'bankofceylon'],
      officialDomains: ['boc.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),

    // ------------------------------------------------------------ telecoms
    OrganizationProfile(
      id: 'hutch',
      name: 'Hutch',
      category: OrganizationCategory.telecom,
      // Deliberately empty: a sender-name match is only asserted for profiles
      // backed by a verified partner. Hutch is only verified via its website,
      // so claiming to recognise "hutch" as a sender would be misleading.
      senderPatterns: [],
      officialDomains: ['hutch.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'slt_mobitel',
      name: 'SLT-MOBITEL',
      category: OrganizationCategory.telecom,
      senderPatterns: ['slt-mobitel', 'mobitel'],
      officialDomains: ['sltmobitel.lk', 'mobitel.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'dialog',
      name: 'Dialog Axiata',
      category: OrganizationCategory.telecom,
      senderPatterns: ['dialog', 'dialogaxiata'],
      officialDomains: ['dialog.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),
    OrganizationProfile(
      id: 'airtel',
      name: 'Airtel',
      category: OrganizationCategory.telecom,
      senderPatterns: ['airtel'],
      officialDomains: ['airtel.lk', 'airtel.in'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),

    // --------------------------------------------------------- government
    OrganizationProfile(
      id: 'ird',
      name: 'Inland Revenue Department',
      category: OrganizationCategory.government,
      senderPatterns: ['ird', 'irdepartment'],
      officialDomains: ['ird.gov.lk'],
      verificationSource: OrganizationVerificationSource.officialRegistry,
    ),
    OrganizationProfile(
      id: 'gov_services',
      name: 'Government Services Portal',
      category: OrganizationCategory.government,
      senderPatterns: [],
      officialDomains: ['gov.lk'],
      verificationSource: OrganizationVerificationSource.officialRegistry,
    ),

    // ----------------------------------------------------------- delivery
    OrganizationProfile(
      id: 'dhl',
      name: 'DHL',
      category: OrganizationCategory.delivery,
      senderPatterns: ['dhl'],
      officialDomains: ['dhl.com', 'dhl.lk'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
    OrganizationProfile(
      id: 'fedex',
      name: 'FedEx',
      category: OrganizationCategory.delivery,
      senderPatterns: ['fedex'],
      officialDomains: ['fedex.com'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
    OrganizationProfile(
      id: 'sl_post',
      name: 'Sri Lanka Post',
      category: OrganizationCategory.delivery,
      senderPatterns: ['slpost'],
      officialDomains: ['slpost.lk'],
      verificationSource: OrganizationVerificationSource.officialWebsite,
    ),

    // ------------------------------------------------------ global tech
    OrganizationProfile(
      id: 'google',
      name: 'Google',
      category: OrganizationCategory.other,
      senderPatterns: ['google'],
      officialDomains: ['google.com', 'accounts.google.com'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
    OrganizationProfile(
      id: 'microsoft',
      name: 'Microsoft',
      category: OrganizationCategory.other,
      senderPatterns: ['microsoft'],
      officialDomains: ['microsoft.com', 'account.microsoft.com'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
    OrganizationProfile(
      id: 'apple',
      name: 'Apple',
      category: OrganizationCategory.other,
      senderPatterns: ['apple'],
      officialDomains: ['apple.com'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
    OrganizationProfile(
      id: 'amazon',
      name: 'Amazon',
      category: OrganizationCategory.ecommerce,
      senderPatterns: ['amazon'],
      officialDomains: ['amazon.com', 'amazon.co.uk'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
    OrganizationProfile(
      id: 'paypal',
      name: 'PayPal',
      category: OrganizationCategory.financialService,
      senderPatterns: ['paypal'],
      officialDomains: ['paypal.com'],
      verificationSource: OrganizationVerificationSource.verifiedPartner,
    ),
  ];
}
