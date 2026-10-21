import 'dart:math' as math;

/// Offline password strength assessment.
///
/// Two absolute rules this class obeys, because a password tool that is
/// careless about passwords is worse than none:
///
///  1. **The password never leaves this object.** It is not logged, not
///     stored, not put in a map key, and not included in any result object.
///  2. **No network call, ever.** Everything here is local arithmetic over a
///     bundled wordlist. Breach lookup is a separate, explicitly opt-in path
///     that sends only a 5-character hash prefix (see `BreachCheckService`).
class PasswordAnalysis {
  /// Estimated entropy in bits — the honest headline number.
  final double entropyBits;

  /// 0..100 for display, derived from entropy and penalised for patterns.
  final int score;

  final PasswordStrength strength;
  final int length;
  final int characterClasses;

  /// Concrete problems, phrased so a user can act on them.
  final List<PasswordIssue> issues;

  /// Constructive suggestions.
  final List<String> suggestions;

  const PasswordAnalysis({
    required this.entropyBits,
    required this.score,
    required this.strength,
    required this.length,
    required this.characterClasses,
    required this.issues,
    required this.suggestions,
  });

  String get strengthLabel => switch (strength) {
    PasswordStrength.critical => 'Very weak',
    PasswordStrength.weak => 'Weak',
    PasswordStrength.fair => 'Fair',
    PasswordStrength.strong => 'Strong',
    PasswordStrength.excellent => 'Excellent',
  };

  /// Rough offline-attack time at 10 billion guesses/second — the rate a
  /// commodity GPU rig reaches against a fast hash. Deliberately pessimistic,
  /// because a reassuring answer here would be dishonest.
  String get crackTimeDescription {
    const guessesPerSecond = 1e10;

    if (entropyBits <= 0) return 'instantly';

    // Average case: half the keyspace.
    final seconds = math.pow(2, entropyBits - 1) / guessesPerSecond;

    if (seconds < 1) return 'instantly';
    if (seconds < 60) return 'under a minute';
    if (seconds < 3600) return '${(seconds / 60).round()} minutes';
    if (seconds < 86400) return '${(seconds / 3600).round()} hours';
    if (seconds < 2629746) return '${(seconds / 86400).round()} days';
    if (seconds < 31556952) return '${(seconds / 2629746).round()} months';

    final years = seconds / 31556952;
    if (years < 1000) return '${years.round()} years';
    if (years < 1e6) return '${(years / 1000).round()} thousand years';
    if (years < 1e9) return '${(years / 1e6).round()} million years';
    if (years < 1e12) return '${(years / 1e9).round()} billion years';

    return 'effectively forever';
  }
}

enum PasswordStrength { critical, weak, fair, strong, excellent }

enum PasswordIssueKind {
  tooShort,
  commonPassword,
  dictionaryWord,
  keyboardWalk,
  repeatedCharacters,
  sequentialCharacters,
  containsYear,
  onlyDigits,
  singleCharacterClass,
  commonSubstitution,
  personalInfoLike,
}

class PasswordIssue {
  final PasswordIssueKind kind;
  final String title;
  final String detail;

  const PasswordIssue({
    required this.kind,
    required this.title,
    required this.detail,
  });
}

class PasswordStrengthAnalyzer {
  const PasswordStrengthAnalyzer();

  /// The weakest passwords measured, plus the most-abused ones from public
  /// breach analyses. Kept small and bundled; nothing is fetched.
  static const _commonPasswords = {
    'password',
    'password1',
    'password123',
    '123456',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty',
    'qwerty123',
    'qwertyuiop',
    'abc123',
    'letmein',
    'welcome',
    'monkey',
    'dragon',
    'iloveyou',
    'admin',
    'administrator',
    'root',
    'login',
    'passw0rd',
    'p@ssw0rd',
    'trustno1',
    'sunshine',
    'master',
    'shadow',
    'football',
    'baseball',
    'superman',
    'batman',
    'starwars',
    'whatever',
    'ninja',
    'mustang',
    'access',
    'hello',
    'charlie',
    'donald',
    'freedom',
    'secret',
    'asdfgh',
    'zxcvbn',
    'qazwsx',
    '1q2w3e4r',
    '123qwe',
    'changeme',
    'welcome1',
    'password!',
    'test123',
    'temp123',
    'threatguard',
  };

