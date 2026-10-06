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
}
