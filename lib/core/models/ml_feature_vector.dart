enum MlThreatType { legitimate, spam, phishing, scam, socialEngineering }

class MlFeatureVector {
  final String caseId;

  // Message-level features.
  final int messageLength;
  final int wordCount;
  final int urlCount;

  // Basic threat-language features.
  final bool hasUrgency;
  final bool hasAccountSecurity;
  final bool hasCredential;
  final bool hasFinancial;
  final bool hasPrizeReward;
  final bool hasSecrecy;
  final bool hasAuthority;
  final bool hasPromotion;
  final bool hasDeliveryContext;

  // URL features.
  final bool hasUrl;
  final bool hasSuspiciousUrl;
  final bool hasIpUrl;
  final bool hasPunycodeUrl;
  final bool hasEmbeddedCredentialsUrl;
  final bool hasNonStandardPortUrl;
  final bool hasExcessiveSubdomainsUrl;
  final bool hasShortenerUrl;

  // Linguistic/context features.
  final bool hasAccountVerification;
  final bool hasIdentityVerification;
  final bool hasCredentialRequest;
  final bool hasStrongCredentialRequest;

  // Derived interaction features.
  final bool hasPrizeFinancialCombination;
  final bool hasAccountCredentialCombination;
  final bool hasAuthorityCredentialCombination;
  final bool hasUrgencyCredentialCombination;

  const MlFeatureVector({
    required this.caseId,
    required this.messageLength,
    required this.wordCount,
    required this.urlCount,
    required this.hasUrgency,
    required this.hasAccountSecurity,
    required this.hasCredential,
    required this.hasFinancial,
    required this.hasPrizeReward,
    required this.hasSecrecy,
    required this.hasAuthority,
    required this.hasPromotion,
    required this.hasDeliveryContext,
    required this.hasUrl,
    required this.hasSuspiciousUrl,
    required this.hasIpUrl,
    required this.hasPunycodeUrl,
    required this.hasEmbeddedCredentialsUrl,
    required this.hasNonStandardPortUrl,
    required this.hasExcessiveSubdomainsUrl,
    required this.hasShortenerUrl,
    required this.hasAccountVerification,
    required this.hasIdentityVerification,
    required this.hasCredentialRequest,
    required this.hasStrongCredentialRequest,
    required this.hasPrizeFinancialCombination,
    required this.hasAccountCredentialCombination,
    required this.hasAuthorityCredentialCombination,
    required this.hasUrgencyCredentialCombination,
  });
}
