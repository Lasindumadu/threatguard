class GoogleWebRiskResponse {
  final List<String> threatTypes;
  final DateTime? expireTime;

  const GoogleWebRiskResponse({required this.threatTypes, this.expireTime});
}

abstract class GoogleWebRiskClient {
  const GoogleWebRiskClient();

  Future<GoogleWebRiskResponse> searchUri(String url);
}

class GoogleWebRiskHttpResponse {
  final int statusCode;
  final String body;

  const GoogleWebRiskHttpResponse({
    required this.statusCode,
    required this.body,
  });
}

abstract class GoogleWebRiskHttpClient {
  const GoogleWebRiskHttpClient();

  Future<GoogleWebRiskHttpResponse> get({required Uri uri});
}
