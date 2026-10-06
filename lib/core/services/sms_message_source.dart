import '../models/threat_message.dart';

abstract class SmsMessageSource {
  Future<List<ThreatMessage>> readMessages();
}
