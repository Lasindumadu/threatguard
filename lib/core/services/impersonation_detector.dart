import 'dart:math' as math;

/// Brand/domain impersonation detection.
///
/// The single most common phishing trick is a domain that *reads* like the real
/// one: `paypaI.com` (capital I), `arnazon.com` (r+n), `g00gle.com`,
/// `microsoft-support.top`, `аpple.com` (Cyrillic а). This engine compares an
/// incoming host against the official domains in the organisation registry and
/// reports how close it is and why.
///
/// The hard part is precision: it must flag `faceb00k-login.top` while never
/// flagging `facebook.com` or an unrelated legitimate site. Everything here is
/// structured around that constraint — in particular, a distance of 0 is
/// always treated as the genuine domain, and short base names are skipped
/// because edit distance on a 4-letter string produces nonsense.
class ImpersonationDetector {
  const ImpersonationDetector({
    this.officialDomains = const [],
    this.maxEditDistance = 2,
  });

  /// The set of genuine domains to protect, e.g. `['paypal.com', 'google.com']`.
  final List<String> officialDomains;

  /// How many edits away a host may be before it stops being "a lookalike".
  /// 1 or 2 is the useful range; 3 matches almost anything.
  final int maxEditDistance;

  /// Hosts too short to compare safely — `x.com` is one edit from `a.com`.
  ///
  /// Homoglyph comparison is exempted from this floor (see [check]): visual
  /// identity is meaningful even for a short brand name, whereas edit distance
  /// on 4-5 letters produces nonsense.
  static const int _minBaseLength = 6;

  /// Compare a host against every known brand.
  ImpersonationCheck check(String host) {
    final normalizedHost = normalizeHost(host);

    if (normalizedHost.isEmpty) {
      return const ImpersonationCheck(
        verdict: ImpersonationVerdict.unknown,
        host: '',
        brand: null,
        officialDomain: null,
        reasons: [],
      );
    }

    // 1. Exact match (or subdomain of an official domain) is the genuine site.
    for (final domain in officialDomains) {
      if (_isSameOrSubdomain(normalizedHost, domain)) {
        return ImpersonationCheck(
          verdict: ImpersonationVerdict.genuine,
          host: host,
          brand: _brandOf(domain),
          officialDomain: domain,
          reasons: const ['This is the official domain for the brand.'],
        );
      }
    }

    // 2. Look for lookalikes.
    final findings = <String>[];
    String? bestDomain;
    String? bestBrand;
    int bestDistance = 1 << 30;

    for (final domain in officialDomains) {
      final officialBase = _baseName(domain);
      final hostBase = _baseName(normalizedHost);
      if (hostBase.isEmpty || officialBase.isEmpty) continue;

      // 2a. Homoglyph / leetspeak normalisation runs first and *before* the
      //     length floor: `paypa1.com` and `аpple.com` are not "2 edits away",
      //     they are visually identical, and that holds for short brands too.
      final deobfuscatedHost = deobfuscate(hostBase);
      final deobfuscatedOfficial = deobfuscate(officialBase);

      final visualDuplicate =
          deobfuscatedHost == deobfuscatedOfficial && hostBase != officialBase;

      if (visualDuplicate) {
        findings.add(
          'The domain uses lookalike characters to imitate '
          '${_brandOf(domain)} ("$hostBase" is visually identical to '
          '"$officialBase").',
        );
        if (bestDistance > 1) {
          bestDistance = 1;
          bestDomain = domain;
          bestBrand = _brandOf(domain);
        }
        continue;
      }

      // Everything below compares strings by edit distance, which is only
      // meaningful for names long enough to be distinctive. Combosquatting and
      // lure suffixes are exempt (see below), because a short brand name is
      // still a brand name: "hnb-secure-login.top" is HNB plus a lure, and a
      // length guard would have hidden that entirely.
      if (officialBase.length >= _minBaseLength) {
        // 2b. Typosquatting: a small edit distance on the brand name.
        final distance = levenshtein(hostBase, officialBase);
        if (distance > 0 && distance <= maxEditDistance) {
          findings.add(
            'The domain is $distance character${distance == 1 ? '' : 's'} '
            'away from the official ${_brandOf(domain)} domain '
            '"$officialBase".',
          );
          if (distance < bestDistance) {
            bestDistance = distance;
            bestDomain = domain;
            bestBrand = _brandOf(domain);
          }
          continue;
        }
      }

      // 2c. Combosquatting: the brand name appears inside a longer host with an
      //     unrelated word attached, e.g. `paypal-verify.top`,
      //     `hnb-secure-login.top`.
      if (hostBase.length > officialBase.length + 2 &&
          _containsBrandToken(hostBase, officialBase)) {
        findings.add(
          'The domain contains the ${_brandOf(domain)} name but is not an '
          'official domain ("$hostBase" instead of "$officialBase").',
        );
        if (bestDistance > 2) {
          bestDistance = 2;
          bestDomain = domain;
          bestBrand = _brandOf(domain);
        }
        continue;
      }

      // 2d. Brand name plus a security-sounding suffix, e.g.
      //     `google-security.top`, `hnb-verify.top`.
      for (final suffix in _lureSuffixes) {
        final candidate = '$officialBase$suffix';
        if (hostBase == candidate ||
            hostBase.contains('$candidate-') ||
            hostBase.endsWith(candidate)) {
          findings.add(
            'The domain pairs the ${_brandOf(domain)} name with "$suffix" — a '
            'common phishing construction.',
          );
          if (bestDistance > 1) {
            bestDistance = 1;
            bestDomain = domain;
            bestBrand = _brandOf(domain);
          }
          break;
        }
      }
    }

    if (findings.isEmpty) {
      return ImpersonationCheck(
        verdict: ImpersonationVerdict.noMatch,
        host: host,
        brand: null,
        officialDomain: null,
        reasons: const [],
      );
    }

    return ImpersonationCheck(
      verdict: bestDistance <= 1
          ? ImpersonationVerdict.likelyImpersonation
          : ImpersonationVerdict.possibleImpersonation,
      host: host,
      brand: bestBrand,
      officialDomain: bestDomain,
      reasons: List.unmodifiable(findings),
    );
  }

