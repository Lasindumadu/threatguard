/// A known data breach, as bundled reference data.
class BreachRecord {
  final String id;
  final String name;
  final String year;
  final String description;

  /// What kinds of personal data were exposed.
  final List<BreachDataKind> exposed;

  /// Number of accounts affected, for prioritisation. Approximate.
  final int affectedAccounts;

  const BreachRecord({
    required this.id,
    required this.name,
    required this.year,
    required this.description,
    required this.exposed,
    required this.affectedAccounts,
  });
}

enum BreachDataKind {
  email,
  password,
  phone,
  name,
  address,
  paymentCard,
  dateOfBirth,
  nationalId,
}

/// Result of checking one identifier.
class BreachExposureResult {
  final String identifier;

  /// Masked for display, e.g. `a***z@example.com`.
  final String maskedIdentifier;
  final List<BreachRecord> matches;

  const BreachExposureResult({
    required this.identifier,
    required this.maskedIdentifier,
    required this.matches,
  });

  bool get isExposed => matches.isNotEmpty;

  int get severity {
    if (matches.isEmpty) return 0;

    // Weighted by how sensitive the leaked data is and how recent the breach is.
    var score = 0;
    for (final breach in matches) {
      if (breach.exposed.contains(BreachDataKind.password)) score += 40;
      if (breach.exposed.contains(BreachDataKind.paymentCard)) score += 35;
      if (breach.exposed.contains(BreachDataKind.nationalId)) score += 35;
      if (breach.exposed.contains(BreachDataKind.phone)) score += 15;
      if (breach.exposed.contains(BreachDataKind.address)) score += 10;
      score += 5;
    }

    return score.clamp(0, 100);
  }
}

/// Bundled breach reference data.
///
/// **Honest limitation:** this is a small, offline sample used to demonstrate
/// the flow. Real coverage comes from a live feed (Have I Been Pwned and
/// similar). The app never pretends this list is complete.
class BreachCatalog {
  const BreachCatalog();

  static const List<BreachRecord> breaches = [
    BreachRecord(
      id: 'linkedin-2021',
      name: 'LinkedIn scrape',
      year: '2021',
      description:
          'Profile data from roughly 700 million accounts was scraped and '
          'published. Passwords were not in this set, but e-mail addresses and '
          'phone numbers were.',
      exposed: [
        BreachDataKind.email,
        BreachDataKind.phone,
        BreachDataKind.name,
        BreachDataKind.address,
      ],
      affectedAccounts: 700000000,
    ),
    BreachRecord(
      id: 'facebook-2019',
      name: 'Facebook data leak',
      year: '2019',
      description:
          'Names, phone numbers and e-mail addresses from over 500 million '
          'accounts were published in a public dataset.',
      exposed: [
        BreachDataKind.email,
        BreachDataKind.phone,
        BreachDataKind.name,
        BreachDataKind.dateOfBirth,
      ],
      affectedAccounts: 533000000,
    ),
    BreachRecord(
      id: 'collection-1-2019',
      name: 'Collection #1',
      year: '2019',
      description:
          'A large compilation of credentials from many breaches, circulated on '
          'hacking forums. Includes e-mail addresses and plaintext or weak-hash '
          'passwords.',
      exposed: [BreachDataKind.email, BreachDataKind.password],
      affectedAccounts: 773000000,
    ),
    BreachRecord(
      id: 'dropbox-2012',
      name: 'Dropbox',
      year: '2012',
      description:
          'Account credentials were taken and later decrypted, exposing '
          'passwords for the affected accounts.',
      exposed: [
        BreachDataKind.email,
        BreachDataKind.password,
        BreachDataKind.name,
      ],
      affectedAccounts: 68600000,
    ),
    BreachRecord(
      id: 'adobe-2013',
      name: 'Adobe',
      year: '2013',
      description:
          'Encrypted passwords and password hints were exposed, along with user '
          'e-mail addresses.',
      exposed: [
        BreachDataKind.email,
        BreachDataKind.password,
        BreachDataKind.name,
      ],
      affectedAccounts: 153000000,
    ),
    BreachRecord(
      id: 'myfitnesspal-2018',
      name: 'MyFitnessPal',
      year: '2018',
      description:
          'Usernames, e-mail addresses and hashed passwords were taken.',
      exposed: [
        BreachDataKind.email,
        BreachDataKind.password,
        BreachDataKind.name,
      ],
      affectedAccounts: 144000000,
    ),
    BreachRecord(
      id: 'mobitel-like-telecom',
      name: 'Telecom subscriber list (illustrative)',
      year: '2020',
      description:
          'Illustrative telecom subscriber records, showing how phone-number '
          'exposure carries identity and SIM-swap risk.',
      exposed: [
        BreachDataKind.phone,
        BreachDataKind.name,
        BreachDataKind.nationalId,
      ],
      affectedAccounts: 12000000,
    ),
  ];

  List<BreachRecord> get all => breaches;

  BreachRecord? byId(String id) {
    for (final breach in breaches) {
      if (breach.id == id) return breach;
    }
    return null;
  }
}
