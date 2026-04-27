import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/historical_data.dart';

class HistoryApiService {
  HistoryApiService._();

  static String _sanitizeBaseUrl(String baseUrl) {
    var b = baseUrl.trim();
    if (b.isEmpty) return '';
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }
    if (b.endsWith('/')) b = b.substring(0, b.length - 1);
    return b;
  }

  static Future<List<HistoricalData>> fetchHistory({
    required String baseUrl,
    required String period,
    required String deviceId,
  }) async {
    final b = _sanitizeBaseUrl(baseUrl);
    if (b.isEmpty) return [];

    final uri = Uri.parse(
      '$b/api/history?period=$period&deviceId=${Uri.encodeQueryComponent(deviceId)}',
    );
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];

    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (map['rows'] as List?) ?? [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(HistoricalData.fromServer)
        .toList();
  }
}
