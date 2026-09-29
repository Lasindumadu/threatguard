import '../models/ml_feature_vector.dart';

class MlFeatureEncoder {
  const MlFeatureEncoder();

  List<double> encode(MlFeatureVector features) {
    return [
      features.messageLength.toDouble(),
      features.wordCount.toDouble(),
      features.urlCount.toDouble(),

      _bool(features.hasUrgency),
      _bool(features.hasAccountSecurity),
      _bool(features.hasCredential),
      _bool(features.hasFinancial),
      _bool(features.hasPrizeReward),
      _bool(features.hasSecrecy),
      _bool(features.hasAuthority),
      _bool(features.hasPromotion),

      _bool(features.hasUrl),
      _bool(features.hasSuspiciousUrl),
      _bool(features.hasIpUrl),
      _bool(features.hasPunycodeUrl),
      _bool(features.hasEmbeddedCredentialsUrl),
      _bool(features.hasNonStandardPortUrl),
      _bool(features.hasExcessiveSubdomainsUrl),
      _bool(features.hasShortenerUrl),

      _bool(features.hasAccountVerification),
      _bool(features.hasIdentityVerification),
      _bool(features.hasCredentialRequest),
      _bool(features.hasStrongCredentialRequest),
      _bool(features.hasPrizeFinancialCombination),
      _bool(features.hasAccountCredentialCombination),
      _bool(features.hasAuthorityCredentialCombination),
      _bool(features.hasUrgencyCredentialCombination),
    ];
  }

  double _bool(bool value) {
    return value ? 1.0 : 0.0;
  }
}
