import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/settings_provider.dart';
import '../models/sensor_reading.dart';
import '../services/sensor_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sensor_card.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<SensorReading> _readings = const [];
  SensorBridgePayload? _payload;
  Timer? _timer;
  int _currentInterval = 0;
  bool _wasLive = false;
  String _lastSensorUrl = '';
  String _lastDeviceId = '';
  bool _liveFetchFailed = false;
  bool _isConnecting = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _overallStatus {
    if (_readings.isEmpty) return 'غير متاح';
    if (_readings.any((r) => r.status == 'CRITICAL')) return 'حرجة';
    if (_readings.any((r) => r.status == 'WARNING')) return 'تحذير';
    return 'طبيعي';
  }

  Color get _overallColor {
    switch (_overallStatus) {
      case 'حرجة':
        return AppColors.critical;
      case 'تحذير':
        return AppColors.warning;
      case 'غير متاح':
        return Colors.blueGrey;
      default:
        return AppColors.success;
    }
  }

  String get _overallMessage {
    switch (_overallStatus) {
      case 'حرجة':
        return 'حالة حرجة - يتطلب تدخل فوري';
      case 'تحذير':
        return 'تحذير - يتطلب مراقبة';
      case 'غير متاح':
        return 'بانتظار وصول قراءة من الحساسات';
      default:
        return 'جميع الأنظمة تعمل بشكل طبيعي';
    }
  }

  IconData _sensorIcon(String type) {
    switch (type) {
      case 'OIL':
        return Icons.water_drop;
      case 'TEMP':
        return Icons.thermostat;
      case 'BATTERY':
        return Icons.battery_charging_full;
      case 'TRANS':
        return Icons.settings;
      default:
        return Icons.sensors;
    }
  }

  void _updateTimerIfNeeded(SettingsProvider settings) {
    final interval = settings.updateIntervalSeconds;
    final live = settings.useLiveSensors;
    final url = settings.sensorServerBaseUrl;
    final deviceId = settings.deviceId;

    if (interval == _currentInterval &&
        live == _wasLive &&
        url == _lastSensorUrl &&
        deviceId == _lastDeviceId) {
      return;
    }

    _currentInterval = interval;
    _wasLive = live;
    _lastSensorUrl = url;
    _lastDeviceId = deviceId;
    _timer?.cancel();

    if (live && url.isNotEmpty) {
      setState(() {
        _isConnecting = true;
        _liveFetchFailed = false;
      });
      _fetchLive(url, settings.deviceId);
      _timer = Timer.periodic(
        Duration(seconds: interval),
        (_) => _fetchLive(url, settings.deviceId),
      );
    } else {
      setState(() {
        _readings = const [];
        _payload = null;
        _liveFetchFailed = false;
        _isConnecting = false;
      });
    }
  }

  Future<void> _fetchLive(String baseUrl, String deviceId) async {
    final payload = await SensorApiService.fetchLatest(
      baseUrl,
      deviceId: deviceId,
    );
    if (!mounted) return;
    if (payload != null) {
      setState(() {
        _payload = payload;
        _readings = _mapPayloadToReadings(payload);
        _liveFetchFailed = false;
        _isConnecting = false;
      });
    } else {
      setState(() {
        _liveFetchFailed = true;
        _isConnecting = false;
      });
    }
  }

  List<SensorReading> _mapPayloadToReadings(SensorBridgePayload p) {
    final now = DateTime.now();
    final oilPct =
        p.engineOilLimit > 0
            ? (p.engineOil / p.engineOilLimit * 100).clamp(0.0, 100.0)
            : 0.0;
    final transPct =
        p.gearOilLimit > 0
            ? (p.gearOil / p.gearOilLimit * 100).clamp(0.0, 100.0)
            : 0.0;

    String tempSt = 'NORMAL';
    if (p.temp > 95) {
      tempSt = 'CRITICAL';
    } else if (p.temp > 85) {
      tempSt = 'WARNING';
    }

    String batSt = 'NORMAL';
    if (p.battery < 11) {
      batSt = 'CRITICAL';
    } else if (p.battery < 12) {
      batSt = 'WARNING';
    }

    String oilSt = 'NORMAL';
    if (oilPct < 30) {
      oilSt = 'CRITICAL';
    } else if (oilPct < 50) {
      oilSt = 'WARNING';
    }

    String transSt = 'NORMAL';
    if (transPct < 30) {
      transSt = 'CRITICAL';
    } else if (transPct < 50) {
      transSt = 'WARNING';
    }

    String trendFor(String type, double newVal) {
      try {
        final old = _readings.firstWhere((r) => r.sensorType == type).value;
        if (newVal > old + 0.5) return 'up';
        if (newVal < old - 0.5) return 'down';
      } catch (_) {}
      return 'stable';
    }

    return [
      SensorReading(
        sensorType: 'OIL',
        value: oilPct,
        unit: '%',
        status: oilSt,
        timestamp: now,
        label: 'زيت المحرك',
        trend: trendFor('OIL', oilPct),
      ),
      SensorReading(
        sensorType: 'TEMP',
        value: p.temp,
        unit: '°',
        status: tempSt,
        timestamp: now,
        label: 'حرارة المحرك',
        trend: trendFor('TEMP', p.temp),
      ),
      SensorReading(
        sensorType: 'BATTERY',
        value: p.battery,
        unit: 'V',
        status: batSt,
        timestamp: now,
        label: 'البطارية',
        trend: trendFor('BATTERY', p.battery),
      ),
      SensorReading(
        sensorType: 'TRANS',
        value: transPct,
        unit: '%',
        status: transSt,
        timestamp: now,
        label: 'زيت القير',
        trend: trendFor('TRANS', transPct),
      ),
    ];
  }

  (double value, String unit) _formatTempForDisplay(
    SensorReading r,
    String tempUnit,
  ) {
    if (r.sensorType != 'TEMP') return (r.value, r.unit);
    if (tempUnit == 'fahrenheit') {
      final f = r.value * 9 / 5 + 32;
      return (f, '°F');
    }
    return (r.value, '°C');
  }

  List<Widget> _buildSensorRows(SettingsProvider settings) {
    final cards =
        _readings.map((r) {
          final (value, unit) = _formatTempForDisplay(
            r,
            settings.temperatureUnit,
          );
          return SensorCard(
            label: r.label,
            value: value,
            unit: unit,
            status: r.status,
            icon: _sensorIcon(r.sensorType),
            trend: r.trend,
            timestamp: intl.DateFormat('HH:mm').format(r.timestamp),
          );
        }).toList();
    if (cards.isEmpty) return [];
    final rows = <Widget>[];
    for (var i = 0; i < cards.length; i += 2) {
      final a = cards[i];
      final b = i + 1 < cards.length ? cards[i + 1] : null;
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            if (b != null) ...[const SizedBox(width: 12), Expanded(child: b)],
          ],
        ),
      );
      if (b != null && i + 2 < cards.length) {
        rows.add(const SizedBox(height: 12));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    _updateTimerIfNeeded(settings);
    final updatedAt = _payload?.updatedAt;
    final lastUpdate = _formatUpdatedAt(updatedAt);
    final hasLive =
        settings.useLiveSensors &&
        settings.sensorServerBaseUrl.trim().isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!hasLive)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.link_off, color: AppColors.warning),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'يجب تحديد عنوان سيرفر الحساسات من الإعدادات. لا توجد بيانات وهمية في هذه الصفحة.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (hasLive && _isConnecting)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'جاري الاتصال بالسيرفر…',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (hasLive && _liveFetchFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.warning.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_off, color: AppColors.warning),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'تعذر جلب بيانات السيرفر. على Chrome استخدم http://localhost:3000 وليس 10.0.2.2',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (hasLive && _payload != null && !_liveFetchFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.sensors,
                              color: AppColors.success,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'وضع الحساسات الحيّة — ${settings.sensorServerBaseUrl}',
                                style: const TextStyle(fontSize: 12),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // شريط الحالة العامة
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _overallColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _overallMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'آخر تحديث: $lastUpdate',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                _buildTelemetrySummary(),
                const SizedBox(height: 20),

                // مستشعرات 2×2 — صفوف بدل GridView لتفادي قصّ المحتوى على الويب
                if (_readings.isNotEmpty) ...[
                  ..._buildSensorRows(settings),
                ] else
                  _buildNoDataCard(),
                const SizedBox(height: 20),

                // ملخص الإحصائيات
                Row(
                  children: [
                    _StatChip(
                      label: 'طبيعي',
                      count:
                          _readings.where((r) => r.status == 'NORMAL').length,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'تحذير',
                      count:
                          _readings.where((r) => r.status == 'WARNING').length,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'حرجة',
                      count:
                          _readings.where((r) => r.status == 'CRITICAL').length,
                      color: AppColors.critical,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatUpdatedAt(String? iso) {
    if (iso == null || iso.isEmpty) return '--:--:--';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return intl.DateFormat('HH:mm:ss').format(dt);
    } catch (_) {
      return '--:--:--';
    }
  }

  Widget _buildTelemetrySummary() {
    final p = _payload;
    final engineKm = p?.engineOil ?? 0;
    final gearKm = p?.gearOil ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _TelemetryItem(
              label: 'المتبقي زيت المحرك',
              value: '${intl.NumberFormat('#,###').format(engineKm)} كم',
              color: AppColors.success,
              icon: Icons.oil_barrel_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TelemetryItem(
              label: 'المتبقي زيت القير',
              value: '${intl.NumberFormat('#,###').format(gearKm)} كم',
              color: AppColors.primary,
              icon: Icons.settings,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors_off, color: Colors.grey),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'لا توجد قراءات حية حالياً. شغّل الحساسات وتأكد من وصول البيانات إلى السيرفر.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: $count',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _TelemetryItem({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
