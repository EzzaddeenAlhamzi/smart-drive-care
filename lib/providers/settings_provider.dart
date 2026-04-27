import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storageKey = 'app_settings';

class SettingsProvider extends ChangeNotifier {
  String _temperatureUnit = 'celsius';
  int _updateIntervalSeconds = 3;
  bool _notificationsEnabled = true;
  bool _criticalAlertsOnly = false;
  bool _autoReconnect = true;
  bool _darkMode = false;
  int _dataRetentionDays = 30;
  /// عنوان السيرفر الوسيط (بدون /update). مثال: http://10.0.2.2:3000
  String _sensorServerBaseUrl = '';

  String get temperatureUnit => _temperatureUnit;
  int get updateIntervalSeconds => _updateIntervalSeconds;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get criticalAlertsOnly => _criticalAlertsOnly;
  bool get autoReconnect => _autoReconnect;
  bool get darkMode => _darkMode;
  int get dataRetentionDays => _dataRetentionDays;
  String get sensorServerBaseUrl => _sensorServerBaseUrl;

  /// إذا كان غير فارغ، لوحة التحكم تقرأ المستشعرات من السيرفر.
  bool get useLiveSensors => _sensorServerBaseUrl.trim().isNotEmpty;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _temperatureUnit = map['temperatureUnit'] as String? ?? 'celsius';
        _updateIntervalSeconds = map['updateInterval'] as int? ?? 3;
        _notificationsEnabled = map['notificationsEnabled'] as bool? ?? true;
        _criticalAlertsOnly = map['criticalAlertsOnly'] as bool? ?? false;
        _autoReconnect = map['autoReconnect'] as bool? ?? true;
        _darkMode = map['darkMode'] as bool? ?? false;
        _dataRetentionDays = map['dataRetentionDays'] as int? ?? 30;
        _sensorServerBaseUrl = map['sensorServerBaseUrl'] as String? ?? '';
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode({
      'temperatureUnit': _temperatureUnit,
      'updateInterval': _updateIntervalSeconds,
      'notificationsEnabled': _notificationsEnabled,
      'criticalAlertsOnly': _criticalAlertsOnly,
      'autoReconnect': _autoReconnect,
      'darkMode': _darkMode,
      'dataRetentionDays': _dataRetentionDays,
      'sensorServerBaseUrl': _sensorServerBaseUrl,
    }));
    notifyListeners();
  }

  void setTemperatureUnit(String value) {
    _temperatureUnit = value;
    _save();
  }

  void setUpdateInterval(int seconds) {
    _updateIntervalSeconds = seconds;
    _save();
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    _save();
  }

  void setCriticalAlertsOnly(bool value) {
    _criticalAlertsOnly = value;
    _save();
  }

  void setAutoReconnect(bool value) {
    _autoReconnect = value;
    _save();
  }

  void setDarkMode(bool value) {
    _darkMode = value;
    _save();
  }

  void setDataRetentionDays(int days) {
    _dataRetentionDays = days;
    _save();
  }

  void setSensorServerBaseUrl(String value) {
    _sensorServerBaseUrl = value.trim();
    _save();
  }

  Future<void> saveAll(Map<String, dynamic> settings) async {
    _temperatureUnit = settings['temperatureUnit'] as String? ?? _temperatureUnit;
    _updateIntervalSeconds = settings['updateInterval'] as int? ?? _updateIntervalSeconds;
    _notificationsEnabled = settings['notificationsEnabled'] as bool? ?? _notificationsEnabled;
    _criticalAlertsOnly = settings['criticalAlertsOnly'] as bool? ?? _criticalAlertsOnly;
    _autoReconnect = settings['autoReconnect'] as bool? ?? _autoReconnect;
    _darkMode = settings['darkMode'] as bool? ?? _darkMode;
    _dataRetentionDays = settings['dataRetentionDays'] as int? ?? _dataRetentionDays;
    _sensorServerBaseUrl = settings['sensorServerBaseUrl'] as String? ?? _sensorServerBaseUrl;
    await _save();
  }
}
