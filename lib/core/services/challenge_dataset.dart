import '../models/evaluation_case.dart';
import '../models/threat_analysis.dart';

/// Independent challenge dataset for evaluating ThreatGuard against realistic
/// phishing, scams, social engineering, spam, and legitimate security-related
/// messages.
///
/// This dataset is SEPARATE from the 105-case benchmark in [EvaluationDataset].
/// It is intended for independent validation, not for tuning rules or models.
///
/// Labels were assigned independently of detector output per the protocol in
/// Task 2.5.8. Cases marked `humanReviewPending: true` require human
/// confirmation before being treated as ground truth.
///
/// Total: 65 proposed cases (CH001–CH065).
class ChallengeDataset {
  /// All challenge cases, each with a scenario family for group-aware splitting.
  static const List<EvaluationCase> cases = [
    // --- Category 1: Legitimate bank/security notifications ---
    EvaluationCase(
      id: 'CH001',
      message: 'Your monthly statement for March 2026 is available. View it in the app.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:bank-statement',
    ),
    EvaluationCase(
      id: 'CH002',
      message: 'We detected a login from a new device. If this was you, no action needed.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:security-notification',
    ),
    EvaluationCase(
      id: 'CH003',
      message: 'Your password was changed successfully on April 1. If you did not make this change, contact us.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:password-change-notice',
    ),
    EvaluationCase(
      id: 'CH004',
      message: 'Security alert: unusual activity detected. We have temporarily locked your account. Visit your branch to unlock.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:account-lock-notice',
    ),
    EvaluationCase(
      id: 'CH005',
      message: 'Your card ending in 4521 was used at Merchant X for \$45.20. Reply STOP to block.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:transaction-alert',
    ),
    EvaluationCase(
      id: 'CH006',
      message: 'Two-factor authentication is now enabled on your account. No further action required.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:2fa-enabled',
    ),
    EvaluationCase(
      id: 'CH007',
      message: 'Your account verification is complete. You can now access all features.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:verification-complete',
    ),
    EvaluationCase(
      id: 'CH008',
      message: 'We noticed a sign-in from Chrome on Windows. Was this you? Reply YES or NO.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:signin-confirmation',
    ),

    // --- Category 2: Legitimate password resets and identity verification ---
    EvaluationCase(
      id: 'CH009',
      message: 'Your password reset link has been sent to your email. It expires in 24 hours.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:password-reset-link',
    ),
    EvaluationCase(
      id: 'CH010',
      message: 'Enter the verification code sent to your phone to complete signup.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:otp-entry-prompt',
    ),
    EvaluationCase(
      id: 'CH011',
      message: 'Your identity has been verified. Welcome to Acme Bank.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:identity-verified',
    ),
    EvaluationCase(
      id: 'CH012',
      message: 'To reset your password, visit https://acmebank.com/reset and follow the instructions.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:password-reset-url',
    ),
    EvaluationCase(
      id: 'CH013',
      message: 'Your one-time passcode is 847291. Do not share it with anyone.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:otp-advisory',
    ),
    EvaluationCase(
      id: 'CH014',
      message: 'Please confirm your email address by clicking the link in the message we sent.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:email-confirmation',
    ),
    EvaluationCase(
      id: 'CH015',
      message: 'Your account has been verified. You may now log in using your existing credentials.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:account-verified',
    ),

    // --- Category 3: Legitimate delivery updates and PINs ---
    EvaluationCase(
      id: 'CH016',
      message: 'Your package has been dispatched and will arrive tomorrow. Track it at acme.com/track.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:delivery-dispatch',
    ),
    EvaluationCase(
      id: 'CH017',
      message: 'Your delivery PIN is 4821. Show it to the courier to receive your parcel.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:delivery-pin-provided',
    ),
    EvaluationCase(
      id: 'CH018',
      message: 'Your parcel is ready for pickup at the collection point. Bring your ID.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:parcel-pickup',
    ),
    EvaluationCase(
      id: 'CH019',
      message: 'Delivery scheduled for today between 2-4 PM. No action needed.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:delivery-scheduled',
    ),
    EvaluationCase(
      id: 'CH020',
      message: 'Your package was delivered. Leave feedback at acme.com/feedback.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:delivery-complete',
    ),
    EvaluationCase(
      id: 'CH021',
      message: 'Courier attempted delivery. Reschedule at acme.com/reschedule.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:delivery-reschedule',
    ),
    EvaluationCase(
      id: 'CH022',
      message: 'Your delivery has been delayed. New ETA: tomorrow.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:delivery-delayed',
    ),

    // --- Category 4: Phishing credential requests ---
    EvaluationCase(
      id: 'CH023',
      message: 'Your account will be suspended. Verify your password at http://acme-secure.top/login',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:account-suspension-url',
    ),
    EvaluationCase(
      id: 'CH024',
      message: 'We need your OTP to verify your identity. Reply with the code.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:otp-request-reply',
    ),
    EvaluationCase(
      id: 'CH025',
      message: 'Your bank account is locked. Submit your PIN to unlock it.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:pin-request-unlock',
    ),
    EvaluationCase(
      id: 'CH026',
      message: 'Confirm your login details to avoid account closure. Click here: http://bit.ly/verify',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:login-details-url',
    ),
    EvaluationCase(
      id: 'CH027',
      message: 'Urgent: your password expires today. Update it at http://acme-reset.com',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:password-expiry-url',
    ),
    EvaluationCase(
      id: 'CH028',
      message: 'Your account has been compromised. Enter your credentials at http://secure-acme.net',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:compromised-credentials-url',
    ),
    EvaluationCase(
      id: 'CH029',
      message: 'Verification required: provide your security code to restore access.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:security-code-restore',
    ),
    EvaluationCase(
      id: 'CH030',
      message: 'Your identity must be confirmed. Send your one-time password now.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:phishing:identity-otp-now',
    ),

    // --- Category 5: Social engineering ---
    EvaluationCase(
      id: 'CH031',
      message: 'This is the tax office. Your account has an overdue balance. Pay immediately or face legal action.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:tax-authority-payment',
    ),
    EvaluationCase(
      id: 'CH032',
      message: 'Hi, this is customer support. We need your PIN to verify your account. Do not tell anyone.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:support-pin-secrecy',
    ),
    EvaluationCase(
      id: 'CH033',
      message: 'Your manager asked me to get your login code. Send it urgently.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:manager-login-code',
    ),
    EvaluationCase(
      id: 'CH034',
      message: 'Your delivery service needs your PIN right now to complete the package release.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:se:delivery-pin-urgency',
    ),
    EvaluationCase(
      id: 'CH035',
      message: 'Government notice: your tax refund is pending. Provide your bank details to claim.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:gov-tax-refund',
    ),
    EvaluationCase(
      id: 'CH036',
      message: 'IT department: your password will expire. Reply with your current password to keep access.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:it-password-expiry',
    ),
    EvaluationCase(
      id: 'CH037',
      message: 'Your account has been flagged. Call this number immediately and provide your OTP.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:flagged-account-otp',
    ),
    EvaluationCase(
      id: 'CH038',
      message: 'We are from the fraud department. Do not discuss this with anyone. Provide your PIN.',
      expectedType: ThreatType.socialEngineering,
      expectedLevel: ThreatLevel.highRisk,
      scenarioFamily: 'challenge:se:fraud-dept-secrecy',
    ),

    // --- Category 6: Scam prize/refund/payment ---
    EvaluationCase(
      id: 'CH039',
      message: 'Congratulations! You won \$5000. Pay the \$50 processing fee to claim.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:prize-processing-fee',
    ),
    EvaluationCase(
      id: 'CH040',
      message: 'You have been selected for a cash reward. Enter your card details to receive it.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:cash-reward-card',
    ),
    EvaluationCase(
      id: 'CH041',
      message: 'Your refund of \$200 is ready. Provide your bank account to receive it.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:refund-bank-details',
    ),
    EvaluationCase(
      id: 'CH042',
      message: 'You won a lottery. Send \$100 to unlock your prize.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:lottery-unlock',
    ),
    EvaluationCase(
      id: 'CH043',
      message: 'Exclusive offer: claim your \$1000 gift card. Pay shipping only.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:gift-card-shipping',
    ),
    EvaluationCase(
      id: 'CH044',
      message: 'Your payment was declined. Update your card details to avoid service interruption.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:payment-declined-card',
    ),
    EvaluationCase(
      id: 'CH045',
      message: 'You have an unclaimed prize. Reply with your account number to claim.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:unclaimed-prize',
    ),
    EvaluationCase(
      id: 'CH046',
      message: 'Refund notification: your \$500 refund is pending. Provide your bank details.',
      expectedType: ThreatType.scam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:scam:refund-pending-bank',
    ),

    // --- Category 7: Suspicious without URLs ---
    EvaluationCase(
      id: 'CH047',
      message: 'Please verify your account by replying with your password.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:phishing:bare-password-reply',
    ),
    EvaluationCase(
      id: 'CH048',
      message: 'Your account needs verification. Send your login details.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:phishing:bare-login-details',
    ),
    EvaluationCase(
      id: 'CH049',
      message: 'We need to confirm your identity. Provide your security code.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:phishing:bare-security-code',
    ),
    EvaluationCase(
      id: 'CH050',
      message: 'Account update required. Submit your credentials.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:phishing:bare-credentials',
    ),
    EvaluationCase(
      id: 'CH051',
      message: 'Verification pending: enter your one-time code.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:phishing:bare-otp-entry',
    ),
    EvaluationCase(
      id: 'CH052',
      message: 'Your account is under review. Confirm your password.',
      expectedType: ThreatType.phishing,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:phishing:bare-password-confirm',
    ),

    // --- Category 8: Benign with trigger words ---
    EvaluationCase(
      id: 'CH053',
      message: 'The password reset feature is now available in settings.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:password-reset-feature',
    ),
    EvaluationCase(
      id: 'CH054',
      message: 'Please verify your email to continue using the app.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:email-verify-prompt',
    ),
    EvaluationCase(
      id: 'CH055',
      message: 'Urgent: server maintenance tonight. No action needed.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:urgent-maintenance',
    ),
    EvaluationCase(
      id: 'CH056',
      message: 'Your account balance is \$1,234.56. View details in app.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:account-balance',
    ),
    EvaluationCase(
      id: 'CH057',
      message: 'PIN protection is enabled on your device.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:pin-protection',
    ),
    EvaluationCase(
      id: 'CH058',
      message: 'Verification codes expire after 5 minutes.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:verification-expiry',
    ),
    EvaluationCase(
      id: 'CH059',
      message: 'Your password must be at least 8 characters.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:password-policy',
    ),
    EvaluationCase(
      id: 'CH060',
      message: 'Account security tips: never share your OTP.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:legit:security-tips',
    ),

    // --- Category 9: Ambiguous/uncertain (human review recommended) ---
    EvaluationCase(
      id: 'CH061',
      message: 'Your account may have been accessed. Please review your recent activity.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:ambiguous:account-access-review',
    ),
    EvaluationCase(
      id: 'CH062',
      message: 'We noticed a login attempt. If this wasn\'t you, reset your password.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:ambiguous:login-attempt-reset',
    ),
    EvaluationCase(
      id: 'CH063',
      message: 'Your delivery is delayed. Contact support if needed.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:ambiguous:delivery-delay',
    ),
    EvaluationCase(
      id: 'CH064',
      message: 'Payment of \$50 received. Thank you.',
      expectedType: ThreatType.legitimate,
      expectedLevel: ThreatLevel.safe,
      scenarioFamily: 'challenge:ambiguous:payment-received',
    ),
    EvaluationCase(
      id: 'CH065',
      message: 'Your subscription expires soon. Renew to continue.',
      expectedType: ThreatType.spam,
      expectedLevel: ThreatLevel.suspicious,
      scenarioFamily: 'challenge:ambiguous:subscription-renewal',
    ),
  ];
}
