import '../models/organization_profile.dart';
import '../models/organization_url_check.dart';
import '../models/sender_analysis.dart';
import 'organization_registry.dart';

class OrganizationUrlAnalyzer {
  final OrganizationRegistry registry;

  const OrganizationUrlAnalyzer({this.registry = const OrganizationRegistry()});

  OrganizationUrlCheck analyze({
    required SenderAnalysis senderAnalysis,
    required List<String> urls,
  }) {
    if (urls.isEmpty) {
      return OrganizationUrlCheck(
        consistency: OrganizationUrlConsistency.noUrl,
        organization: senderAnalysis.organization,
        url: null,
        matchedDomain: null,
      );
    }

    final organizationName = senderAnalysis.organization;

    if (organizationName == null) {
      return const OrganizationUrlCheck(
        consistency: OrganizationUrlConsistency.unknown,
        organization: null,
        url: null,
        matchedDomain: null,
      );
    }

    final profile = _findProfile(organizationName);

    if (profile == null) {
      return OrganizationUrlCheck(
        consistency: OrganizationUrlConsistency.unknown,
        organization: organizationName,
        url: urls.first,
        matchedDomain: null,
      );
    }

    for (final url in urls) {
      final host = _extractHost(url);

      if (host == null) {
        continue;
      }

      for (final domain in profile.officialDomains) {
        if (_matchesDomain(host, domain)) {
          return OrganizationUrlCheck(
            consistency: OrganizationUrlConsistency.consistent,
            organization: organizationName,
            url: url,
            matchedDomain: domain,
          );
        }
      }
    }

    return OrganizationUrlCheck(
      consistency: OrganizationUrlConsistency.inconsistent,
      organization: organizationName,
      url: urls.first,
      matchedDomain: null,
    );
  }

  OrganizationProfile? _findProfile(String organizationName) {
    for (final profile in registry.profiles) {
      if (profile.name == organizationName) {
        return profile;
      }
    }

    return null;
  }

  String? _extractHost(String url) {
    final uri = Uri.tryParse(url);

    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    return uri.host.toLowerCase();
  }

  bool _matchesDomain(String host, String officialDomain) {
    final normalizedDomain = officialDomain.toLowerCase();

    return host == normalizedDomain || host.endsWith('.$normalizedDomain');
  }
}
