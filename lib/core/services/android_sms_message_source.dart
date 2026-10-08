import 'package:flutter/services.dart';

import '../models/message_source.dart';
import '../models/threat_message.dart';
import 'sms_message_source.dart';

class AndroidSmsMessageSource implements SmsMessageSource {
  static const MethodChannel _channel = MethodChannel('threatguard/sms');

  const AndroidSmsMessageSource();

  @override
  Future<List<ThreatMessage>> readMessages() async {
    final messages = await _channel.invokeMethod<List<dynamic>>(
      'readSmsMessages',
    );

    if (messages == null) {
      return const [];
    }

    return messages.map((message) {
      final data = Map<String, dynamic>.from(message as Map);

      return ThreatMessage(
        id: data['id'] as String,
        body: data['body'] as String,
        sender: data['sender'] as String?,
        receivedAt: data['date'] != null
            ? DateTime.fromMillisecondsSinceEpoch(data['date'] as int)
            : null,
        source: MessageSource.sms,
      );
    }).toList();
  }
}
