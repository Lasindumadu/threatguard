/// Challenge dataset annotation metadata.
///
/// This file provides review status, rationale, and context for each case in
/// [ChallengeDataset]. It is kept separate from [EvaluationCase] to avoid
/// modifying the shared model.
///
/// Review statuses:
/// - `approved`: label independently verified, safe for primary metrics.
/// - `pendingReview`: label uncertain, excluded from primary metrics.
class ChallengeAnnotation {
  final String caseId;
  final String reviewStatus;
  final String intendedContext;
  final String rationale;
  final String reviewNote;

  const ChallengeAnnotation({
    required this.caseId,
    required this.reviewStatus,
    required this.intendedContext,
    required this.rationale,
    this.reviewNote = '',
  });
}

/// Annotations for all 65 challenge cases (CH001–CH065).
///
/// Every case ID must appear exactly once. Pending-review cases are excluded
/// from primary evaluation metrics.
class ChallengeAnnotations {
  static const List<ChallengeAnnotation> all = [
    // --- Category 1: Legitimate bank/security notifications ---
    ChallengeAnnotation(
      caseId: 'CH001',
      reviewStatus: 'approved',
      intendedContext: 'Monthly bank statement notification',
      rationale: 'Routine statement availability, no credential request or threat.',
    ),
    ChallengeAnnotation(
      caseId: 'CH002',
      reviewStatus: 'approved',
      intendedContext: 'New device login notification',
      rationale: 'Informational security notice, no action required.',
    ),
    ChallengeAnnotation(
      caseId: 'CH003',
      reviewStatus: 'approved',
      intendedContext: 'Password change confirmation',
      rationale: 'Confirmation of completed action, not a request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH004',
      reviewStatus: 'approved',
      intendedContext: 'Account lock notice with branch visit instruction',
      rationale: 'Legitimate security action, no credential disclosure requested.',
    ),
    ChallengeAnnotation(
      caseId: 'CH005',
      reviewStatus: 'approved',
      intendedContext: 'Transaction alert with stop option',
      rationale: 'Standard transaction notification, no threat.',
    ),
    ChallengeAnnotation(
      caseId: 'CH006',
      reviewStatus: 'approved',
      intendedContext: '2FA enabled confirmation',
      rationale: 'Feature activation notice, no action required.',
    ),
    ChallengeAnnotation(
      caseId: 'CH007',
      reviewStatus: 'approved',
      intendedContext: 'Account verification complete',
      rationale: 'Completion notice, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH008',
      reviewStatus: 'approved',
      intendedContext: 'Sign-in confirmation prompt',
      rationale: 'User-initiated confirmation, no disclosure requested.',
    ),

    // --- Category 2: Legitimate password resets and identity verification ---
    ChallengeAnnotation(
      caseId: 'CH009',
      reviewStatus: 'approved',
      intendedContext: 'Password reset link sent notification',
      rationale: 'Informational, link already sent, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH010',
      reviewStatus: 'pendingReview',
      intendedContext: 'OTP entry prompt during signup',
      rationale: 'Legitimate if sender is the app the user independently opened; phishing if unverified sender.',
      reviewNote: 'Sender trust unverified. Keep pending until human review confirms legitimate context.',
    ),
    ChallengeAnnotation(
      caseId: 'CH011',
      reviewStatus: 'approved',
      intendedContext: 'Identity verification complete welcome',
      rationale: 'Completion notice, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH012',
      reviewStatus: 'approved',
      intendedContext: 'Password reset URL provided',
      rationale: 'Legitimate URL to trusted domain, user-initiated reset.',
    ),
    ChallengeAnnotation(
      caseId: 'CH013',
      reviewStatus: 'approved',
      intendedContext: 'OTP advisory with do-not-share instruction',
      rationale: 'Advisory, not a request to disclose. Correctly legitimate.',
    ),
    ChallengeAnnotation(
      caseId: 'CH014',
      reviewStatus: 'approved',
      intendedContext: 'Email confirmation prompt',
      rationale: 'Standard email verification, no credential disclosure.',
    ),
    ChallengeAnnotation(
      caseId: 'CH015',
      reviewStatus: 'approved',
      intendedContext: 'Account verified, login with existing credentials',
      rationale: 'Completion notice, no credential request.',
    ),

    // --- Category 3: Legitimate delivery updates and PINs ---
    ChallengeAnnotation(
      caseId: 'CH016',
      reviewStatus: 'approved',
      intendedContext: 'Package dispatched with tracking link',
      rationale: 'Standard delivery notification, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH017',
      reviewStatus: 'approved',
      intendedContext: 'Delivery PIN provided to recipient',
      rationale: 'PIN given to recipient to show courier, not requested from them.',
    ),
    ChallengeAnnotation(
      caseId: 'CH018',
      reviewStatus: 'approved',
      intendedContext: 'Parcel ready for pickup',
      rationale: 'Standard pickup notice, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH019',
      reviewStatus: 'approved',
      intendedContext: 'Delivery scheduled notification',
      rationale: 'Informational, no action required.',
    ),
    ChallengeAnnotation(
      caseId: 'CH020',
      reviewStatus: 'approved',
      intendedContext: 'Delivery complete with feedback link',
      rationale: 'Standard post-delivery notice.',
    ),
    ChallengeAnnotation(
      caseId: 'CH021',
      reviewStatus: 'approved',
      intendedContext: 'Delivery reschedule prompt',
      rationale: 'User-initiated reschedule link, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH022',
      reviewStatus: 'approved',
      intendedContext: 'Delivery delay notification',
      rationale: 'Informational, no action required.',
    ),

    // --- Category 4: Phishing credential requests ---
    ChallengeAnnotation(
      caseId: 'CH023',
      reviewStatus: 'approved',
      intendedContext: 'Account suspension with credential request via URL',
      rationale: 'Credential harvesting via urgency + URL. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH024',
      reviewStatus: 'approved',
      intendedContext: 'OTP disclosure request in reply',
      rationale: 'Asks recipient to disclose OTP in reply. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH025',
      reviewStatus: 'approved',
      intendedContext: 'PIN disclosure request for account unlock',
      rationale: 'Asks recipient to submit PIN. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH026',
      reviewStatus: 'approved',
      intendedContext: 'Login details confirmation via shortened URL',
      rationale: 'Credential harvesting via shortened link. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH027',
      reviewStatus: 'approved',
      intendedContext: 'Password expiry with update URL',
      rationale: 'Urgency + credential request + URL. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH028',
      reviewStatus: 'approved',
      intendedContext: 'Compromised account with credential entry URL',
      rationale: 'Fear + credential request + URL. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH029',
      reviewStatus: 'approved',
      intendedContext: 'Security code disclosure to restore access',
      rationale: 'Credential request with account threat. Clear phishing.',
    ),
    ChallengeAnnotation(
      caseId: 'CH030',
      reviewStatus: 'approved',
      intendedContext: 'Identity confirmation with OTP disclosure',
      rationale: 'Credential request with urgency. Clear phishing.',
    ),

    // --- Category 5: Social engineering ---
    ChallengeAnnotation(
      caseId: 'CH031',
      reviewStatus: 'approved',
      intendedContext: 'Tax authority payment threat',
      rationale: 'Authority + fear + financial request. Clear social engineering.',
    ),
    ChallengeAnnotation(
      caseId: 'CH032',
      reviewStatus: 'approved',
      intendedContext: 'Support agent PIN request with secrecy',
      rationale: 'Authority + credential request + secrecy. Clear social engineering.',
    ),
    ChallengeAnnotation(
      caseId: 'CH033',
      reviewStatus: 'approved',
      intendedContext: 'Manager impersonation login code request',
      rationale: 'Authority impersonation + credential request + urgency. Clear.',
    ),
    ChallengeAnnotation(
      caseId: 'CH034',
      reviewStatus: 'approved',
      intendedContext: 'Delivery PIN request with urgency',
      rationale: 'Authority + credential request + urgency. Social engineering.',
    ),
    ChallengeAnnotation(
      caseId: 'CH035',
      reviewStatus: 'approved',
      intendedContext: 'Government tax refund bank details request',
      rationale: 'Authority + financial request. Clear social engineering.',
    ),
    ChallengeAnnotation(
      caseId: 'CH036',
      reviewStatus: 'approved',
      intendedContext: 'IT department password expiry reply request',
      rationale: 'Authority + credential request. Clear social engineering.',
    ),
    ChallengeAnnotation(
      caseId: 'CH037',
      reviewStatus: 'approved',
      intendedContext: 'Flagged account OTP phone request',
      rationale: 'Fear + credential request + urgency. Clear social engineering.',
    ),
    ChallengeAnnotation(
      caseId: 'CH038',
      reviewStatus: 'approved',
      intendedContext: 'Fraud department secrecy PIN request',
      rationale: 'Authority + secrecy + credential request. Clear social engineering.',
    ),

    // --- Category 6: Scam prize/refund/payment ---
    ChallengeAnnotation(
      caseId: 'CH039',
      reviewStatus: 'approved',
      intendedContext: 'Prize processing fee request',
      rationale: 'Prize + financial request. Clear scam.',
    ),
    ChallengeAnnotation(
      caseId: 'CH040',
      reviewStatus: 'approved',
      intendedContext: 'Cash reward card details request',
      rationale: 'Reward + financial request. Clear scam.',
    ),
    ChallengeAnnotation(
      caseId: 'CH041',
      reviewStatus: 'approved',
      intendedContext: 'Refund bank account request',
      rationale: 'Refund + financial request. Clear scam.',
    ),
    ChallengeAnnotation(
      caseId: 'CH042',
      reviewStatus: 'approved',
      intendedContext: 'Lottery unlock fee request',
      rationale: 'Lottery + financial request. Clear scam.',
    ),
    ChallengeAnnotation(
      caseId: 'CH043',
      reviewStatus: 'approved',
      intendedContext: 'Gift card shipping fee request',
      rationale: 'Gift card + financial request. Clear scam.',
    ),
    ChallengeAnnotation(
      caseId: 'CH044',
      reviewStatus: 'pendingReview',
      intendedContext: 'Payment declined card update request',
      rationale: 'Could be phishing (credential request) or scam (financial). Ambiguous classification.',
      reviewNote: 'Type ambiguity: phishing vs scam. Keep pending until reviewed.',
    ),
    ChallengeAnnotation(
      caseId: 'CH045',
      reviewStatus: 'approved',
      intendedContext: 'Unclaimed prize account number request',
      rationale: 'Prize + financial request. Clear scam.',
    ),
    ChallengeAnnotation(
      caseId: 'CH046',
      reviewStatus: 'approved',
      intendedContext: 'Pending refund bank details request',
      rationale: 'Refund + financial request. Clear scam.',
    ),

    // --- Category 7: Suspicious without URLs ---
    ChallengeAnnotation(
      caseId: 'CH047',
      reviewStatus: 'approved',
      intendedContext: 'Bare password reply request',
      rationale: 'Credential request without URL. Phishing/suspicious.',
    ),
    ChallengeAnnotation(
      caseId: 'CH048',
      reviewStatus: 'approved',
      intendedContext: 'Bare login details request',
      rationale: 'Credential request without URL. Phishing/suspicious.',
    ),
    ChallengeAnnotation(
      caseId: 'CH049',
      reviewStatus: 'approved',
      intendedContext: 'Bare security code request',
      rationale: 'Credential request without URL. Phishing/suspicious.',
    ),
    ChallengeAnnotation(
      caseId: 'CH050',
      reviewStatus: 'approved',
      intendedContext: 'Bare credentials submission request',
      rationale: 'Credential request without URL. Phishing/suspicious.',
    ),
    ChallengeAnnotation(
      caseId: 'CH051',
      reviewStatus: 'approved',
      intendedContext: 'Bare OTP entry request',
      rationale: 'Credential request without URL. Phishing/suspicious.',
    ),
    ChallengeAnnotation(
      caseId: 'CH052',
      reviewStatus: 'approved',
      intendedContext: 'Bare password confirmation request',
      rationale: 'Credential request without URL. Phishing/suspicious.',
    ),

    // --- Category 8: Benign with trigger words ---
    ChallengeAnnotation(
      caseId: 'CH053',
      reviewStatus: 'approved',
      intendedContext: 'Password reset feature announcement',
      rationale: 'Feature mention, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH054',
      reviewStatus: 'approved',
      intendedContext: 'Email verification prompt',
      rationale: 'Standard verification, no credential disclosure.',
    ),
    ChallengeAnnotation(
      caseId: 'CH055',
      reviewStatus: 'approved',
      intendedContext: 'Urgent maintenance notice',
      rationale: 'Urgency word but no threat. Legitimate.',
    ),
    ChallengeAnnotation(
      caseId: 'CH056',
      reviewStatus: 'approved',
      intendedContext: 'Account balance display',
      rationale: 'Informational, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH057',
      reviewStatus: 'approved',
      intendedContext: 'PIN protection feature notice',
      rationale: 'Feature mention, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH058',
      reviewStatus: 'approved',
      intendedContext: 'Verification code expiry info',
      rationale: 'Informational, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH059',
      reviewStatus: 'approved',
      intendedContext: 'Password policy requirement',
      rationale: 'Policy statement, no credential request.',
    ),
    ChallengeAnnotation(
      caseId: 'CH060',
      reviewStatus: 'approved',
      intendedContext: 'Security tips advisory',
      rationale: 'Advisory, no credential request.',
    ),

    // --- Category 9: Ambiguous/uncertain ---
    ChallengeAnnotation(
      caseId: 'CH061',
      reviewStatus: 'pendingReview',
      intendedContext: 'Account access review prompt',
      rationale: 'No credential request but security language. Ambiguous severity.',
      reviewNote: 'Could be legitimate/safe or legitimate/suspicious. Keep pending.',
    ),
    ChallengeAnnotation(
      caseId: 'CH062',
      reviewStatus: 'pendingReview',
      intendedContext: 'Login attempt with password reset suggestion',
      rationale: 'Mixed signals: security notice + credential-adjacent phrase.',
      reviewNote: 'Sender trust unverified. Keep pending.',
    ),
    ChallengeAnnotation(
      caseId: 'CH063',
      reviewStatus: 'pendingReview',
      intendedContext: 'Delivery delay support contact',
      rationale: 'Benign delivery message, but ambiguous if sender is unverified.',
      reviewNote: 'Insufficient context to confirm legitimacy. Keep pending.',
    ),
    ChallengeAnnotation(
      caseId: 'CH064',
      reviewStatus: 'pendingReview',
      intendedContext: 'Payment received confirmation',
      rationale: 'Benign payment notice, but could be a scam lure.',
      reviewNote: 'Ambiguous without sender verification. Keep pending.',
    ),
    ChallengeAnnotation(
      caseId: 'CH065',
      reviewStatus: 'pendingReview',
      intendedContext: 'Subscription renewal prompt',
      rationale: 'Could be legitimate spam or a scam lure. Ambiguous.',
      reviewNote: 'Type ambiguity: spam vs scam. Keep pending.',
    ),
  ];

  /// Returns annotations for approved cases only.
  static List<ChallengeAnnotation> get approved =>
      all.where((a) => a.reviewStatus == 'approved').toList();

  /// Returns annotations for pending-review cases.
  static List<ChallengeAnnotation> get pendingReview =>
      all.where((a) => a.reviewStatus == 'pendingReview').toList();

  /// Finds an annotation by case ID.
  static ChallengeAnnotation? byId(String id) {
    for (final a in all) {
      if (a.caseId == id) return a;
    }
    return null;
  }

  /// Validates that annotations cover all 65 case IDs exactly once.
  static bool validateCoverage(Set<String> caseIds) {
    if (all.length != caseIds.length) return false;
    final ids = all.map((a) => a.caseId).toSet();
    return ids.length == caseIds.length && ids.containsAll(caseIds);
  }
}
