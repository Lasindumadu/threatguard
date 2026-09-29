import '../models/url_analysis.dart';
import '../models/url_evaluation_case.dart';

class UrlEvaluationDataset {
  static const cases = <UrlEvaluationCase>[
    UrlEvaluationCase(
      id: 'url_001_ordinary',
      message: 'Please visit https://example.com/account.',
      expectedSignal: UrlSignalType.ipAddressHost,
      shouldDetectSignal: false,
    ),

    UrlEvaluationCase(
      id: 'url_002_ip_host',
      message: 'Please visit http://192.168.1.10/login.',
      expectedSignal: UrlSignalType.ipAddressHost,
      shouldDetectSignal: true,
    ),

    UrlEvaluationCase(
      id: 'url_003_punycode',
      message: 'Please visit https://xn--pple-43d.com/login.',
      expectedSignal: UrlSignalType.punycodeHost,
      shouldDetectSignal: true,
    ),

    UrlEvaluationCase(
      id: 'url_004_embedded_credentials',
      message: 'Open https://user:password@example.com/login.',
      expectedSignal: UrlSignalType.embeddedCredentials,
      shouldDetectSignal: true,
    ),

    UrlEvaluationCase(
      id: 'url_005_non_standard_port',
      message: 'Open https://example.com:8443/login.',
      expectedSignal: UrlSignalType.nonStandardPort,
      shouldDetectSignal: true,
    ),

    UrlEvaluationCase(
      id: 'url_006_deep_subdomain',
      message: 'Open https://login.security.account.example.com/verify.',
      expectedSignal: UrlSignalType.excessiveSubdomains,
      shouldDetectSignal: true,
    ),

    UrlEvaluationCase(
      id: 'url_007_shortener',
      message: 'Please open https://bit.ly/abc123.',
      expectedSignal: UrlSignalType.urlShortener,
      shouldDetectSignal: true,
    ),

    UrlEvaluationCase(
      id: 'url_008_normal_https',
      message: 'Visit https://www.example.com/help.',
      expectedSignal: UrlSignalType.punycodeHost,
      shouldDetectSignal: false,
    ),

    UrlEvaluationCase(
      id: 'url_009_standard_https_port',
      message: 'Visit https://example.com:443/account.',
      expectedSignal: UrlSignalType.nonStandardPort,
      shouldDetectSignal: false,
    ),

    UrlEvaluationCase(
      id: 'url_010_standard_http_port',
      message: 'Visit http://example.com:80/account.',
      expectedSignal: UrlSignalType.nonStandardPort,
      shouldDetectSignal: false,
    ),
  ];
}