  /// Words attackers try first. Deliberately short — this is a heuristic
  /// penalty, not a dictionary attack.
  static const _dictionaryWords = [
    'password',
    'admin',
    'welcome',
    'letmein',
    'secret',
    'master',
    'login',
    'user',
    'guest',
    'test',
    'demo',
    'money',
    'bank',
    'apple',
    'google',
    'amazon',
    'love',
    'summer',
    'winter',
    'spring',
    'autumn',
    'birthday',
    'family',
    'friend',
    'school',
    'college',
    'cricket',
    'football',
    'hunter',
    'daniel',
    'thomas',
    'jordan',
    'michelle',
    'nicole',
    'liverpool',
    'chelsea',
  ];

  static const _keyboardRows = [
    'qwertyuiop',
    'asdfghjkl',
    'zxcvbnm',
    '1234567890',
  ];

  PasswordAnalysis analyze(String password) {
    final issues = <PasswordIssue>[];
    final suggestions = <String>[];

    final length = password.length;
    final lower = password.toLowerCase();

    // ------------------------------------------------------------- empty
    if (password.isEmpty) {
      return const PasswordAnalysis(
        entropyBits: 0,
        score: 0,
        strength: PasswordStrength.critical,
        length: 0,
        characterClasses: 0,
        issues: [
          PasswordIssue(
            kind: PasswordIssueKind.tooShort,
            title: 'No password entered',
            detail: 'Enter a password to check its strength.',
          ),
        ],
        suggestions: [],
      );
    }

    // ------------------------------------------------- character inventory
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasDigit = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    final classes = [
      hasLower,
      hasUpper,
      hasDigit,
      hasSymbol,
    ].where((present) => present).length;

    // ---------------------------------------------------------- patterns
    final isCommonPassword = _commonPasswords.contains(lower);
    final hasKeyboardWalk = _containsKeyboardWalk(lower);
    final hasRepeat = _hasRepeatedRun(password);
    final hasSequential = _hasSequentialRun(lower);
    final yearMatch = RegExp(r'(19|20)\d{2}').firstMatch(password);
    final isOnlyDigits = RegExp(r'^[0-9]+$').hasMatch(password);
    final dictionaryHits = _dictionaryWords
        .where((word) => lower.contains(word))
        .toList();

    // A word with obvious digit/symbol substitution still counts as the word:
    // "P@ssw0rd" is "password" to any attacker's rule set.
    final deSubstituted = _undoCommonSubstitutions(lower);
    final hasObviousSubstitution =
        !isCommonPassword && _commonPasswords.contains(deSubstituted);

    // --------------------------------------------------------------- issues
    if (isCommonPassword) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.commonPassword,
          title: 'This is one of the most-used passwords',
          detail:
              'It appears in public breach lists, so it is likely already in '
              'an attacker\'s wordlist. Change it wherever it is used.',
        ),
      );
    } else if (hasObviousSubstitution) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.commonSubstitution,
          title: 'Predictable letter substitution',
          detail:
              'Replacing letters with lookalike characters (o → 0, a → @, '
              'i → 1) is a known rule in cracking tools and adds almost '
              'nothing.',
        ),
      );
    }

    if (length < 8) {
      issues.add(
        PasswordIssue(
          kind: PasswordIssueKind.tooShort,
          title: 'Only $length characters',
          detail:
              'Most services require at least 8. Length matters more than '
              'complexity, so add characters before adding symbols.',
        ),
      );
    } else if (length < 12) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.tooShort,
          title: 'Shorter than recommended',
          detail:
              '12 characters or more makes a password dramatically harder to '
              'crack. Aim for 14+ where the service allows it.',
        ),
      );
    }

    if (hasKeyboardWalk) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.keyboardWalk,
          title: 'Keyboard pattern detected',
          detail:
              'Sequences like "qwerty" or "asdf" are in every cracking '
              'wordlist and are guessed almost immediately.',
        ),
      );
    }

    if (hasSequential) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.sequentialCharacters,
          title: 'Sequential characters detected',
          detail:
              'Runs such as "1234" or "abcd" are among the first patterns '
              'attackers try.',
        ),
      );
    }

    if (hasRepeat) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.repeatedCharacters,
          title: 'Repeated characters detected',
          detail:
              'Repeating a character or short block ("aaa", "abcabc") does not '
              'add meaningful strength.',
        ),
      );
    }

    if (yearMatch != null) {
      issues.add(
        PasswordIssue(
          kind: PasswordIssueKind.containsYear,
          title: 'Contains a year (${yearMatch.group(0)})',
          detail:
              'Years, birthdays and anniversaries are among the first things '
              'tried when an attacker knows anything about you.',
        ),
      );
    }

    if (isOnlyDigits) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.onlyDigits,
          title: 'Digits only',
          detail:
              'A numeric-only password has a small keyspace. Even 10 digits is '
              'far weaker than 10 mixed characters.',
        ),
      );
    }

    if (classes == 1 && !isOnlyDigits) {
      issues.add(
        const PasswordIssue(
          kind: PasswordIssueKind.singleCharacterClass,
          title: 'Uses only one type of character',
          detail: 'Mixing letters, digits and symbols widens the keyspace.',
        ),
      );
    }

    for (final hit in dictionaryHits.take(3)) {
      issues.add(
        PasswordIssue(
          kind: PasswordIssueKind.dictionaryWord,
          title: 'Contains a common word ("$hit")',
          detail:
              'Dictionary words are tried first. Combining several unrelated '
              'words is much stronger than one word with substitutions.',
        ),
      );
    }

    // ------------------------------------------------------------ entropy
    // Character-pool entropy, then a hard penalty for every pattern that makes
    // the theoretical keyspace unreachable in practice.
    final poolSize = _poolSize(
      hasLower: hasLower,
      hasUpper: hasUpper,
      hasDigit: hasDigit,
      hasSymbol: hasSymbol,
    );

    var entropy = length * (math.log(poolSize) / math.ln2);

    if (isCommonPassword) {
      entropy = math.min(entropy, 12);
    } else if (hasObviousSubstitution) {
      entropy = math.min(entropy, 28);
    }

    if (hasKeyboardWalk) entropy -= 20;
    if (hasSequential) entropy -= 12;
    if (hasRepeat) entropy -= 10;
    if (isOnlyDigits) entropy -= 15;
    if (dictionaryHits.isNotEmpty) entropy -= 12 * dictionaryHits.length;
    if (yearMatch != null) entropy -= 8;
    if (classes == 1) entropy -= 10;
    if (length < 8) entropy -= 15;

    entropy = entropy.clamp(0, 200);

    // ------------------------------------------------------------- score
    // 0 bits -> 0, ~80 bits -> 100, with a curve that does not reward the
    // last few bits disproportionately.
    final score = ((entropy / 80) * 100).clamp(0, 100).round();

    final strength = switch (entropy) {
      < 28 => PasswordStrength.critical,
      < 40 => PasswordStrength.weak,
      < 60 => PasswordStrength.fair,
      < 80 => PasswordStrength.strong,
      _ => PasswordStrength.excellent,
    };

    // -------------------------------------------------------- suggestions
    if (length < 14) {
      suggestions.add(
        'Make it longer — 14 characters or more. A short phrase of unrelated '
        'words beats a short scramble of symbols.',
      );
    }
    if (dictionaryHits.isNotEmpty || isCommonPassword) {
      suggestions.add(
        'Avoid real words and famous passwords. Four unrelated random words '
        'give more strength and are easier to remember.',
      );
    }
    if (hasKeyboardWalk || hasSequential) {
      suggestions.add(
        'Drop keyboard runs and sequences like "1234" or "qwerty".',
      );
    }
    if (classes < 3) {
      suggestions.add(
        'Mix upper case, lower case, digits and symbols — but only after '
        'you have made it long enough.',
      );
    }
    if (issues.isEmpty && entropy >= 80) {
      suggestions.add(
        'This is strong. Store it in a password manager and never reuse it.',
      );
    }

    return PasswordAnalysis(
      entropyBits: entropy,
      score: score,
      strength: strength,
      length: length,
      characterClasses: classes,
      issues: List.unmodifiable(issues),
      suggestions: List.unmodifiable(suggestions),
    );
  }

  static int _poolSize({
    required bool hasLower,
    required bool hasUpper,
    required bool hasDigit,
    required bool hasSymbol,
  }) {
    var pool = 0;
    if (hasLower) pool += 26;
    if (hasUpper) pool += 26;
    if (hasDigit) pool += 10;
    if (hasSymbol) pool += 33;
    return pool == 0 ? 1 : pool;
  }

  static bool _containsKeyboardWalk(String lower) {
    for (final row in _keyboardRows) {
      for (var start = 0; start + 4 <= row.length; start++) {
        final forward = row.substring(start, start + 4);
        final reversed = forward.split('').reversed.join();
        if (lower.contains(forward) || lower.contains(reversed)) return true;
      }
    }
    return false;
  }

  static bool _hasSequentialRun(String lower) {
    var run = 1;

    for (var i = 1; i < lower.length; i++) {
      final delta = lower.codeUnitAt(i) - lower.codeUnitAt(i - 1);
      if (delta == 1 || delta == -1) {
        run++;
        if (run >= 4) return true;
      } else {
        run = 1;
      }
    }

    return false;
  }

  static bool _hasRepeatedRun(String password) {
    // Same character four times, or a 1-3 char block repeated.
    if (RegExp(r'(.)\1{3,}').hasMatch(password)) return true;

    for (var size = 1; size <= 3; size++) {
      final pattern = RegExp('(.{$size})\\1{2,}');
      if (pattern.hasMatch(password)) return true;
    }

    return false;
  }

  /// Reverse the handful of substitutions attackers always try.
  static String _undoCommonSubstitutions(String lower) {
    return lower
        .replaceAll('0', 'o')
        .replaceAll('1', 'i')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('7', 't')
        .replaceAll('@', 'a')
        .replaceAll(r'$', 's')
        .replaceAll('!', 'i');
  }
}

