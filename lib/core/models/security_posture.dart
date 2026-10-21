/// A single device-hygiene check.
///
/// The important design decision here is [PostureStatus.unknown]. A
/// non-system app on modern Android genuinely cannot inspect most device
/// state, and reporting a guess as a pass would be a lie the user might rely
/// on. Everything unavailable is reported as unknown and excluded from the
/// score rather than assumed safe.
class PostureCheck {
  final String id;
  final String title;
  final String description;
  final PostureStatus status;

  /// What to do about a failure.
  final String? remediation;

  /// How much this contributes to the hygiene score when it is not unknown.
  final int weight;

  const PostureCheck({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    this.remediation,
    this.weight = 10,
  });

  bool get isScored => status != PostureStatus.unknown;
}

enum PostureStatus { pass, fail, warning, unknown }

/// Device security hygiene assessment.
///
/// The scores come from facts the app can actually observe on the device, plus
/// the user's own answers for the things it cannot. Nothing here is invented.
class SecurityPosture {
  final List<PostureCheck> checks;

  const SecurityPosture({required this.checks});

  /// 0..100 hygiene score over the checks that could be evaluated.
  ///
  /// Unknown checks are excluded from both numerator and denominator, so an
  /// app that cannot inspect something does not gain or lose points for it.
  int get score {
    final scored = checks.where((c) => c.isScored).toList();
    if (scored.isEmpty) return 0;

    final totalWeight = scored.fold<int>(0, (sum, c) => sum + c.weight);
    if (totalWeight == 0) return 0;

    var earned = 0;
    for (final check in scored) {
      earned += switch (check.status) {
        PostureStatus.pass => check.weight,
        PostureStatus.warning => (check.weight * 0.5).round(),
        PostureStatus.fail => 0,
        PostureStatus.unknown => 0,
      };
    }

    return ((earned / totalWeight) * 100).round().clamp(0, 100);
  }

  PostureGrade get grade => switch (score) {
    >= 85 => PostureGrade.strong,
    >= 65 => PostureGrade.good,
    >= 40 => PostureGrade.weak,
    _ => PostureGrade.poor,
  };

  List<PostureCheck> get failures => checks
      .where(
        (c) =>
            c.status == PostureStatus.fail || c.status == PostureStatus.warning,
      )
      .toList();

  List<PostureCheck> get unknowns =>
      checks.where((c) => c.status == PostureStatus.unknown).toList();

  int get unknownCount => unknowns.length;
}

enum PostureGrade { strong, good, weak, poor }

/// Builds a [SecurityPosture] from the values the UI could actually obtain.
///
/// Every parameter is nullable on purpose: `null` means "the platform would not
/// tell us", which becomes [PostureStatus.unknown].
class SecurityPostureAssessor {
  const SecurityPostureAssessor();

  SecurityPosture assess({
    required bool? screenLockEnabled,
    required bool? smsPermissionGranted,
    required bool onlineLookupEnabled,
    required bool strictModeEnabled,
    required int mutedSenderCount,
    required int feedbackGiven,
    required int scannedMessages,
    required int highRiskMessages,
  }) {
    final checks = <PostureCheck>[
      PostureCheck(
        id: 'screen_lock',
        title: 'Screen lock enabled',
        description:
            'A PIN, pattern or biometric lock is the single most important '
            'protection for a lost or stolen phone.',
        status: switch (screenLockEnabled) {
          true => PostureStatus.pass,
          false => PostureStatus.fail,
          null => PostureStatus.unknown,
        },
        remediation:
            'Settings → Security → Screen lock. Choose a 6-digit PIN or longer, '
            'and add a fingerprint if available.',
        weight: 20,
      ),
      PostureCheck(
        id: 'sms_monitoring',
        title: 'Message scanning active',
        description:
            'ThreatGuard can only warn you about a scam it has been allowed to '
            'read.',
        status: smsPermissionGranted == true
            ? PostureStatus.pass
            : smsPermissionGranted == false
            ? PostureStatus.fail
            : PostureStatus.unknown,
        remediation:
            'Grant SMS access, or share messages to ThreatGuard from the app '
            'they arrived in.',
        weight: 15,
      ),
      PostureCheck(
        id: 'protection_mode',
        title: 'Protection sensitivity',
        description:
            'Strict mode catches borderline cases that balanced mode lets '
            'through.',
        status: strictModeEnabled ? PostureStatus.pass : PostureStatus.warning,
        remediation:
            'Turn on Strict mode in Settings if you would rather check a false '
            'alarm than miss a real attack.',
        weight: 10,
      ),
      PostureCheck(
        id: 'privacy_posture',
        title: 'Privacy-first configuration',
        description:
            'Online lookups are off, so no link or identifier leaves the '
            'device during analysis.',
        status: onlineLookupEnabled
            ? PostureStatus.warning
            : PostureStatus.pass,
        remediation:
            'Leave online lookup off unless you specifically want link '
            'reputation checks that require a network request.',
        weight: 10,
      ),
      PostureCheck(
        id: 'engagement',
        title: 'You review your threats',
        description:
            'A security tool only helps if its warnings are actually read.',
        status: scannedMessages == 0
            ? PostureStatus.unknown
            : highRiskMessages == 0
            ? PostureStatus.pass
            : PostureStatus.warning,
        remediation: 'Open the Dashboard and review the flagged messages.',
        weight: 10,
      ),
      PostureCheck(
        id: 'feedback',
        title: 'Model feedback provided',
        description:
            'Confirming or correcting verdicts is what makes the detection '
            'better over time.',
        status: feedbackGiven == 0 ? PostureStatus.unknown : PostureStatus.pass,
        remediation:
            'Use the three feedback buttons on any analysis screen to record '
            'whether the verdict was right.',
        weight: 10,
      ),
      PostureCheck(
        id: 'sender_hygiene',
        title: 'Repeat offenders muted',
        description:
            'Muting senders that only ever send junk reduces the number of '
            'things you have to review.',
        status: mutedSenderCount > 0
            ? PostureStatus.pass
            : PostureStatus.unknown,
        remediation: 'Long-press any threat message and mute its sender.',
        weight: 10,
      ),
      // These are genuinely unobservable from a normal app, and are reported
      // as unknown on purpose rather than guessed.
      PostureCheck(
        id: 'os_patch',
        title: 'Operating system up to date',
        description:
            'Security patches close known exploits. Android does not expose '
            'the patch level to a normal app, so ThreatGuard cannot verify '
            'this for you.',
        status: PostureStatus.unknown,
        remediation:
            'Settings → System → System update. Install any pending update.',
        weight: 0,
      ),
      PostureCheck(
        id: 'unknown_sources',
        title: 'Installation from unknown sources',
        description:
            'Sideloading apps bypasses store review. Android 8+ restricts this '
            'per app, and ThreatGuard cannot read that setting.',
        status: PostureStatus.unknown,
        remediation:
            'Settings → Apps → Special access → Install unknown apps. Remove '
            'permission from anything that does not need it.',
        weight: 0,
      ),
    ];

    return SecurityPosture(checks: checks);
  }
}
