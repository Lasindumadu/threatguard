enum GoogleWebRiskClientErrorType {
  unauthorized,
  forbidden,
  rateLimited,
  serverError,
  network,
  invalidResponse,
  unknown,
}

class GoogleWebRiskClientException implements Exception {
  final GoogleWebRiskClientErrorType type;
  final String message;

  const GoogleWebRiskClientException({
    required this.type,
    required this.message,
  });

  @override
  String toString() {
    return 'GoogleWebRiskClientException('
        'type: $type, '
        'message: $message'
        ')';
  }
}
