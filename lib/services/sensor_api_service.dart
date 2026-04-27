import 'dart:convert';
import 'package:http/http.dart' as http;

/// آخر قراءة من السيرفر الوسيط (متوافق مع Wokwi / ESP32).
class SensorBridgePayload {
  final double temp;
  final double battery;
  final int engineOil;
  final int gearOil;
  final int engineOilLimit;
  final int gearOilLimit;
  final String? updatedAt;

  SensorBridgePayload({
    required this.temp,
    required this.battery,
    required this.engineOil,
    required this.gearOil,
    required this.engineOilLimit,
    required this.gearOilLimit,
    this.updatedAt,
  });

  factory SensorBridgePayload.fromJson(Map<String, dynamic> j) {
    double d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;
    return SensorBridgePayload(
      temp: d(j['temp']),
      battery: d(j['battery']),
      engineOil: i(j['engineOil']),
      gearOil: i(j['gearOil']),
      engineOilLimit: i(j['engineOilLimit']) == 0 ? 5000 : i(j['engineOilLimit']),
      gearOilLimit: i(j['gearOilLimit']) == 0 ? 20000 : i(j['gearOilLimit']),
      updatedAt: j['updatedAt'] as String?,
    );
  }
}

class SensorApiService {
  SensorApiService._();

  static Uri _latestUri(String baseUrl) {
    var b = baseUrl.trim();
    if (b.isEmpty) throw ArgumentError('baseUrl فارغ');
    if (!b.startsWith('http://') && !b.startsWith('https://')) {
      b = 'http://$b';
    }
    if (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return Uri.parse('$b/api/latest');
  }

  static Future<SensorBridgePayload?> fetchLatest(String baseUrl) async {
    try {
      final uri = _latestUri(baseUrl);
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return SensorBridgePayload.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> checkHealth(String baseUrl) async {
    try {
      var b = baseUrl.trim();
      if (b.isEmpty) return false;
      if (!b.startsWith('http://') && !b.startsWith('https://')) {
        b = 'http://$b';
      }
      if (b.endsWith('/')) {
        b = b.substring(0, b.length - 1);
      }
      final uri = Uri.parse('$b/api/health');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return false;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return map['ok'] == true;
    } catch (_) {
      return false;
    }
  }
}
