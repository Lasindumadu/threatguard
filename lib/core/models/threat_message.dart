import 'message_source.dart';

class ThreatMessage {
  final String id;
  final String body;
  final String? sender;
  final DateTime? receivedAt;
  final MessageSource source;

  const ThreatMessage({
    required this.id,
    required this.body,
    required this.source,
    this.sender,
    this.receivedAt,
  });
}
