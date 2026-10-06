import '../models/organization_profile.dart';
import '../models/sender_analysis.dart';
import 'organization_registry.dart';

class SenderAnalyzer {
  final OrganizationRegistry registry;

  const SenderAnalyzer({this.registry = const OrganizationRegistry()});

  SenderAnalysis analyze(String? sender) {
    final rawSender = sender?.trim() ?? '';

    if (rawSender.isEmpty) {
      return const SenderAnalysis(
        rawSender: '',
        normalizedSender: '',
        senderType: SenderType.unknown,
        organization: null,
        verificationStatus: SenderVerificationStatus.unknown,
        confidence: 0.0,
      );
    }

    final normalizedSender = _normalizeSender(rawSender);
    final senderType = _detectSenderType(normalizedSender);

    final organization = _findOrganization(normalizedSender);

    if (organization == null) {
      return SenderAnalysis(
        rawSender: rawSender,
        normalizedSender: normalizedSender,
        senderType: senderType,
        organization: null,
        verificationStatus: SenderVerificationStatus.unknown,
        confidence: 0.0,
      );
    }

    return SenderAnalysis(
      rawSender: rawSender,
      normalizedSender: normalizedSender,
      senderType: senderType,
      organization: organization.name,
      verificationStatus: SenderVerificationStatus.recognized,
      confidence: 0.85,
    );
  }

  String _normalizeSender(String sender) {
    return sender.trim().toLowerCase();
  }

  SenderType _detectSenderType(String sender) {
    if (RegExp(r'^\+?[0-9][0-9\s-]{5,}$').hasMatch(sender)) {
      return SenderType.phoneNumber;
    }

    if (RegExp(r'^[0-9]{3,8}$').hasMatch(sender)) {
      return SenderType.shortCode;
    }

    if (RegExp(r'^[a-z0-9._-]+$').hasMatch(sender)) {
      return SenderType.alphanumeric;
    }

    return SenderType.unknown;
  }

  OrganizationProfile? _findOrganization(String sender) {
    for (final profile in registry.profiles) {
      if (profile.senderPatterns.contains(sender)) {
        return profile;
      }
    }

    return null;
  }
}