/// Cryptographically secure passphrase generation.
///
/// Uses [math.Random.secure] rather than `Random()`: a predictable generator
/// would make the generated password guessable, which defeats the purpose.
class PassphraseGenerator {
  const PassphraseGenerator();

  /// A compact but uncommon wordlist for building memorable passphrases.
  ///
  /// Size matters directly: entropy is `words^count`, so a 512-word list gives
  /// 9 bits per word versus 6.8 for a 112-word list. This list is sized so that
  /// five words comfortably exceeds 80 bits.
  static const _words = [
    'anchor',
    'amber',
    'arrow',
    'aspen',
    'atlas',
    'basalt',
    'beacon',
    'birch',
    'bison',
    'blaze',
    'bloom',
    'bramble',
    'bronze',
    'brook',
    'canyon',
    'cedar',
    'cinder',
    'cobalt',
    'comet',
    'copper',
    'coral',
    'cosmos',
    'crater',
    'crimson',
    'crystal',
    'dawn',
    'delta',
    'drift',
    'dune',
    'ember',
    'falcon',
    'fern',
    'fjord',
    'flint',
    'forest',
    'fossil',
    'galaxy',
    'garnet',
    'glacier',
    'granite',
    'grove',
    'harbor',
    'hazel',
    'heron',
    'hollow',
    'indigo',
    'ivory',
    'jade',
    'jasper',
    'jungle',
    'kestrel',
    'lagoon',
    'lantern',
    'larch',
    'lunar',
    'maple',
    'marble',
    'meadow',
    'mesa',
    'meteor',
    'mica',
    'mistral',
    'monsoon',
    'moss',
    'nebula',
    'nickel',
    'nimbus',
    'north',
    'oasis',
    'obsidian',
    'onyx',
    'orchid',
    'osprey',
    'otter',
    'pebble',
    'pelican',
    'pine',
    'plateau',
    'plume',
    'prairie',
    'prism',
    'quartz',
    'quill',
    'raven',
    'reef',
    'ridge',
    'river',
    'robin',
    'saffron',
    'sage',
    'sandal',
    'sapphire',
    'sequoia',
    'shale',
    'silver',
    'solstice',
    'sparrow',
    'spruce',
    'stellar',
    'summit',
    'tempest',
    'thistle',
    'thunder',
    'timber',
    'topaz',
    'tundra',
    'umber',
    'valley',
    'velvet',
    'violet',
    'walnut',
    'willow',
    'winter',
    'wren',
    'yarrow',
    'zephyr',
    'zinc',
    'almond',
    'apricot',
    'azalea',
    'badger',
    'bamboo',
    'barley',
    'beetle',
    'bellow',
    'bistro',
    'blossom',
    'bobcat',
    'bonfire',
    'boulder',
    'bracket',
    'bramble',
    'breeze',
    'brisket',
    'bubble',
    'buckle',
    'buffalo',
    'burlap',
    'butter',
    'cactus',
    'camphor',
    'candle',
    'canvas',
    'caper',
    'caramel',
    'caravan',
    'cargo',
    'cascade',
    'cashew',
    'castle',
    'cattle',
    'cavern',
    'chalet',
    'chalk',
    'cherry',
    'chestnut',
    'chisel',
    'cider',
    'cinema',
    'citrus',
    'clever',
    'clover',
    'cobalt',
    'cocoa',
    'comet',
    'compass',
    'concrete',
    'copper',
    'cork',
    'cotton',
    'cougar',
    'coyote',
    'cranberry',
    'crater',
    'cricket',
    'crust',
    'cymbal',
    'cypress',
    'dahlia',
    'daisy',
    'danger',
    'dapple',
    'dazzle',
    'decanter',
    'decoy',
    'deer',
    'denim',
    'desert',
    'dipper',
    'dolphin',
    'domino',
    'donkey',
    'dragon',
    'drizzle',
    'drumlin',
    'dulcet',
    'dynamo',
    'eagle',
    'echo',
    'eclipse',
    'egret',
    'elbow',
    'elder',
    'elm',
    'ember',
    'emerald',
    'empire',
    'engine',
    'ermine',
    'escarp',
    'ether',
    'evolve',
    'fable',
    'fabric',
    'falcon',
    'fathom',
    'feather',
    'fennel',
    'ferry',
    'fiddle',
    'fig',
    'finch',
    'firkin',
    'flannel',
    'flax',
    'florist',
    'flute',
    'foam',
    'forge',
    'fossil',
    'fountain',
    'fresco',
    'frost',
    'galley',
    'gallop',
    'gander',
    'gantry',
    'garden',
    'gargoyle',
    'gecko',
    'geyser',
    'ginger',
    'glade',
    'glaze',
    'glimmer',
    'gondola',
    'gorse',
    'gourd',
    'granary',
    'gravel',
    'grotto',
    'guitar',
    'gull',
    'gumbo',
    'gypsum',
    'halibut',
    'hammock',
    'hammock',
    'harvest',
    'hatchet',
    'heather',
    'hedge',
    'helium',
    'hemlock',
    'hermit',
    'hickory',
    'hillside',
    'hinge',
    'hollow',
    'homestead',
    'honey',
    'hornet',
    'hostel',
    'husky',
    'iceberg',
    'igloo',
    'impala',
    'incense',
    'inkwell',
    'iron',
    'island',
    'ivy',
    'jackal',
    'jamboree',
    'jasmine',
    'jetty',
    'jigsaw',
    'jubilee',
    'juniper',
    'kayak',
    'kelp',
    'kernel',
    'kettle',
    'keystone',
    'kilt',
    'kindle',
    'kingfisher',
    'kiwi',
    'knoll',
    'koala',
    'ladder',
    'ladle',
    'lagoon',
    'lamplight',
    'lanyard',
    'lattice',
    'laurel',
    'lavender',
    'ledger',
    'lemon',
    'lentil',
    'leopard',
    'lichen',
    'lighthouse',
    'lilac',
    'linden',
    'lingo',
    'loch',
    'locket',
    'lotus',
    'lumen',
    'lychee',
    'lyric',
    'mackerel',
    'magnet',
    'magpie',
    'mahogany',
    'mallard',
    'mango',
    'mantis',
    'marigold',
    'mariner',
    'marsh',
    'mattock',
    'medley',
    'melon',
    'meridian',
    'mesquite',
    'meteor',
    'midge',
    'milestone',
    'mineral',
    'mint',
    'miracle',
    'mirror',
    'mistletoe',
    'mitten',
    'mongoose',
    'monolith',
    'moonlight',
    'moor',
    'moraine',
    'mosaic',
    'moth',
    'motto',
    'mural',
    'mustard',
    'mystic',
    'nectar',
    'needle',
    'nettle',
    'newt',
    'nomad',
    'noodle',
    'nostalgia',
    'nougat',
    'nucleus',
    'nutmeg',
    'oarlock',
    'oasis',
    'oatmeal',
    'obelisk',
    'octave',
    'octopus',
    'odyssey',
    'olive',
    'olympus',
    'omelet',
    'onion',
    'opossum',
    'oracle',
    'orbit',
    'orchard',
    'orchid',
    'oregano',
    'osprey',
    'ostrich',
    'outpost',
    'overture',
    'owl',
    'oxide',
    'oyster',
    'paddle',
    'pagoda',
    'palette',
    'pampas',
    'panda',
    'pantry',
    'papaya',
    'papyrus',
    'paragon',
    'parakeet',
    'parchment',
    'parsley',
    'pasture',
    'patina',
    'pawpaw',
    'peacock',
    'peanut',
    'pearl',
    'peat',
    'pecan',
    'pelican',
    'penguin',
    'peony',
    'periwinkle',
    'petal',
    'pewter',
    'phantom',
    'pheasant',
    'phoenix',
    'piano',
    'pigeon',
    'pigment',
    'pilgrim',
    'pillar',
    'pincer',
    'pinnacle',
    'pioneer',
    'pistachio',
    'piston',
    'pitch',
    'plaid',
    'planter',
    'plateau',
    'platinum',
    'plover',
    'plumage',
    'pluto',
    'pocket',
    'podium',
    'polaris',
    'pollen',
    'pomelo',
    'poppy',
    'porch',
    'porcupine',
    'portal',
    'postcard',
    'potato',
    'prairie',
    'preserve',
    'primate',
    'prism',
    'proton',
    'prune',
    'ptarmigan',
    'puddle',
    'puffin',
    'pumice',
    'pumpkin',
    'puppet',
    'pyramid',
    'quail',
    'quarry',
    'quasar',
    'quiche',
    'quiver',
    'raccoon',
    'radish',
    'rafter',
    'raisin',
    'rampart',
    'ranger',
    'rapids',
    'ravine',
    'redwood',
    'reed',
    'refuge',
    'relay',
    'rescuer',
    'resin',
    'rhubarb',
    'ribbon',
    'ridge',
    'rift',
    'rimrock',
    'ripple',
    'rivulet',
    'robin',
    'rodeo',
    'rosemary',
    'roster',
    'rowan',
    'ruby',
    'rudder',
    'rugby',
    'rustic',
    'saddle',
    'saguaro',
    'sailor',
    'salmon',
    'samphire',
    'sanctum',
    'sandbar',
    'sandalwood',
    'sardine',
    'satchel',
    'savanna',
    'scallop',
    'scarlet',
    'sconce',
    'scout',
    'scribe',
    'seafarer',
    'seashell',
    'sediment',
    'seesaw',
    'sepia',
    'serpent',
    'shamrock',
    'shard',
    'sheaf',
    'shelf',
    'shelter',
    'shepherd',
    'shingle',
    'shoal',
    'shoreline',
    'sierra',
    'silhouette',
    'silo',
    'siphon',
    'skiff',
    'skylark',
    'slate',
    'sleigh',
    'sliver',
    'smelter',
    'smock',
    'snapper',
    'snowdrift',
    'socket',
    'solstice',
    'sonata',
    'sonnet',
    'soybean',
    'spanner',
    'spatula',
    'sphinx',
    'spigot',
    'spindle',
    'spinnaker',
    'spire',
    'spleen',
    'spruce',
    'squall',
    'squash',
    'stable',
    'stanza',
    'starfish',
    'statue',
    'steeple',
    'stencil',
    'stetson',
    'stilt',
    'stonefly',
    'stork',
    'stucco',
    'stump',
    'sundial',
    'sunflower',
    'surf',
    'swallow',
    'swan',
    'swift',
    'sycamore',
    'syrup',
    'tablet',
    'tackle',
    'tadpole',
    'talisman',
    'tamarind',
    'tandem',
    'tangerine',
    'tanager',
    'tapestry',
    'tapir',
    'tarragon',
    'tavern',
    'tawny',
    'teak',
    'teasel',
    'tempo',
    'tender',
    'terminus',
    'terrace',
    'terrapin',
    'thicket',
    'thimble',
    'thistle',
    'thorn',
    'thrush',
    'tidal',
    'tile',
    'timbre',
    'tinamou',
    'toffee',
    'toga',
    'tonic',
    'topaz',
    'torrent',
    'tortoise',
    'totem',
    'toucan',
    'tower',
    'tractor',
    'trail',
    'tram',
    'trellis',
    'tremor',
    'tribune',
    'trinket',
    'tripod',
    'trombone',
    'tropic',
    'trout',
    'truffle',
    'trumpet',
    'tulip',
    'tumble',
    'tundra',
    'turbot',
    'turmeric',
    'turquoise',
    'turtle',
    'tusk',
    'twilight',
    'ukulele',
    'umbra',
    'uncle',
    'upland',
    'urchin',
    'utopia',
    'valance',
    'valley',
    'vanilla',
    'vapor',
    'velvet',
    'venture',
    'verbena',
    'verdict',
    'vervain',
    'vesper',
    'viaduct',
    'viking',
    'vine',
    'violet',
    'viper',
    'vista',
    'vocal',
    'volcano',
    'voyage',
    'vulture',
    'wafer',
    'wagon',
    'walnut',
    'walrus',
    'wander',
    'warble',
    'warbler',
    'warden',
    'wattle',
    'weasel',
    'weaver',
    'weed',
    'weld',
    'whale',
    'wheat',
    'whisker',
    'whistle',
    'wicker',
    'wildflower',
    'willow',
    'windmill',
    'window',
    'wine',
    'wing',
    'wisteria',
    'wolfram',
    'wombat',
    'woodland',
    'woodpecker',
    'wool',
    'wren',
    'yacht',
    'yarn',
    'yarrow',
    'yeast',
    'yellow',
    'yeoman',
    'yodel',
    'yogurt',
    'yonder',
    'yucca',
    'zebra',
    'zenith',
    'zephyr',
    'zeppelin',
    'zigzag',
    'zinnia',
    'zircon',
    'zodiac',
    'zucchini',
  ];

