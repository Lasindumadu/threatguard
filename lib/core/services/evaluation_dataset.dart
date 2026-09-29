import '../models/evaluation_case.dart';
import '../models/threat_analysis.dart';

class EvaluationDataset {
  static const List<EvaluationCase> cases = [
    // ============================================================
    // LEGITIMATE
    // ============================================================

    EvaluationCase(
      id: 'legitimate_001',
      message:
          'Hi, your meeting is scheduled for tomorrow at 10 AM. See you there.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_002',
      message:
          'Your order has been shipped and will arrive tomorrow afternoon.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_003',
      message:
          'Here is the website for our event tomorrow: https://example.com',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_004',
      message: 'Please remember that your appointment is scheduled for Friday at 2 PM.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_005',
      message: 'The project documents have been uploaded to the shared folder.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    // Hard-negative legitimate messages.
    EvaluationCase(
      id: 'legitimate_006',
      message:
          'Your account security review is complete. No action is required.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_007',
      message: 'The delivery company will contact you tomorrow regarding your package.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_008',
      message: 'Please use the official website to check your order status.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_009',
      message: 'Our customer support team is available today if you have any questions.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),
    EvaluationCase(
      id: 'legitimate_010',
      message: 'Your verification code will be sent when you sign in to the application.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    // ============================================================
    // SPAM
    // ============================================================
    EvaluationCase(
      id: 'spam_001',
      message: 'Special offer! Get 50% off selected products this weekend.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_002',
      message: 'Limited time offer! Subscribe today and receive a free reward.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_003',
      message: 'Congratulations! Our store has a special reward available for selected customers.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_004',
      message: 'Act now to receive our latest promotional discount before the offer expires today.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_005',
      message: 'Free money and rewards are available for a limited number of customers.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_006',
      message: 'Exclusive discount available for selected customers this week.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_007',
      message: 'Subscribe today and enjoy our latest promotional offer.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_008',
      message: 'Special reward available for a limited number of customers.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_009',
      message: 'Get a special discount on selected products before the offer expires.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'spam_010',
      message: 'Limited time promotion: receive a free reward when you subscribe today.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    // ============================================================
    // PHISHING
    // ============================================================
    EvaluationCase(
      id: 'phishing_001',
      message: 'URGENT! Your bank account will be suspended today. Verify your account immediately using https://example.com/login and enter your password and OTP.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_002',
      message: 'Your account has been locked due to unusual activity. Verify your identity using https://example.com and enter your security code.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_003',
      message: 'Security alert: your account will be closed unless you confirm your login details immediately.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_004',
      message: 'Your verification is required. Please provide your password and one-time password to restore access.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'phishing_005',
      message: 'Unusual activity was detected on your account. Login now at https://example.com to verify your identity.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'phishing_006',
      message: 'Your account will be closed today. Enter your password to keep your account active.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_007',
      message: 'Security alert. Please enter your verification code at https://example.com to restore access.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_008',
      message: 'Your account has been locked. Provide your login details to unlock it.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_009',
      message: 'Verify your account immediately by entering your PIN and security code.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'phishing_010',
      message: 'Your identity verification is required. Submit your password to complete verification.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
    ),

    // ============================================================
    // SCAM
    // ============================================================
    EvaluationCase(
      id: 'scam_001',
      message: 'Congratulations! You have won a \$5,000 cash prize. Claim your prize now by visiting https://example.com.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_002',
      message: 'You have won the national lottery. Send your bank account number to receive your prize.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_003',
      message: 'Free money is waiting for you. Pay the processing fee now to claim your reward.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_004',
      message: 'Congratulations winner! Transfer money immediately to unlock your cash prize.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_005',
      message: 'You have been selected for a special reward. Provide your credit card details to receive the payment.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_006',
      message: 'You won a cash reward. Pay the processing fee to release your prize.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_007',
      message: 'Congratulations winner! Send money now to receive your lottery payment.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_008',
      message: 'Free money is available. Provide your bank account number to receive the reward.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_009',
      message: 'You have been selected for a cash prize. Pay the required fee to claim it.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'scam_010',
      message: 'Lottery winner notification: transfer the required payment to unlock your prize.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    // ============================================================
    // SOCIAL ENGINEERING
    // ============================================================
    EvaluationCase(
      id: 'social_001',
      message: 'This is the bank security department. Do not tell anyone about this request. Act immediately and send your verification code.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'social_002',
      message: 'This is customer support. Keep this confidential and send your security code immediately.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'social_003',
      message: 'The government department requires your account number immediately. Do not share this request with anyone.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'social_004',
      message: 'Your delivery company needs your verification code right now to release the package.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'social_005',
      message: 'A security officer needs your PIN immediately. Please keep this request confidential.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'social_006',
      message: 'This is the bank security team. Send your verification code immediately to prevent your account from being suspended.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'social_007',
      message: 'Customer service requires your security code right now. Do not share this request with anyone.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'social_008',
      message: 'The tax department needs your account number immediately. Keep this request confidential.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
    EvaluationCase(
      id: 'social_009',
      message: 'A support officer needs your PIN right now to complete the account verification.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'social_010',
      message: 'The delivery company requires your verification code immediately to release your package.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
    ),
    EvaluationCase(
      id: 'legitimate_011',
      message: 'Your account statement is ready. You can view it through the official banking application.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_012',
      message: 'Our IT team will perform scheduled maintenance tonight from 11 PM to 1 AM.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_013',
      message: 'Please verify your account details with the customer service desk during your next visit.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_014',
      message: 'Your package is ready for collection. Please bring your identification document.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_015',
      message: 'The company security team has published a notice about scheduled password maintenance.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_016',
      message: 'You can review your monthly invoice at https://example.com/invoices.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_017',
      message: 'Please contact customer support if you have questions about your recent payment.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_018',
      message: 'The office access system will be unavailable during scheduled maintenance.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'spam_011',
      message: 'Special offer available today. Get 30% off selected products.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_012',
      message:
          'Limited time offer! Subscribe today and receive a special reward.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_013',
      message: 'Congratulations! You have been selected for our promotional campaign.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'phishing_011',
      message: 'Your account has been locked. Verify your identity to restore access.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'phishing_012',
      message: 'Security alert: unusual activity was detected. Enter your password to continue.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'phishing_013',
      message: 'Please enter your verification code to confirm your account immediately.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'phishing_014',
      message: 'Your account verification is required. Provide your login details to continue.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'phishing_015',
      message: 'Your security verification is incomplete. Enter your PIN to finish the process.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'scam_011',
      message: 'You have been selected for a cash reward. Pay a small processing fee to receive it.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_012',
      message: 'Congratulations, your reward is ready. Send money to release the funds.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_013',
      message: 'Your prize is waiting. Transfer the required payment before collection.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_014',
      message: 'You were selected for a special cash reward. Pay the required fee to claim it.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'social_011',
      message: 'This is the bank security department. Send your verification code immediately.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'social_012',
      message: 'Customer support needs your security code right now to complete the account verification.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'social_013',
      message: 'The delivery company requires your PIN immediately to release your package.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'social_014',
      message: 'The tax department needs your account number immediately. Keep this request confidential.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'social_015',
      message: 'A support officer needs your verification code right now to complete your account verification.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // ============================================================
    // ADDITIONAL DATASET CASES — V0.6 DATASET STRENGTHENING
    // ============================================================

    // ============================================================
    // ADDITIONAL LEGITIMATE
    // ============================================================
    EvaluationCase(
      id: 'legitimate_019',
      message: 'Your bank account statement is now available. Please review it through the official banking application.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_020',
      message: 'The security team completed the scheduled review of your account. No action is required.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_021',
      message: 'Please visit https://example.com/account to view your latest account statement.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_022',
      message: 'Your identity document is ready for collection. Please bring your identification when you visit the office.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_023',
      message: 'The IT department will perform routine security maintenance on the account system tonight.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    EvaluationCase(
      id: 'legitimate_024',
      message: 'Your payment has been received successfully. Contact customer support if you need assistance.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
    ),

    // ============================================================
    // ADDITIONAL SPAM
    // ============================================================
    EvaluationCase(
      id: 'spam_014',
      message: 'Weekend promotion! Get 40% off selected products while the special offer lasts.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_015',
      message: 'Subscribe today and receive an exclusive promotional reward from our store.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_016',
      message: 'Limited time discount available now for selected customers. Shop today.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_017',
      message: 'Special promotion! Receive a free reward when you join our customer program.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_018',
      message: 'Exclusive offer available this week. Enjoy a special discount on selected products.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'spam_019',
      message: 'Congratulations! You have been selected for a special promotional reward from our store.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    // ============================================================
    // ADDITIONAL PHISHING
    // ============================================================

    // IP-address URL
    EvaluationCase(
      id: 'phishing_016',
      message: 'URGENT! Your bank account will be suspended. Verify your account at http://192.168.1.10/login immediately.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // Punycode URL
    EvaluationCase(
      id: 'phishing_017',
      message: 'Security alert: verify your account immediately at https://xn--pple-43d.com/verify to prevent suspension.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // Embedded credentials in URL
    EvaluationCase(
      id: 'phishing_018',
      message: 'Your account requires verification. Continue at https://user:pass@example.com/login to restore access.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // Non-standard port
    EvaluationCase(
      id: 'phishing_019',
      message: 'Your account has been locked. Verify your identity at https://example.com:8080/login immediately.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // Excessive subdomains
    EvaluationCase(
      id: 'phishing_020',
      message: 'Security alert! Confirm your account at https://login.security.verify.account.example.com/login.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // URL shortener
    EvaluationCase(
      id: 'phishing_021',
      message: 'Your account verification is required. Open https://bit.ly/account-check immediately to restore access.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // ============================================================
    // ADDITIONAL SCAM
    // ============================================================
    EvaluationCase(
      id: 'scam_015',
      message: 'You have won a cash reward. Pay the required processing fee before the prize can be released.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_016',
      message: 'Your lottery prize is ready. Transfer the required payment to receive the funds.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_017',
      message: 'Congratulations! A cash prize has been reserved for you. Provide your bank account number to receive it.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_018',
      message: 'You were selected for a special reward. Pay the small release fee before collecting your prize.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'scam_019',
      message: 'A cash reward is waiting for you. Transfer money now to complete the prize collection.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    // Scam with a URL signal rather than relying only on prize wording.
    EvaluationCase(
      id: 'scam_020',
      message: 'Your cash prize is ready. Pay the processing fee at https://bit.ly/prize-claim to receive your reward.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
    ),

    // ============================================================
    // ADDITIONAL SOCIAL ENGINEERING
    // ============================================================
    EvaluationCase(
      id: 'social_016',
      message: 'This is the bank security team. Send your verification code immediately so we can secure your account.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'social_017',
      message: 'The government security office requires your account number immediately. Keep this request confidential.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    EvaluationCase(
      id: 'social_018',
      message: 'Your delivery service needs your PIN right now to complete the package release.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
    ),

    EvaluationCase(
      id: 'social_019',
      message: 'Customer support needs your verification code immediately to finish your account verification.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // Social engineering with a suspicious URL.
    EvaluationCase(
      id: 'social_020',
      message: 'This is the bank security department. Verify your account immediately at https://bit.ly/security-check and send your verification code.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),

    // Social engineering using an authority + credential pattern.
    EvaluationCase(
      id: 'social_021',
      message: 'The tax department requires your security code now to complete your account verification. Do not share this request.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
    ),
  ];
}
