import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:threatguard/core/models/message_source.dart';
import 'package:threatguard/core/services/android_sms_message_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('threatguard/sms');

  test('reads SMS messages from the Android method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'readSmsMessages') {
            return [
              {
                'id': 'sms_001',
                'sender': 'ExampleBank',
                'body': 'Your account is suspended. Verify your password immediately.',
                'date': 1700000000000,
              },
              {
                'id': 'sms_002',
                'sender': 'John',
                'body': 'Hi, are we still meeting tomorrow?',
                'date': 1700000001000,
              },
            ];
          }

          return null;
        });

    const source = AndroidSmsMessageSource();

    final messages = await source.readMessages();

    expect(messages.length, 2);

    expect(messages[0].id, 'sms_001');
    expect(messages[0].sender, 'ExampleBank');
    expect(
      messages[0].body,
      'Your account is suspended. Verify your password immediately.',
    );
    expect(messages[0].source, MessageSource.sms);

    expect(messages[1].id, 'sms_002');
    expect(messages[1].sender, 'John');
    expect(messages[1].source, MessageSource.sms);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
