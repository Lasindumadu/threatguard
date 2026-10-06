import '../models/message_source.dart';
import '../models/threat_message.dart';
import 'sms_message_source.dart';

class FakeSmsMessageSource implements SmsMessageSource {
  const FakeSmsMessageSource();

  @override
  Future<List<ThreatMessage>> readMessages() async {
    return const [
      ThreatMessage(
        id: 'demo_sms_001',
        body: 'Your account is suspended. Verify your password immediately.',
        sender: 'ExampleBank',
        source: MessageSource.sms,
      ),
      ThreatMessage(
        id: 'demo_sms_002',
        body: 'Congratulations! You have won a cash prize. Claim now.',
        sender: 'PrizeCenter',
        source: MessageSource.sms,
      ),
      ThreatMessage(
        id: 'demo_sms_003',
        body: 'Hi, are we still meeting tomorrow at 10 AM?',
        sender: 'John',
        source: MessageSource.sms,
      ),
    ];
  }
}
