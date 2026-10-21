import 'impersonation_detector.dart';
import 'url_analyzer.dart';
import '../models/url_analysis.dart';

/// Deep, explainable inspection of a single URL.
///
/// This is the engine behind the Link Scanner screen and the pre-flight
/// interstitial. It answers the question a user actually has — *"is this link
/// safe?"* — with a score and a list of concrete reasons, not a bare colour.
class UrlForensics {
  final String rawUrl;
  final String host;
  final String? registrableDomain;
  final String? subdomain;
  final String? publicSuffix;
  final String scheme;
  final int? port;

  /// The path + query, shown separately so a user can see what is being hidden
  /// behind a shortener or a long query string.
  final String path;
  final String? query;

  final bool isHttps;
  final bool isShortener;
  final bool isIpHost;
  final bool hasPunycode;
  final bool hasMixedScript;
  final bool hasEmbeddedCredentials;
  final int subdomainCount;

  final List<UrlFinding> findings;
  final ImpersonationCheck? impersonation;

  const UrlForensics({
    required this.rawUrl,
    required this.host,
    required this.registrableDomain,
    required this.subdomain,
    required this.publicSuffix,
    required this.scheme,
    required this.port,
    required this.path,
    required this.query,
    required this.isHttps,
    required this.isShortener,
    required this.isIpHost,
    required this.hasPunycode,
    required this.hasMixedScript,
    required this.hasEmbeddedCredentials,
    required this.subdomainCount,
    required this.findings,
    required this.impersonation,
  });

  /// 0..100 risk score for this link alone.
  int get riskScore {
    var score = findings.fold<int>(0, (sum, f) => sum + f.weight);
    if (impersonation != null) score += impersonation!.riskContribution;
    return score.clamp(0, 100);
  }

  LinkSafetyGrade get grade {
    if (findings.any((f) => f.severity == UrlFindingSeverity.critical)) {
      return LinkSafetyGrade.dangerous;
    }
    if (riskScore >= 45) return LinkSafetyGrade.dangerous;
    if (riskScore >= 20) return LinkSafetyGrade.suspicious;
    return LinkSafetyGrade.looksSafe;
  }

  bool get isConcerning => grade != LinkSafetyGrade.looksSafe;

  /// The address a user should actually read: registrable domain + path.
  String get displayAddress {
    final domainPart = registrableDomain ?? host;
    return '$domainPart$path${query == null ? '' : '?$query'}';
  }
}

enum LinkSafetyGrade { looksSafe, suspicious, dangerous }

enum UrlFindingSeverity { info, warning, critical }

class UrlFinding {
  final UrlFindingSeverity severity;
  final String title;
  final String detail;
  final int weight;

  const UrlFinding({
    required this.severity,
    required this.title,
    required this.detail,
    required this.weight,
  });
}

/// Decomposes a URL and explains what is wrong with it.
class UrlForensicsAnalyzer {
  const UrlForensicsAnalyzer({
    this.urlAnalyzer = const UrlAnalyzer(),
    this.impersonationDetector = const ImpersonationDetector(),
  });

  final UrlAnalyzer urlAnalyzer;
  final ImpersonationDetector impersonationDetector;

  /// A host must look like a host: labels of letters/digits/hyphens separated
  /// by dots, at least one dot, and a plausible TLD.
  ///
  /// Without this, `Uri.tryParse('https://this is not a url')` happily returns
  /// a "host" and prose gets treated as a link.
  static final RegExp _hostPattern = RegExp(
    r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?'
    r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
  );

  static final RegExp _tldPattern = RegExp(r'^[a-z]{2,}$');

  /// TLDs with a very high abuse rate. Not a verdict on their own — a `.top`
  /// domain is not malicious — but a meaningful prior when combined with other
  /// signals, which is why they carry a small weight.
  static const _highAbuseTlds = {
    'top',
    'xyz',
    'click',
    'link',
    'work',
    'gq',
    'tk',
    'cf',
    'ml',
    'ga',
    'buzz',
    'rest',
    'country',
    'stream',
    'download',
    'loan',
    'win',
    'bid',
    'review',
    'surf',
    'bar',
    'casa',
    'icu',
  };

  /// Second-level suffixes that need two labels to reach the registrable name.
  static const _twoPartSuffixes = {
    'co.uk',
    'com.au',
    'co.jp',
    'co.in',
    'com.br',
    'co.za',
    'com.my',
    'co.nz',
    'com.sg',
    'org.uk',
    'gov.lk',
    'com.lk',
    'org.lk',
    'net.lk',
  };

