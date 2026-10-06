import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/url_reputation.dart';
import 'package:threatguard/core/services/unavailable_online_url_reputation_provider.dart';

void main() {
  const provider = UnavailableOnlineUrlReputationProvider();

  test(
    'returns unknown when online reputation service is unavailable',
    () async {
      final result = await provider.checkUrl('https://example.com');

      expect(result.url, 'https://example.com');
      expect(result.status, UrlReputationStatus.unknown);
      expect(
        result.reason,
        contains('Online URL reputation service is currently unavailable'),
      );
      expect(result.source, UrlReputationSource.online);
      expect(result.confidence, isNull);
      expect(result.checkedAt, isNotNull);
    },
  );
}
