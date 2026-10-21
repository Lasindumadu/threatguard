import '../models/url_reputation.dart';
import 'url_forensics_analyzer.dart';

/// The consolidated answer to "is this link safe to tap?".
///
/// This is the type the UI consumes, and the type the interception flow gates
/// on. It merges three sources of evidence — structural forensics, brand
/// impersonation, and reputation — into one verdict with a single score and a
/// flat list of reasons, so nothing downstream has to know how many engines
/// fed it.
class LinkSafety {
  final String url;
  final LinkSafetyGrade verdict;
  final int score;

  /// Every reason, from every engine, in plain language.
  final List<String> reasons;

  /// The full forensic breakdown, for the detail view.
  final UrlForensics forensics;

  /// Reputation check, when one was performed.
  final UrlReputation? reputation;

  const LinkSafety({
    required this.url,
    required this.verdict,
    required this.score,
    required this.reasons,
    required this.forensics,
    this.reputation,
  });

  bool get isSafe => verdict == LinkSafetyGrade.looksSafe;
  bool get isDangerous => verdict == LinkSafetyGrade.dangerous;

  /// True when the URL is risky enough that we should not let a simple tap
  /// navigate to it without an explicit confirmation.
  bool get shouldIntercept => verdict != LinkSafetyGrade.looksSafe;

  /// Whether the destination can be handed to a browser at all.
  ///
  /// A non-HTTP(S) scheme is never opened: `tg://`, `javascript:`, `intent://`
  /// and `file://` have all been used to escape the sandbox or run script.
  bool get isOpenableScheme {
    final scheme = forensics.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  /// The one-line summary shown on the interstitial.
  String get headline => switch (verdict) {
    LinkSafetyGrade.looksSafe => 'No problems found with this link',
    LinkSafetyGrade.suspicious => 'This link looks suspicious',
    LinkSafetyGrade.dangerous => 'Do not open this link',
  };

  String get recommendation => switch (verdict) {
    LinkSafetyGrade.looksSafe =>
      'Nothing stands out, but stay alert for requests for passwords, '
          'one-time codes or payment.',
    LinkSafetyGrade.suspicious =>
      'Open it only if you were expecting it, and never enter a password or '
          'one-time code on the page. Reach the service through its official '
          'app instead.',
    LinkSafetyGrade.dangerous =>
      'Delete the message. If you already opened it, do not enter any '
          'information, and change your password if you did.',
  };
}

/// Combines the URL engines into one verdict.
class LinkSafetyService {
  const LinkSafetyService({
    this.forensicsAnalyzer = const UrlForensicsAnalyzer(),
  });

  final UrlForensicsAnalyzer forensicsAnalyzer;

  /// Analyses a URL without any network access.
  ///
  /// The offline path is the default and the only path used unless the user has
  /// enabled online reputation lookup, which is why it has to stand on its own.
  LinkSafety analyzeOffline(String url) {
    final forensics = forensicsAnalyzer.analyze(url);

    final reasons = <String>[
      for (final finding in forensics.findings)
        if (finding.weight > 0 || finding.severity != UrlFindingSeverity.info)
          finding.detail,
    ];

    final impersonation = forensics.impersonation;
    if (impersonation != null && impersonation.isConcerning) {
      reasons.addAll(impersonation.reasons);
    }

    return LinkSafety(
      url: url,
      verdict: forensics.grade,
      score: forensics.riskScore,
      reasons: List.unmodifiable(reasons),
      forensics: forensics,
    );
  }

  /// Analyses a URL and folds in a reputation result.
  ///
  /// Reputation can raise the verdict but never lowers it: a "safe" reputation
  /// report does not clear a domain that structurally impersonates a bank,
  /// because reputation services lag newly-registered phishing domains by hours
  /// or days — exactly the window an attack uses.
  LinkSafety combine(String url, UrlReputation? reputation) {
    final offline = analyzeOffline(url);

    if (reputation == null ||
        reputation.status == UrlReputationStatus.unknown) {
      return offline;
    }

    final reasons = [...offline.reasons];
    var score = offline.score;
    var verdict = offline.verdict;

    switch (reputation.status) {
      case UrlReputationStatus.malicious:
        score = 100;
        verdict = LinkSafetyGrade.dangerous;
        reasons.add(
          'A threat-intelligence source lists this address as malicious'
          '${reputation.reason == null ? '' : ' (${reputation.reason})'}.',
        );
      case UrlReputationStatus.suspicious:
        score = score < 45 ? 45 : score;
        verdict = verdict == LinkSafetyGrade.dangerous
            ? verdict
            : LinkSafetyGrade.suspicious;
        reasons.add(
          'A reputation source reports this address as suspicious'
          '${reputation.reason == null ? '' : ' (${reputation.reason})'}.',
        );
      case UrlReputationStatus.invalid:
        score = score < 60 ? 60 : score;
        verdict = LinkSafetyGrade.dangerous;
        reasons.add('This address does not resolve to a reachable service.');
      case UrlReputationStatus.safe:
        reasons.add('No threat-intelligence source has reported this address.');
      case UrlReputationStatus.valid:
        reasons.add('This address is reachable.');
      case UrlReputationStatus.unknown:
        break;
    }

    return LinkSafety(
      url: url,
      verdict: verdict,
      score: score.clamp(0, 100),
      reasons: List.unmodifiable(reasons),
      forensics: offline.forensics,
      reputation: reputation,
    );
  }
}

/// Holds URLs that have been quarantined, so the interception flow can refer to
/// them by a short id instead of carrying the raw address around the UI.
///
/// Kept in memory only: a quarantined phishing URL is sensitive, and persisting
/// it to disk would create a stored record of what the user was targeted by.
class QuarantineVault {
  QuarantineVault();

  final Map<String, LinkSafety> _entries = {};
  int _counter = 0;

  String quarantine(LinkSafety safety) {
    final id = 'q${_counter++}';
    _entries[id] = safety;
    return id;
  }

  LinkSafety? resolve(String id) => _entries[id];

  /// Releases an entry once the user has seen the warning.
  LinkSafety? release(String id) => _entries.remove(id);

  int get size => _entries.length;

  void clear() => _entries.clear();
}
