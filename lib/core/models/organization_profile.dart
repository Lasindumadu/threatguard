enum OrganizationCategory {
  bank,
  telecom,
  government,
  delivery,
  ecommerce,
  financialService,
  other,
}

enum OrganizationVerificationSource {
  unknown,
  officialWebsite,
  officialRegistry,
  verifiedPartner,
}

class OrganizationProfile {
  final String id;
  final String name;
  final OrganizationCategory category;
  final List<String> senderPatterns;
  final List<String> officialDomains;
  final OrganizationVerificationSource verificationSource;

  const OrganizationProfile({
    required this.id,
    required this.name,
    required this.category,
    required this.senderPatterns,
    required this.officialDomains,
    required this.verificationSource,
  });
}
