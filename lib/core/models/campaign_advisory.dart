/// A known scam campaign, described so a user can recognise it.
class CampaignAdvisory {
  final String id;
  final String title;
  final String category;

  /// A short summary of how the scam works.
  final String summary;

  /// Actual wording patterns used in the campaign, so this doubles as a
  /// recognition aid. Written as paraphrases, not copied messages.
  final List<String> typicalWording;

  /// What the attacker is after.
  final String objective;

  /// The countermeasure, in one sentence.
  final String defence;

  /// Which ThreatGuard tool to reach for.
  final String relatedTool;

  const CampaignAdvisory({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.typicalWording,
    required this.objective,
    required this.defence,
    required this.relatedTool,
  });
}

/// Bundled, offline campaign advisories.
///
/// This is deliberately offline data rather than a live feed: it works with no
/// network, cannot be tampered with in transit, and doubles as the educational
/// surface that makes the rest of the app easier to understand.
class ThreatFeedCatalog {
  const ThreatFeedCatalog();

  static const List<CampaignAdvisory> campaigns = [
    CampaignAdvisory(
      id: 'parcel_fee',
      title: 'Parcel held — pay a release fee',
      category: 'Delivery scam',
      summary:
          'A message claims a parcel is waiting but needs a small fee, or a '
          'redelivery charge, before it can be handed over. The amount is '
          'small enough to feel harmless, which is the point — the real prize '
          'is the card details entered on the payment page.',
      typicalWording: [
        'Your parcel is held at our depot',
        'A redelivery fee of Rs. ___ is required',
        'Pay within 24 hours or the item is returned',
        'Update your delivery address using the link',
      ],
      objective: 'Card details, then recurring charges on the compromised card',
      defence:
          'Real couriers do not collect fees by text link. Track the parcel '
          'through the courier\'s own app or website, using a number you look '
          'up yourself.',
      relatedTool: 'Check the link in Link scanner',
    ),
    CampaignAdvisory(
      id: 'bank_sms_phishing',
      title: 'Bank account suspended',
      category: 'Phishing',
      summary:
          'A message says your account has been suspended or that unusual '
          'activity was detected, and asks you to verify your details through '
          'a link. The wording is designed to be alarming enough that you act '
          'before you think.',
      typicalWording: [
        'Your account has been suspended',
        'Unusual activity was detected on your account',
        'Verify your identity to restore access',
        'This link expires in 24 hours',
      ],
      objective: 'Internet banking credentials, OTPs and card numbers',
      defence:
          'Never open a bank link from a message. Open your bank\'s own app, or '
          'call the number printed on your card.',
      relatedTool: 'Check the message in Check, then the link in Link scanner',
    ),
    CampaignAdvisory(
      id: 'otp_social_engineering',
      title: '"Read me the code that was just sent"',
      category: 'Social engineering',
      summary:
          'Someone calls or messages pretending to be your bank, a delivery '
          'service or a technical support desk, and asks you to read out the '
          'one-time code that just arrived. The code is the last step of a '
          'login they have already started.',
      typicalWording: [
        'I am calling from the security team',
        'Please confirm the code we just sent you',
        'Do not share this code with anyone',
        'You must act before the transaction completes',
      ],
      objective: 'The one-time code, which completes an account takeover',
      defence:
          'No legitimate organisation will ever ask for a one-time code. If '
          'anyone asks, end the call and dial the number on your card.',
      relatedTool: 'Check the message in Check',
    ),
    CampaignAdvisory(
      id: 'prize_lottery',
      title: 'You have won a prize',
      category: 'Advance-fee scam',
      summary:
          'An unexpected win in a lottery or draw you never entered, with a '
          'fee, tax or delivery charge to release it. The "prize" never '
          'arrives; the fee does.',
      typicalWording: [
        'Congratulations, you have won',
        'Your number was selected at random',
        'Pay the processing fee to claim',
        'Send your bank account number to receive the funds',
      ],
      objective: 'An upfront fee, then banking details for account takeover',
      defence:
          'You cannot win a draw you never entered. Delete anything asking for '
          'money to release money.',
      relatedTool: 'Check the message in Check',
    ),
    CampaignAdvisory(
      id: 'job_offer',
      title: 'Easy work, high pay, upfront cost',
      category: 'Employment scam',
      summary:
          'An unsolicited job offer, often remote and part-time, that promises '
          'strong pay for simple tasks. It escalates into a registration fee, '
          'a "training deposit", or a request to receive and forward money.',
      typicalWording: [
        'Earn from home part time',
        'No experience needed, immediate start',
        'Small registration deposit required',
        'Receive payments and forward them on',
      ],
      objective: 'A fee, or use of your account as a money-mule layer',
      defence:
          'A real employer never asks a candidate for money. Verify the company '
          'through its own website, not the one in the message.',
      relatedTool: 'Check the message in Check',
    ),
    CampaignAdvisory(
      id: 'sim_swap',
      title: 'SIM-swap and number porting',
      category: 'Account takeover',
      summary:
          'An attacker ports your number to a SIM they control, then receives '
          'every one-time code sent to you. It often starts with a call or '
          'message claiming to confirm a porting request you did not make.',
      typicalWording: [
        'Confirm your porting request',
        'Your number will be transferred today',
        'Reply with the code to cancel',
        'We noticed a SIM change on your account',
      ],
      objective:
          'Control of your phone number, and therefore of every '
          'SMS-based second factor',
      defence:
          'Contact your carrier immediately through a number you look up '
          'yourself. Move critical accounts to an authenticator app rather '
          'than SMS codes.',
      relatedTool: 'Check your number in Breach check',
    ),
    CampaignAdvisory(
      id: 'romance_investment',
      title: 'Long con: relationship, then investment',
      category: 'Investment fraud',
      summary:
          'A friendly or romantic contact builds trust over weeks, then '
          'introduces an investment platform with impossible returns. Early '
          'small withdrawals work, to encourage a large deposit.',
      typicalWording: [
        'I want to help you succeed',
        'A friend showed me this platform',
        'You can withdraw anytime',
        'Let us increase the amount together',
      ],
      objective: 'A large irreversible transfer',
      defence:
          'Anyone who introduces an investment opportunity over a chat app is '
          'running this play. Check the platform against your regulator\'s '
          'warning list before sending anything.',
      relatedTool: 'Check links in Link scanner',
    ),
    CampaignAdvisory(
      id: 'fake_support',
      title: 'Technical support pop-up',
      category: 'Tech support scam',
      summary:
          'A page or message claims your phone is infected and offers a number '
          'to call. The "agent" then asks for remote access or a payment for '
          'unnecessary software.',
      typicalWording: [
        'Your device is infected with a virus',
        'Call this number immediately',
        'Do not close this window',
        'We need remote access to clean your device',
      ],
      objective: 'Remote access to your device, or a card payment',
      defence:
          'No legitimate security product reports a virus via a pop-up with a '
          'phone number. Close the tab or app and delete the message.',
      relatedTool: 'Check the message in Check',
    ),
  ];

  List<CampaignAdvisory> get all => campaigns;

  /// All categories present, for filtering.
  List<String> get categories =>
      campaigns.map((c) => c.category).toSet().toList()..sort();

  List<CampaignAdvisory> byCategory(String category) =>
      campaigns.where((c) => c.category == category).toList();
}
