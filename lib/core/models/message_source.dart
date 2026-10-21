/// Where a message came from.
///
/// Provenance is a real risk input, not just a label: an unsolicited link
/// arriving in a WhatsApp or Instagram DM from an unknown handle is materially
/// riskier than the same link in an SMS from a known bank shortcode. The
/// channel therefore participates in scoring (see `ChannelProfile`).
///
/// Note which of these are *read* automatically and which are user-invoked:
/// nothing can read WhatsApp/Messenger/Instagram message databases (they are
/// encrypted and have no read API). Those channels arrive via the Android
/// share sheet, and [MessageSource.share] records that.
enum MessageSource {
  /// Typed or pasted directly into the app.
  manual,

  /// Read from the device SMS inbox.
  sms,

  /// Delivered through the Android share sheet from another app.
  share,

  /// Detected on the clipboard (opt-in).
  clipboard,

  /// Shared out of WhatsApp.
  whatsapp,

  /// Shared out of Facebook Messenger.
  messenger,

  /// Shared out of Instagram.
  instagram,

  /// Shared out of an e-mail client.
  email,

  /// Shared out of a browser / web page.
  web,
}
