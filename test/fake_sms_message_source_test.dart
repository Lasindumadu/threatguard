import 'package:flutter_test/flutter_test.dart';

import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/services/fake_sms_message_source.dart';

void main() {
  test('returns the expected demo SMS messages', () async {
    const source = FakeSmsMessageSource();

    final messages = await source.readMessages();

    expect(messages.length, 3);

    expect(messages[0].id, 'demo_sms_001');
    expect(messages[0].sender, 'ExampleBank');
    expect(messages[0].source, MessageSource.sms);
    expect(
      messages[0].body,
      'Your account is suspended. Verify your password immediately.',
    );

    expect(messages[1].id, 'demo_sms_002');
    expect(messages[1].sender, 'PrizeCenter');
    expect(messages[1].source, MessageSource.sms);
    expect(
      messages[1].body,
      'Congratulations! You have won a cash prize. Claim now.',
    );

    expect(messages[2].id, 'demo_sms_003');
    expect(messages[2].sender, 'John');
    expect(messages[2].source, MessageSource.sms);
    expect(messages[2].body, 'Hi, are we still meeting tomorrow at 10 AM?');
  });
}
