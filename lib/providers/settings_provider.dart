import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_api_service.dart';

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
  String _deviceId = '';
  bool _lastRemoteSyncOk = true;

  String get temperatureUnit => _temperatureUnit;
  int get updateIntervalSeconds => _updateIntervalSeconds;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get criticalAlertsOnly => _criticalAlertsOnly;
  bool get autoReconnect => _autoReconnect;
  bool get darkMode => _darkMode;
  int get dataRetentionDays => _dataRetentionDays;
  String get sensorServerBaseUrl => _sensorServerBaseUrl;
  String get deviceId => _deviceId;
  bool get lastRemoteSyncOk => _lastRemoteSyncOk;

  /// إذا كان غير فارغ، لوحة التحكم تقرأ المستشعرات من السيرفر.
  bool get useLiveSensors => _sensorServerBaseUrl.trim().isNotEmpty;

  SettingsProvider() {
    _load();
  }

  Map<String, dynamic> _toMap() => {
        'temperatureUnit': _temperatureUnit,
        'updateInterval': _updateIntervalSeconds,
        'notificationsEnabled': _notificationsEnabled,
        'criticalAlertsOnly': _criticalAlertsOnly,
        'autoReconnect': _autoReconnect,
        'darkMode': _darkMode,
        'dataRetentionDays': _dataRetentionDays,
        'sensorServerBaseUrl': _sensorServerBaseUrl,
        'deviceId': _deviceId,
      };

  void _applyMap(Map<String, dynamic> map) {
    _temperatureUnit = map['temperatureUnit'] as String? ?? _temperatureUnit;
    _updateIntervalSeconds = map['updateInterval'] as int? ?? _updateIntervalSeconds;
    _notificationsEnabled = map['notificationsEnabled'] as bool? ?? _notificationsEnabled;
    _criticalAlertsOnly = map['criticalAlertsOnly'] as bool? ?? _criticalAlertsOnly;
    _autoReconnect = map['autoReconnect'] as bool? ?? _autoReconnect;
    _darkMode = map['darkMode'] as bool? ?? _darkMode;
    _dataRetentionDays = map['dataRetentionDays'] as int? ?? _dataRetentionDays;
    _sensorServerBaseUrl = map['sensorServerBaseUrl'] as String? ?? _sensorServerBaseUrl;
    _deviceId = map['deviceId'] as String? ?? _deviceId;
  }

  String _generateDeviceId() {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'device-$t';
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _applyMap(map);
      } catch (_) {}
    }
    if (_deviceId.trim().isEmpty) {
      _deviceId = _generateDeviceId();
      await prefs.setString(_storageKey, jsonEncode(_toMap()));
    }

    // Sync from Firestore when server is configured.
    if (_sensorServerBaseUrl.trim().isNotEmpty) {
      final remote = await SettingsApiService.fetchSettings(
        _sensorServerBaseUrl,
        deviceId: _deviceId,
      );
      if (remote != null) {
        _applyMap(remote);
        await prefs.setString(_storageKey, jsonEncode(_toMap()));
      }
    }
    notifyListeners();
  }

  Future<void> _save({bool syncRemote = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _toMap();
    await prefs.setString(_storageKey, jsonEncode(map));
    if (syncRemote && _sensorServerBaseUrl.trim().isNotEmpty) {
      _lastRemoteSyncOk = await SettingsApiService.saveSettings(
        _sensorServerBaseUrl,
        map,
        deviceId: _deviceId,
      );
    } else {
      _lastRemoteSyncOk = true;
    }
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
    _applyMap(settings);
    await _save();
  }
}
