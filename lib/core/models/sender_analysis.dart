enum SenderType { alphanumeric, phoneNumber, shortCode, unknown }

enum SenderVerificationStatus { unknown, recognized, verified, suspicious }

class SenderAnalysis {
  final String rawSender;
  final String normalizedSender;
  final SenderType senderType;
  final String? organization;
  final SenderVerificationStatus verificationStatus;
  final double confidence;

  const SenderAnalysis({
    required this.rawSender,
    required this.normalizedSender,
    required this.senderType,
    required this.organization,
    required this.verificationStatus,
    required this.confidence,
  });

  /// Used when no sender analysis was performed because the message was not
  /// analysed. Confidence is 0, not 1: nothing was established.
  static const SenderAnalysis unavailable = SenderAnalysis(
    rawSender: '',
    normalizedSender: '',
    senderType: SenderType.unknown,
    organization: null,
    verificationStatus: SenderVerificationStatus.unknown,
    confidence: 0.0,
  );
}