  static const _shorteners = {
    'bit.ly',
    'tinyurl.com',
    't.co',
    'goo.gl',
    'ow.ly',
    'is.gd',
    'buff.ly',
    'cutt.ly',
    'shorturl.at',
    'rebrand.ly',
    't.ly',
    'rb.gy',
    'tiny.cc',
    'shorte.st',
    'adf.ly',
    'bit.do',
    's.id',
    'clck.ru',
    'v.gd',
  };

  UrlForensics analyze(String url) {
    final raw = url.trim();

    // Normalise to something Uri can parse, without inventing a scheme we then
    // report back to the user as if it were real.
    final hasScheme = raw.contains('://');
    final uriInput = hasScheme ? raw : 'https://$raw';
    final uri = Uri.tryParse(uriInput);

    if (uri == null || uri.host.isEmpty || !_looksLikeHost(uri.host)) {
      return UrlForensics(
        rawUrl: raw,
        host: '',
        registrableDomain: null,
        subdomain: null,
        publicSuffix: null,
        scheme: '',
        port: null,
        path: '',
        query: null,
        isHttps: false,
        isShortener: false,
        isIpHost: false,
        hasPunycode: false,
        hasMixedScript: false,
        hasEmbeddedCredentials: false,
        subdomainCount: 0,
        findings: const [
          UrlFinding(
            severity: UrlFindingSeverity.info,
            title: 'Not a valid URL',
            detail: 'This text could not be parsed as a web address.',
            weight: 0,
          ),
        ],
        impersonation: null,
      );
    }

    final host = uri.host.toLowerCase();
    final scheme = hasScheme ? uri.scheme.toLowerCase() : '(none)';
    final isHttps = hasScheme && scheme == 'https';

    // Reuse the structural analyser so the link scanner and the message
    // analyser can never disagree about the same URL.
    final structural = urlAnalyzer.analyze(raw);
    final signalTypes = structural.signals.map((s) => s.type).toSet();

    final parts = _splitHost(host);
    final registrable = parts.registrable;
    final tld = parts.suffix;

    final impersonation = registrable == null || _isIpLiteral(host)
        ? null
        : impersonationDetector.check(host);

    final findings = <UrlFinding>[];

    // ---------------------------------------------------------------- scheme
    if (hasScheme && !isHttps) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.warning,
          title: 'Not encrypted (HTTP)',
          detail:
              'This link uses plain HTTP, so anything you type — including a '
              'password — can be read or altered in transit.',
          weight: 22,
        ),
      );
    }

    if (!hasScheme) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.info,
          title: 'No scheme given',
          detail:
              'The link was written without http:// or https://. Browsers '
              'usually assume HTTPS, but the true destination is unconfirmed.',
          weight: 6,
        ),
      );
    }

    // ------------------------------------------------------------ IP literal
    if (signalTypes.contains(UrlSignalType.ipAddressHost)) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.critical,
          title: 'Raw IP address instead of a domain',
          detail:
              'Legitimate services almost always use a domain name. A raw IP '
              'address is a strong indicator of phishing infrastructure, '
              'because it cannot hold a valid TLS certificate for a brand.',
          weight: 45,
        ),
      );
    }

    // -------------------------------------------------------------- punycode
    if (signalTypes.contains(UrlSignalType.punycodeHost)) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.critical,
          title: 'Punycode-encoded domain',
          detail:
              'The domain uses encoded international characters, a technique '
              'used to make a fake domain look identical to a real one.',
          weight: 30,
        ),
      );
    }

    if (signalTypes.contains(UrlSignalType.mixedScriptHost)) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.critical,
          title: 'Mixed-alphabet domain',
          detail:
              'The domain mixes letter alphabets (for example Latin and '
              'Cyrillic), which is a homograph attack that displays like a '
              'trusted brand but resolves elsewhere.',
          weight: 35,
        ),
      );
    }

    // -------------------------------------------------------- credentials
    if (uri.userInfo.isNotEmpty) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.critical,
          title: 'Credentials embedded in the link',
          detail:
              'The address contains text before the "@". Everything before it '
              'is ignored by the browser, so it is used to disguise the real '
              'destination.',
          weight: 35,
        ),
      );
    }

    // ---------------------------------------------------------------- port
    if (uri.hasPort && uri.port != 80 && uri.port != 443) {
      findings.add(
        UrlFinding(
          severity: UrlFindingSeverity.warning,
          title: 'Unusual network port (${uri.port})',
          detail:
              'Web traffic normally uses 443. A strange port can indicate a '
              'temporary or compromised server.',
          weight: 12,
        ),
      );
    }

    // ------------------------------------------------------------ subdomains
    final subdomainCount = parts.subdomains.length;
    if (subdomainCount >= 4) {
      findings.add(
        UrlFinding(
          severity: UrlFindingSeverity.warning,
          title: 'Excessive subdomains ($subdomainCount)',
          detail:
              'Long subdomain chains are used to push the real domain out of '
              'sight on a phone screen.',
          weight: 15,
        ),
      );
    }

    // ------------------------------------------------------------- shortener
    final isShortener =
        _shorteners.contains(registrable ?? host) ||
        _shorteners.contains(host) ||
        signalTypes.contains(UrlSignalType.urlShortener);

    if (isShortener) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.warning,
          title: 'Link shortener',
          detail:
              'The real destination is hidden behind a redirect. Legitimate '
              'bank and government messages do not normally use shorteners.',
          weight: 18,
        ),
      );
    }

    // -------------------------------------------------------------- abuse TLD
    if (tld != null && _highAbuseTlds.contains(tld)) {
      findings.add(
        UrlFinding(
          severity: UrlFindingSeverity.warning,
          title: 'High-abuse top-level domain (.$tld)',
          detail:
              'This TLD is cheap or free to register and is heavily used in '
              'phishing campaigns. Not proof of malice, but a real risk factor.',
          weight: 14,
        ),
      );
    }

    // -------------------------------------------------------- encoded chars
    final decoded = Uri.decodeComponent(raw.replaceAll('+', ' '));
    if (decoded != raw &&
        (decoded.contains('://') || decoded.contains('<script'))) {
      findings.add(
        const UrlFinding(
          severity: UrlFindingSeverity.warning,
          title: 'Hidden characters in the link',
          detail:
              'The link contains encoded text that decodes to another address '
              'or to markup, which is a filter-evasion technique.',
          weight: 16,
        ),
      );
    }

    // ------------------------------------------------------- lookalike brand
    // (contributed separately via impersonation.riskContribution)

    return UrlForensics(
      rawUrl: raw,
      host: host,
      registrableDomain: registrable,
      subdomain: parts.subdomains.isEmpty ? null : parts.subdomains.join('.'),
      publicSuffix: tld,
      scheme: scheme,
      port: uri.hasPort ? uri.port : null,
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      isHttps: isHttps,
      isShortener: isShortener,
      isIpHost: signalTypes.contains(UrlSignalType.ipAddressHost),
      hasPunycode: signalTypes.contains(UrlSignalType.punycodeHost),
      hasMixedScript: signalTypes.contains(UrlSignalType.mixedScriptHost),
      hasEmbeddedCredentials: uri.userInfo.isNotEmpty,
      subdomainCount: subdomainCount,
      findings: List.unmodifiable(findings),
      impersonation: impersonation,
    );
  }

  /// Split a host into subdomains, the registrable domain, and the public
  /// suffix — handling two-part suffixes such as `co.uk` and `gov.lk`.
  _HostParts _splitHost(String host) {
    final labels = host.split('.').where((l) => l.isNotEmpty).toList();

    if (labels.isEmpty) {
      return const _HostParts(subdomains: [], registrable: null, suffix: null);
    }

    if (labels.length == 1) {
      return _HostParts(
        subdomains: const [],
        registrable: labels.first,
        suffix: null,
      );
    }

    final lastTwo = '${labels[labels.length - 2]}.${labels.last}';

    if (_twoPartSuffixes.contains(lastTwo)) {
      if (labels.length == 2) {
        return _HostParts(
          subdomains: const [],
          registrable: lastTwo,
          suffix: lastTwo,
        );
      }

      final registrable = '${labels[labels.length - 3]}.$lastTwo';
      return _HostParts(
        subdomains: labels.sublist(0, labels.length - 3),
        registrable: registrable,
        suffix: lastTwo,
      );
    }

    // Single-label suffix (.com, .lk, .top ...).
    if (labels.length == 2) {
      return _HostParts(
        subdomains: const [],
        registrable: host,
        suffix: labels.last,
      );
    }

    final registrable = '${labels[labels.length - 2]}.${labels.last}';
    return _HostParts(
      subdomains: labels.sublist(0, labels.length - 2),
      registrable: registrable,
      suffix: labels.last,
    );
  }

  static bool _isIpLiteral(String host) {
    if (host.contains(':')) return true;
    // 1.2.3.4
    return RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
  }

  /// True when the host genuinely looks like a hostname or IP literal.
  static bool _looksLikeHost(String host) {
    if (_isIpLiteral(host)) return true;
    if (!_hostPattern.hasMatch(host)) return false;

    final tld = host.split('.').last;
    return _tldPattern.hasMatch(tld);
  }
}

class _HostParts {
  final List<String> subdomains;
  final String? registrable;
  final String? suffix;

  const _HostParts({
    required this.subdomains,
    required this.registrable,
    required this.suffix,
  });
}
