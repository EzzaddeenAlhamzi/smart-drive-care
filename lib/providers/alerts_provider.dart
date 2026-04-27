import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/alert.dart';
import '../services/alerts_api_service.dart';

class AlertsProvider extends ChangeNotifier {
  List<Alert> _alerts = [];
  String _baseUrl = '';
  Timer? _pollTimer;
  bool _isLoading = false;

  List<Alert> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String get baseUrl => _baseUrl;

  List<Alert> get unacknowledgedAlerts =>
      _alerts.where((a) => !a.acknowledged).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<Alert> get acknowledgedAlerts =>
      _alerts.where((a) => a.acknowledged).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get unacknowledgedCount => _alerts.where((a) => !a.acknowledged).length;

  AlertsProvider();

  void configureServer(String baseUrl) {
    final normalized = baseUrl.trim();
    if (normalized == _baseUrl) return;
    _baseUrl = normalized;
    _pollTimer?.cancel();
    if (_baseUrl.isNotEmpty) {
      fetchNow();
      _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchNow());
    } else {
      _alerts = [];
      notifyListeners();
    }
  }

  Future<void> fetchNow() async {
    if (_baseUrl.isEmpty) {
      _alerts = [];
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    try {
      _alerts = await AlertsApiService.fetchAlerts(_baseUrl);
    } catch (_) {
      // Keep previous list on transient failures
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// توافق مع الاستدعاءات القديمة من صفحة الإعدادات.
  Future<void> reload() async {
    await fetchNow();
  }

  Future<void> acknowledge(String alertId) async {
    if (_baseUrl.isEmpty) return;
    final ok = await AlertsApiService.acknowledge(_baseUrl, alertId);
    if (ok) {
      final idx = _alerts.indexWhere((a) => a.id == alertId);
      if (idx >= 0) {
        _alerts[idx] = _alerts[idx].copyWith(acknowledged: true);
      }
      notifyListeners();
      await fetchNow();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
