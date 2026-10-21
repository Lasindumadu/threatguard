import 'message_source.dart';

/// How much to trust a channel, and what to call it in the UI.
///
/// This exists because provenance is evidence. A link in a DM from an unknown
/// Instagram handle has a different base rate of malice than the same link in a
/// message from a bank shortcode, and an app that ignores that is leaving
/// signal on the floor.
class ChannelProfile {
  final MessageSource source;

  /// Human-readable name, shown as "Checked from WhatsApp".
  final String displayName;

  /// Short name for dense list rows.
  final String shortName;

  /// Extra risk points added to a message that carries a URL.
  ///
  /// Only applied when the message actually contains a link: an unsolicited DM
  /// *with a link* is the classic attack shape. A plain DM with no link is not
  /// made suspicious merely by its channel.
  final int urlRiskBonus;

  /// True when messages on this channel are typically unsolicited.
  final bool isTypicallyUnsolicited;

  /// True when ThreatGuard can read this channel automatically, as opposed to
  /// only receiving it via the share sheet. Used to keep the UI honest.
  final bool isAutomaticallyRead;

  const ChannelProfile({
    required this.source,
    required this.displayName,
    required this.shortName,
    required this.urlRiskBonus,
    required this.isTypicallyUnsolicited,
    required this.isAutomaticallyRead,
  });

  bool get isUserInvoked => !isAutomaticallyRead;

  static const Map<MessageSource, ChannelProfile> _profiles = {
    MessageSource.sms: ChannelProfile(
      source: MessageSource.sms,
      displayName: 'SMS',
      shortName: 'SMS',
      // Bank shortcodes and delivery notifications legitimately contain links.
      urlRiskBonus: 0,
      isTypicallyUnsolicited: false,
      isAutomaticallyRead: true,
    ),
    MessageSource.manual: ChannelProfile(
      source: MessageSource.manual,
      displayName: 'Pasted into ThreatGuard',
      shortName: 'Manual',
      urlRiskBonus: 0,
      isTypicallyUnsolicited: false,
      isAutomaticallyRead: false,
    ),
    MessageSource.share: ChannelProfile(
      source: MessageSource.share,
      displayName: 'Shared to ThreatGuard',
      shortName: 'Shared',
      urlRiskBonus: 2,
      isTypicallyUnsolicited: false,
      isAutomaticallyRead: false,
    ),
    MessageSource.clipboard: ChannelProfile(
      source: MessageSource.clipboard,
      displayName: 'Clipboard',
      shortName: 'Clipboard',
      urlRiskBonus: 4,
      isTypicallyUnsolicited: false,
      isAutomaticallyRead: false,
    ),
    MessageSource.whatsapp: ChannelProfile(
      source: MessageSource.whatsapp,
      displayName: 'WhatsApp',
      shortName: 'WhatsApp',
      // A link from a non-contact handle on a consumer messenger is a strong
      // prior for phishing.
      urlRiskBonus: 6,
      isTypicallyUnsolicited: true,
      isAutomaticallyRead: false,
    ),
    MessageSource.messenger: ChannelProfile(
      source: MessageSource.messenger,
      displayName: 'Facebook Messenger',
      shortName: 'Messenger',
      urlRiskBonus: 6,
      isTypicallyUnsolicited: true,
      isAutomaticallyRead: false,
    ),
    MessageSource.instagram: ChannelProfile(
      source: MessageSource.instagram,
      displayName: 'Instagram',
      shortName: 'Instagram',
      urlRiskBonus: 6,
      isTypicallyUnsolicited: true,
      isAutomaticallyRead: false,
    ),
    MessageSource.email: ChannelProfile(
      source: MessageSource.email,
      displayName: 'E-mail',
      shortName: 'E-mail',
      urlRiskBonus: 4,
      isTypicallyUnsolicited: true,
      isAutomaticallyRead: false,
    ),
    MessageSource.web: ChannelProfile(
      source: MessageSource.web,
      displayName: 'Web page',
      shortName: 'Web',
      urlRiskBonus: 5,
      isTypicallyUnsolicited: true,
      isAutomaticallyRead: false,
    ),
  };

  static ChannelProfile of(MessageSource source) {
    return _profiles[source] ?? _profiles[MessageSource.manual]!;
  }

  static List<ChannelProfile> get all => _profiles.values.toList();

  /// Map an Android share-sheet package name onto a channel.
  ///
  /// Falls back to [MessageSource.share] when the source app is unknown, rather
  /// than guessing: a wrong provenance label would be a lie in the UI.
  static MessageSource fromPackageName(String? packageName) {
    if (packageName == null || packageName.isEmpty) {
      return MessageSource.share;
    }

    final p = packageName.toLowerCase();

    if (p.contains('whatsapp')) return MessageSource.whatsapp;
    if (p.contains('instagram')) return MessageSource.instagram;
    if (p.contains('facebook') || p.contains('orca')) {
      return MessageSource.messenger;
    }
    if (p.contains('gmail') ||
        p.endsWith('.gm') ||
        p.contains('mail') ||
        p.contains('outlook') ||
        p.contains('yahoo') ||
        p.contains('proton')) {
      return MessageSource.email;
    }
    if (p.contains('chrome') ||
        p.contains('browser') ||
        p.contains('firefox') ||
        p.contains('opera') ||
        p.contains('brave') ||
        p.contains('sbrowser') ||
        p.contains('webview')) {
      return MessageSource.web;
    }
    if (p.contains('messaging') || p.contains('mms')) {
      return MessageSource.sms;
    }

    return MessageSource.share;
  }
}