  /// Check every host in a list, keeping only the concerning ones.
  List<ImpersonationCheck> checkAll(List<String> hosts) {
    return hosts
        .map(check)
        .where(
          (result) =>
              result.verdict == ImpersonationVerdict.likelyImpersonation ||
              result.verdict == ImpersonationVerdict.possibleImpersonation,
        )
        .toList();
  }

  /// True when [brand] appears in [host] as a whole token.
  ///
  /// Token-aware on purpose: `hnb-secure-login` contains the token `hnb`, but
  /// `hnboats.com` merely contains the letters and must not be treated as an
  /// impersonation of the bank.
  static bool _containsBrandToken(String host, String brand) {
    final tokens = host.split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty);

    for (final token in tokens) {
      if (token == brand) return true;
    }

    return false;
  }

  static const List<String> _lureSuffixes = [
    '-secure',
    '-security',
    '-support',
    '-verify',
    '-verification',
    '-login',
    '-signin',
    '-account',
    '-update',
    '-service',
    '-help',
    '-alert',
    '-billing',
    '-recovery',
    'secure-',
    'verify-',
    'login-',
    'account-',
  ];

  /// Strip a scheme, path, port and a leading `www.`.
  static String normalizeHost(String input) {
    var host = input.trim().toLowerCase();

    if (host.contains('://')) {
      final parsed = Uri.tryParse(host);
      if (parsed != null && parsed.host.isNotEmpty) {
        host = parsed.host;
      }
    }

    host = host.split('/').first;
    host = host.split(':').first;
    host = host.split('?').first;

    if (host.startsWith('www.')) {
      host = host.substring(4);
    }

    return host;
  }

  /// The part before the public suffix: `mail.google.com` -> `google`.
  ///
  /// Multi-part suffixes like `co.uk` are handled by taking the label before
  /// the last two components when the second-to-last is a known second-level
  /// suffix.
  static String _baseName(String host) {
    final labels = host.split('.').where((l) => l.isNotEmpty).toList();
    if (labels.isEmpty) return '';

    if (labels.length == 1) return labels.first;

    const twoPartSuffixes = {
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
    };

    final lastTwo = labels.length >= 2
        ? '${labels[labels.length - 2]}.${labels.last}'
        : '';

    if (twoPartSuffixes.contains(lastTwo) && labels.length >= 3) {
      return labels[labels.length - 3];
    }

    return labels[labels.length - 2];
  }

  static String? _brandOf(String domain) {
    final base = _baseName(domain);
    if (base.isEmpty) return null;
    return base[0].toUpperCase() + base.substring(1);
  }

  static bool _isSameOrSubdomain(String host, String domain) {
    final d = domain.toLowerCase();
    return host == d || host.endsWith('.$d');
  }

  /// Fold the characters attackers use to make a different string *look* the
  /// same: leetspeak digits, visually identical Latin letters, and Cyrillic or
  /// Greek homoglyphs.
  ///
  /// Note that `i`/`l`/`1` all fold together, which is exactly why `paypaI`
  /// and `paypal` must compare equal here — the point is visual identity.
  static String deobfuscate(String input) {
    final buffer = StringBuffer();

    for (final rune in input.toLowerCase().runes) {
      final mapped = _homoglyphs[rune];
      if (mapped != null) {
        buffer.write(mapped);
        continue;
      }

      if (rune == 0x30) {
        buffer.write('o');
      } else if (rune == 0x31 || rune == 0x6C || rune == 0x7C) {
        // 1/l/| all fold to i — the paypaI/paypal visual-identity case.
        buffer.write('i');
      } else if (rune == 0x35) {
        buffer.write('s');
      } else if (rune == 0x33) {
        buffer.write('e');
      } else if (rune == 0x34 || rune == 0x40) {
        buffer.write('a');
      } else if (rune == 0x37) {
        buffer.write('t');
      } else {
        buffer.writeCharCode(rune);
      }
    }

    return buffer.toString();
  }

  static const Map<int, String> _homoglyphs = {
    // Cyrillic
    0x0430: 'a', // а
    0x0435: 'e', // е
    0x043E: 'o', // о
    0x0440: 'p', // р
    0x0441: 'c', // с
    0x0445: 'x', // х
    0x0443: 'y', // у
    0x0456: 'i', // і
    0x0455: 's', // ѕ
    // Greek
    0x03BF: 'o', // ο
    0x03B1: 'a', // α
    0x03B5: 'e', // ε
    0x03C1: 'p', // ρ
    0x03BD: 'v', // ν
  };

  /// Standard Levenshtein distance, iterative with two rows.
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 1; i <= a.length; i++) {
      current[0] = i;

      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;

        current[j] = math.min(
          math.min(current[j - 1] + 1, previous[j] + 1),
          previous[j - 1] + cost,
        );
      }

      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[b.length];
  }
}

