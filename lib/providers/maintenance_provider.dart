import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/maintenance_data.dart';
import '../models/oil_change.dart';
import '../services/maintenance_api_service.dart';

const _storageKey = 'maintenance_data';

class MaintenanceProvider extends ChangeNotifier {
  MaintenanceData _data = MaintenanceData(
    currentMileage: 50000,
    oilChangeInterval: 5000,
    lastOilChange: OilChange(
      id: 'initial',
      date: '', // سيُملأ عند التحميل
      mileage: 46500,
    ),
    oilChangeHistory: [],
  );

  MaintenanceData get data => _data;
  String _baseUrl = '';
  String _deviceId = '';
  bool _lastRemoteSyncOk = true;
  bool get lastRemoteSyncOk => _lastRemoteSyncOk;

  MaintenanceProvider() {
    _load();
  }

  void configureServer(String baseUrl, {String deviceId = ''}) {
    final normalized = baseUrl.trim();
    final id = deviceId.trim();
    if (normalized == _baseUrl && id == _deviceId) return;
    _baseUrl = normalized;
    _deviceId = id;
    if (_baseUrl.isNotEmpty) {
      _loadFromServer();
    }
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        _data = MaintenanceData.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    } else {
      // قيم افتراضية مع تاريخ نسبي
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      final initial = OilChange(
        id: 'initial',
        date: thirtyDaysAgo.toIso8601String(),
        mileage: 46500,
      );
      _data = MaintenanceData(
        currentMileage: 50000,
        oilChangeInterval: 5000,
        lastOilChange: initial,
        oilChangeHistory: [initial],
      );
    }
    notifyListeners();
  }

  Future<void> _loadFromServer() async {
    final remote = await MaintenanceApiService.fetchData(
      _baseUrl,
      deviceId: _deviceId,
    );
    if (remote == null) return;
    _data = remote;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_data.toJson()));
    if (_baseUrl.isNotEmpty) {
      _lastRemoteSyncOk = await MaintenanceApiService.saveData(
        _baseUrl,
        _data,
        deviceId: _deviceId,
      );
    } else {
      _lastRemoteSyncOk = true;
    }
    notifyListeners();
  }

  void updateCurrentMileage(int mileage) {
    _data = _data.copyWith(currentMileage: mileage);
    _save();
    notifyListeners();
  }

  void updateOilChangeInterval(int interval) {
    if (interval < 1000 || interval > 50000) return;
    _data = _data.copyWith(oilChangeInterval: interval);
    _save();
    notifyListeners();
  }

  Future<void> restoreFromJson(Map<String, dynamic> json) async {
    _data = MaintenanceData.fromJson(json);
    await _save();
    notifyListeners();
  }

  void recordOilChange([String? notes]) {
    final now = DateTime.now();
    final record = OilChange(
      id: now.millisecondsSinceEpoch.toString(),
      date: now.toIso8601String(),
      mileage: _data.currentMileage,
      notes: notes?.trim().isEmpty == true ? null : notes,
    );
    final history = [record, ..._data.oilChangeHistory];
    _data = _data.copyWith(
      lastOilChange: record,
      oilChangeHistory: history,
    );
    _save();
    notifyListeners();
  }

  int getMileageSinceLastOilChange() {
    final last = _data.lastOilChange;
    if (last == null) return _data.currentMileage;
    return _data.currentMileage - last.mileage;
  }

  int getRemainingMileage() {
    final since = getMileageSinceLastOilChange();
    final remaining = _data.oilChangeInterval - since;
    return remaining > 0 ? remaining : 0;
  }

  int getOilLifePercentage() {
    final since = getMileageSinceLastOilChange();
    if (_data.oilChangeInterval <= 0) return 100;
    var pct = ((_data.oilChangeInterval - since) / _data.oilChangeInterval) * 100;
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    return pct.round();
  }

  OilStatus getOilStatus() {
    final pct = getOilLifePercentage();
    if (pct < 15) return OilStatus.critical;
    if (pct < 30) return OilStatus.warning;
    return OilStatus.normal;
  }
}
