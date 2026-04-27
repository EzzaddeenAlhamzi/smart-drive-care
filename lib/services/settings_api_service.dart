import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsApiService {
  SettingsApiService._();

  static String _sanitizeBaseUrl(String baseUrl) {
    var b = baseUrl.trim();
    if (b.isEmpty) return '';
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  static Future<Map<String, dynamic>?> fetchSettings(
    String baseUrl, {
    required String deviceId,
  }) async {
    final b = _sanitizeBaseUrl(baseUrl);
    if (b.isEmpty) return null;
    try {
      final uri = Uri.parse('$b/api/settings?deviceId=$deviceId');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return (map['settings'] as Map?)?.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> saveSettings(
    String baseUrl,
    Map<String, dynamic> settings,
    {required String deviceId}
  ) async {
    final b = _sanitizeBaseUrl(baseUrl);
    if (b.isEmpty) return false;
    try {
      final uri = Uri.parse('$b/api/settings?deviceId=$deviceId');
      final res = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'deviceId': deviceId, 'settings': settings}),
          )
          .timeout(const Duration(seconds: 12));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