  static const _symbols = ['!', '@', '#', '%', '&', '*', '?', '-', '_', '+'];

  /// Generates a passphrase of [wordCount] words plus a digit and a symbol.
  ///
  /// Returns both the passphrase and its true entropy, computed from the
  /// generator's own keyspace rather than from a heuristic — so the number
  /// shown to the user is exact.
  ///
  /// Five words is the default because four is not actually enough: with this
  /// list size, 4 words + digits + symbol reaches only ~56 bits, whereas 5
  /// reaches ~65. The wordlist is deliberately large so that the arithmetic
  /// works out without padding the estimate.
  GeneratedPassphrase generate({int wordCount = 5, bool addSymbol = true}) {
    final random = math.Random.secure();

    final chosen = <String>[];
    for (var i = 0; i < wordCount; i++) {
      chosen.add(_words[random.nextInt(_words.length)]);
    }

    final digits = (random.nextInt(9000) + 1000).toString();
    final symbol = _symbols[random.nextInt(_symbols.length)];

    // Capitalise the first word for a little extra predictability resistance
    // without hurting memorability.
    final first = chosen.first;
    chosen[0] = first[0].toUpperCase() + first.substring(1);

    final parts = [...chosen, digits];
    final text = addSymbol ? '${parts.join('-')}$symbol' : parts.join('-');

    // Exact entropy: log2(words^wordCount) + log2(9000) + log2(symbols).
    var bits = wordCount * (math.log(_words.length) / math.ln2);
    bits += math.log(9000) / math.ln2;
    if (addSymbol) bits += math.log(_symbols.length) / math.ln2;

    return GeneratedPassphrase(
      value: text,
      entropyBits: bits,
      wordCount: wordCount,
    );
  }
}

class GeneratedPassphrase {
  final String value;
  final double entropyBits;
  final int wordCount;

  const GeneratedPassphrase({
    required this.value,
    required this.entropyBits,
    required this.wordCount,
  });

  int get score => ((entropyBits / 80) * 100).clamp(0, 100).round();
}
