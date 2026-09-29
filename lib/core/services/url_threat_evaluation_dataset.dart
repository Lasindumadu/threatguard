import '../models/threat_analysis.dart';
import '../models/url_analysis.dart';
import '../models/url_threat_evaluation_case.dart';

class UrlThreatEvaluationDataset {
  static const cases = <UrlThreatEvaluationCase>[
    UrlThreatEvaluationCase(
      id: 'combo_001_phishing_ip',
      message:
          'Your account has been suspended. '
          'Enter your password at http://192.168.1.10/login.',
      expectedUrlSignal: UrlSignalType.ipAddressHost,
      expectedThreatType: ThreatType.phishing,
      expectedThreatLevel: ThreatLevel.highRisk,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_002_phishing_shortener',
      message:
          'Verify your account immediately at '
          'https://bit.ly/verify123.',
      expectedUrlSignal: UrlSignalType.urlShortener,
      expectedThreatType: ThreatType.phishing,
      expectedThreatLevel: ThreatLevel.highRisk,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_003_phishing_punycode',
      message:
          'Your account has unusual activity. '
          'Verify your account at https://xn--pple-43d.com/login.',
      expectedUrlSignal: UrlSignalType.punycodeHost,
      expectedThreatType: ThreatType.phishing,
      expectedThreatLevel: ThreatLevel.highRisk,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_004_scam_ip',
      message:
          'Congratulations! You won a cash prize. '
          'Pay the required fee at http://192.168.1.20/claim.',
      expectedUrlSignal: UrlSignalType.ipAddressHost,
      expectedThreatType: ThreatType.scam,
      expectedThreatLevel: ThreatLevel.suspicious,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_005_scam_shortener',
      message:
          'You have won a reward. '
          'Pay the processing fee here: https://bit.ly/reward123.',
      expectedUrlSignal: UrlSignalType.urlShortener,
      expectedThreatType: ThreatType.scam,
      expectedThreatLevel: ThreatLevel.suspicious,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_006_social_ip',
      message:
          'This is the bank security team. '
          'Send your verification code immediately at '
          'http://192.168.1.30/verify.',
      expectedUrlSignal: UrlSignalType.ipAddressHost,
      expectedThreatType: ThreatType.socialEngineering,
      expectedThreatLevel: ThreatLevel.highRisk,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_007_social_shortener',
      message:
          'Customer support requires your security code right now. '
          'Open https://bit.ly/support123.',
      expectedUrlSignal: UrlSignalType.urlShortener,
      expectedThreatType: ThreatType.socialEngineering,
      expectedThreatLevel: ThreatLevel.highRisk,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_008_legitimate_ip',
      message:
          'The office network server is available at '
          'http://192.168.1.50/status.',
      expectedUrlSignal: UrlSignalType.ipAddressHost,
      expectedThreatType: ThreatType.legitimate,
      expectedThreatLevel: ThreatLevel.safe,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_009_legitimate_deep_subdomain',
      message:
          'Please open '
          'https://portal.department.company.example.com/help.',
      expectedUrlSignal: UrlSignalType.excessiveSubdomains,
      expectedThreatType: ThreatType.legitimate,
      expectedThreatLevel: ThreatLevel.safe,
    ),

    UrlThreatEvaluationCase(
      id: 'combo_010_legitimate_nonstandard_port',
      message:
          'The development server is available at '
          'https://dev.example.com:8443/dashboard.',
      expectedUrlSignal: UrlSignalType.nonStandardPort,
      expectedThreatType: ThreatType.legitimate,
      expectedThreatLevel: ThreatLevel.safe,
    ),
  ];
}
