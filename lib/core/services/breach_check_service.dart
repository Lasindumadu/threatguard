import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../models/breach_record.dart';

/// Online breach lookup using k-anonymity.
///
/// This is the privacy mechanism that makes the feature defensible, and it is
/// worth being precise about what it does and does not protect:
///
///  1. SHA-1 the secret locally.
///  2. Send only the **first five hex characters** of that hash.
///  3. The server returns every suffix that matches that prefix — typically
///     hundreds to thousands of them.
///  4. The match is done **on this device**.
///
/// The server therefore learns a 5-character prefix, shared by roughly
/// 1-in-a-million secrets, and never learns the secret or its full hash. This
/// is exactly the Have I Been Pwned range-query model.
///
/// The call only happens when the user has explicitly enabled online lookup;
/// there is no default-on network path anywhere in this app.
class KAnonymityBreachClient {
  KAnonymityBreachClient({
    http.Client? client,
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  /// Endpoint implementing the range query, e.g. the Pwned Passwords API.
  static const defaultEndpoint = 'https://api.pwnedpasswords.com/range/';

  /// The first 5 hex characters of the SHA-1 — the only part transmitted.
  ///
  /// Exposed separately and tested directly, so the privacy guarantee can be
  /// asserted rather than merely documented.
  static String hashPrefix(String secret) {
    final digest = sha1.convert(utf8.encode(secret));
    return digest.toString().toUpperCase().substring(0, 5);
  }

  static String hashSuffix(String secret) {
    final digest = sha1.convert(utf8.encode(secret));
    return digest.toString().toUpperCase().substring(5);
  }

  /// Returns how many times [secret] appears in the corpus, or 0.
  ///
  /// Returns null when the lookup could not be completed, which the UI must
  /// distinguish from "not found" — claiming a password is safe because the
  /// network failed would be dangerous.
  Future<int?> occurrences(String secret, {String? endpoint}) async {
    final prefix = hashPrefix(secret);
    final suffix = hashSuffix(secret);

    final uri = Uri.parse('${endpoint ?? defaultEndpoint}$prefix');

    try {
      final response = await _client.get(uri).timeout(timeout);

      if (response.statusCode != 200) return null;

      // Each line is "SUFFIX:COUNT".
      for (final line in const LineSplitter().convert(response.body)) {
        final separator = line.indexOf(':');
        if (separator <= 0) continue;

        final candidate = line.substring(0, separator).trim().toUpperCase();
        if (candidate != suffix) continue;

        return int.tryParse(line.substring(separator + 1).trim()) ?? 0;
      }

      return 0;
    } catch (_) {
      // Network failure, timeout, DNS, TLS — all reported as "unknown".
      return null;
    }
  }

  void close() => _client.close();
}

/// Checks identifiers against the bundled breach catalogue, locally.
///
/// The online path is deliberately separate and opt-in so that the default
/// behaviour of this screen involves **zero** network traffic.
class BreachCheckService {
  const BreachCheckService({this.catalog = const BreachCatalog()});

  final BreachCatalog catalog;

  /// Deterministic offline check.
  ///
  /// Because the bundled catalogue contains no real subscriber data, the match
  /// is a documented heuristic rather than a lookup: an identifier whose local
  /// hash falls into a breach's cohort is reported as *potentially* exposed.
  /// The UI labels it as such — see [BreachExposureResult.matches].
  BreachExposureResult check(String identifier) {
    final trimmed = identifier.trim().toLowerCase();
    final masked = mask(trimmed);

    if (trimmed.isEmpty) {
      return BreachExposureResult(
        identifier: trimmed,
        maskedIdentifier: masked,
        matches: const [],
      );
    }

    final matches = <BreachRecord>[];

    for (final breach in catalog.all) {
      if (_isCohortMember(trimmed, breach.id)) {
        matches.add(breach);
      }
    }

    return BreachExposureResult(
      identifier: trimmed,
      maskedIdentifier: masked,
      matches: matches,
    );
  }

  /// A stable, evenly-distributed bucket for an identifier+breach pair.
  ///
  /// Only used to decide cohort membership in this offline demonstration; the
  /// real product replaces this with an actual index of breached identifiers.
  static bool _isCohortMember(String identifier, String breachId) {
    var hash = 0x811c9dc5;
    for (final unit in '$breachId::$identifier'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }

    // Roughly a third of identifiers fall into any given cohort, which keeps
    // the demo populated without being uniform.
    return hash % 3 == 0;
  }

  /// Mask an identifier so the screen never shows the whole thing.
  ///
  /// `someone@example.com` -> `s*****e@example.com`
  static String mask(String identifier) {
    if (identifier.isEmpty) return '';

    final atIndex = identifier.indexOf('@');

    if (atIndex > 0) {
      final local = identifier.substring(0, atIndex);
      final domain = identifier.substring(atIndex);

      if (local.length <= 2) return '${local[0]}*$domain';
      return '${local[0]}${'*' * (local.length - 2)}'
          '${local[local.length - 1]}$domain';
    }

    // Phone number or other identifier: keep the last 3 digits.
    final digits = identifier.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 4) {
      return '${'*' * (digits.length - 3)}${digits.substring(digits.length - 3)}';
    }

    if (identifier.length <= 3) return '*' * identifier.length;
    return '${identifier[0]}${'*' * (identifier.length - 2)}'
        '${identifier[identifier.length - 1]}';
  }

  /// Prioritised remediation advice for an exposure result.
  static List<String> remediationFor(BreachExposureResult result) {
    if (!result.isExposed) {
      return const [
        'No exposure found in the bundled catalogue. This list is a sample, '
            'not complete coverage.',
        'Use a unique password everywhere and turn on two-factor '
            'authentication where it is offered.',
      ];
    }

    final steps = <String>[];
    final kinds = result.matches.expand((b) => b.exposed).toSet();

    if (kinds.contains(BreachDataKind.password)) {
      steps.add(
        'Change the password for those accounts first, and change it anywhere '
        'else you reused it.',
      );
      steps.add(
        'Turn on two-factor authentication so a leaked password alone '
        'is not enough to sign in.',
      );
    }

    if (kinds.contains(BreachDataKind.paymentCard)) {
      steps.add(
        'Contact your bank about the exposed card and review recent '
        'transactions.',
      );
    }

    if (kinds.contains(BreachDataKind.phone)) {
      steps.add(
        'Be alert to SIM-swap and smishing attempts: your number is known to '
        'attackers, so unsolicited codes and calls should be treated with '
        'suspicion.',
      );
    }

    if (kinds.contains(BreachDataKind.nationalId)) {
      steps.add(
        'Treat your national identity number as compromised and consider '
        'placing a fraud alert with your bank.',
      );
    }

    if (kinds.contains(BreachDataKind.email)) {
      steps.add(
        'Expect targeted phishing to this address — ThreatGuard will flag the '
        'messages you share with it.',
      );
    }

    steps.add(
      'Use a password manager so every account can have a different, strong '
      'password.',
    );

    return steps;
  }
}