enum ImpersonationVerdict {
  /// The genuine official domain.
  genuine,

  /// A near-identical lookalike — treat as hostile.
  likelyImpersonation,

  /// Suspiciously similar, or brand name embedded in another domain.
  possibleImpersonation,

  /// Nothing resembling any known brand.
  noMatch,

  /// Input could not be parsed.
  unknown,
}

class ImpersonationCheck {
  final ImpersonationVerdict verdict;
  final String host;
  final String? brand;
  final String? officialDomain;
  final List<String> reasons;

  const ImpersonationCheck({
    required this.verdict,
    required this.host,
    required this.brand,
    required this.officialDomain,
    required this.reasons,
  });

  bool get isConcerning =>
      verdict == ImpersonationVerdict.likelyImpersonation ||
      verdict == ImpersonationVerdict.possibleImpersonation;

  /// Risk points this contributes to a link score.
  ///
  /// These are deliberately high. A domain that visually imitates a bank is
  /// not a "possible" problem to hedge about — if the address is not the
  /// official domain and it reads as one, the link should be treated as
  /// hostile rather than merely suspicious.
  int get riskContribution => switch (verdict) {
    ImpersonationVerdict.likelyImpersonation => 60,
    ImpersonationVerdict.possibleImpersonation => 35,
    _ => 0,
  };

  String get summary => switch (verdict) {
    ImpersonationVerdict.genuine =>
      'Official domain${brand == null ? '' : ' for $brand'}.',
    ImpersonationVerdict.likelyImpersonation =>
      'Almost certainly impersonating ${brand ?? 'a known brand'}.',
    ImpersonationVerdict.possibleImpersonation =>
      'May be impersonating ${brand ?? 'a known brand'}.',
    ImpersonationVerdict.noMatch => 'No known brand resemblance.',
    ImpersonationVerdict.unknown => 'Could not inspect this host.',
  };
}
