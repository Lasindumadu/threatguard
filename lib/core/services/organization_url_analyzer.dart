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

    String? firstUnmatchedUrl;

    for (final url in urls) {
      final host = _extractHost(url);

      if (host == null) {
        return OrganizationUrlCheck(
          consistency: OrganizationUrlConsistency.inconsistent,
          organization: organizationName,
          url: url,
          matchedDomain: null,
        );
      }

      String? matchedDomain;

      for (final domain in profile.officialDomains) {
        if (_matchesDomain(host, domain)) {
          matchedDomain = domain;
          break;
        }
      }

      if (matchedDomain == null) {
        firstUnmatchedUrl ??= url;
        continue;
      }
    }

    if (firstUnmatchedUrl != null) {
      return OrganizationUrlCheck(
        consistency: OrganizationUrlConsistency.inconsistent,
        organization: organizationName,
        url: firstUnmatchedUrl,
        matchedDomain: null,
      );
    }

    final firstUrl = urls.first;
    final firstHost = _extractHost(firstUrl);

    String? matchedDomain;

    if (firstHost != null) {
      for (final domain in profile.officialDomains) {
        if (_matchesDomain(firstHost, domain)) {
          matchedDomain = domain;
          break;
        }
      }
    }

    return OrganizationUrlCheck(
      consistency: OrganizationUrlConsistency.consistent,
      organization: organizationName,
      url: firstUrl,
      matchedDomain: matchedDomain,
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
    final trimmed = url.trim();

    final uri = Uri.tryParse(
      trimmed.contains('://') ? trimmed : 'https://$trimmed',
    );

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
