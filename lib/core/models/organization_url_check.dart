enum OrganizationUrlConsistency { noUrl, consistent, inconsistent, unknown }

class OrganizationUrlCheck {
  final OrganizationUrlConsistency consistency;
  final String? organization;
  final String? url;
  final String? matchedDomain;

  const OrganizationUrlCheck({
    required this.consistency,
    required this.organization,
    required this.url,
    required this.matchedDomain,
  });
}
