import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';

const _storageKey = 'alerts_data';

class AlertsProvider extends ChangeNotifier {
  List<Alert> _alerts = [];

  List<Alert> get alerts => _alerts;

  List<Alert> get unacknowledgedAlerts =>
      _alerts.where((a) => !a.acknowledged).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<Alert> get acknowledgedAlerts =>
      _alerts.where((a) => a.acknowledged).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get unacknowledgedCount => _alerts.where((a) => !a.acknowledged).length;

  AlertsProvider() {
    _load();
    if (_alerts.isEmpty) {
      _alerts = _generateSampleAlerts();
      _save();
    }
  }

  List<Alert> _generateSampleAlerts() {
    final now = DateTime.now();
    return [
      Alert(
        id: '1',
        alertType: 'HIGH_TEMP',
        riskLevel: 'CRITICAL',
        message: 'ارتفاع درجة حرارة المحرك بشكل خطير',
        suggestedAction:
            'أوقف المحرك فوراً وانتظر حتى يبرد. تحقق من مستوى سائل التبريد ومروحة التبريد.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        sensorType: 'TEMP',
      ),
      Alert(
        id: '2',
        alertType: 'LOW_OIL',
        riskLevel: 'HIGH',
        message: 'انخفاض مستوى زيت المحرك',
        suggestedAction:
            'تحقق من مستوى الزيت وأضف الزيت إذا لزم الأمر. قد تحتاج لتغيير الزيت قريباً.',
        timestamp: now.subtract(const Duration(minutes: 30)),
        sensorType: 'OIL',
      ),
      Alert(
        id: '3',
        alertType: 'BATTERY_LOW',
        riskLevel: 'MEDIUM',
        message: 'انخفاض جهد البطارية',
        suggestedAction: 'تحقق من البطارية والمولد. قد تحتاج لشحن أو استبدال البطارية.',
        timestamp: now.subtract(const Duration(hours: 2)),
        sensorType: 'BATTERY',
      ),
      Alert(
        id: '4',
        alertType: 'TRANS_OIL',
        riskLevel: 'LOW',
        message: 'انتباه: زيت ناقل الحركة',
        suggestedAction: 'راجع سجل الصيانة. قد تحتاج لتغيير زيت القير في المستقبل.',
        timestamp: now.subtract(const Duration(days: 1)),
        sensorType: 'TRANS',
      ),
      Alert(
        id: '5',
        alertType: 'HIGH_TEMP',
        riskLevel: 'MEDIUM',
        message: 'ارتفاع طفيف في حرارة المحرك',
        suggestedAction: 'راقب القراءات. إذا استمر الارتفاع، أوقف المحرك.',
        timestamp: now.subtract(const Duration(days: 2)),
        acknowledged: true,
        sensorType: 'TEMP',
      ),
    ];
  }

  Future<void> reload() async {
    _alerts = [];
    await _load();
    if (_alerts.isEmpty) {
      _alerts = _generateSampleAlerts();
      _save();
    }
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _alerts = list
            .map((e) => Alert.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_alerts.map((e) => e.toJson()).toList()),
    );
    notifyListeners();
  }

  void acknowledge(String alertId) {
    final idx = _alerts.indexWhere((a) => a.id == alertId);
    if (idx >= 0) {
      _alerts[idx] = _alerts[idx].copyWith(acknowledged: true);
      _save();
    }
  }
}
