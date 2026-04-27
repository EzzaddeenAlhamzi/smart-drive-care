import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/alert.dart';

class AlertsApiService {
  AlertsApiService._();

  static String _sanitizeBaseUrl(String baseUrl) {
    var b = baseUrl.trim();
    if (b.isEmpty) return '';
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  static Future<List<Alert>> fetchAlerts(
    String baseUrl, {
    bool criticalOnly = false,
    String? deviceId,
  }) async {
    final b = _sanitizeBaseUrl(baseUrl);
    if (b.isEmpty) return [];
    final qs = StringBuffer('criticalOnly=$criticalOnly');
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      qs.write('&deviceId=${Uri.encodeQueryComponent(deviceId.trim())}');
    }
    final uri = Uri.parse('$b/api/alerts?$qs');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return [];
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final list = (map['alerts'] as List?) ?? [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(Alert.fromServer)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<bool> acknowledge(
    String baseUrl,
    String alertId, {
    String? deviceId,
  }) async {
    final b = _sanitizeBaseUrl(baseUrl);
    if (b.isEmpty || alertId.isEmpty) return false;
    final id = Uri.encodeQueryComponent(alertId);
    final qs = StringBuffer('id=$id');
    if (deviceId != null && deviceId.trim().isNotEmpty) {
      qs.write('&deviceId=${Uri.encodeQueryComponent(deviceId.trim())}');
    }
    final uri = Uri.parse('$b/api/alerts/ack?$qs');
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return false;
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return map['ok'] == true;
  }
}
