import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/maintenance_provider.dart';
import '../providers/settings_provider.dart';
import '../models/sensor_reading.dart';
import '../services/sensor_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/sensor_card.dart';
import '../widgets/oil_change_card.dart';
import '../widgets/mileage_update_dialog.dart';
import '../widgets/oil_change_dialog.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late List<SensorReading> _readings;
  Timer? _timer;
  int _currentInterval = 0;
  bool _wasLive = false;
  String _lastSensorUrl = '';
  bool _liveFetchFailed = false;
  bool _liveHadSuccessfulFetch = false;

  @override
  void initState() {
    super.initState();
    _readings = _initialReadings();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<SensorReading> _initialReadings() {
    final now = DateTime.now();
    return [
      SensorReading(
        sensorType: 'OIL',
        value: 72,
        unit: '%',
        status: 'NORMAL',
        timestamp: now,
        label: 'زيت المحرك',
        trend: 'stable',
      ),
      SensorReading(
        sensorType: 'TEMP',
        value: 82,
        unit: '°',
        timestamp: now,
        status: 'NORMAL',
        label: 'حرارة المحرك',
        trend: 'stable',
      ),
      SensorReading(
        sensorType: 'BATTERY',
        value: 12.5,
        unit: 'V',
        timestamp: now,
        status: 'NORMAL',
        label: 'البطارية',
        trend: 'stable',
      ),
      SensorReading(
        sensorType: 'TRANS',
        value: 65,
        unit: '%',
        timestamp: now,
        status: 'NORMAL',
        label: 'زيت القير',
        trend: 'stable',
      ),
    ];
  }

  void _simulateUpdate() {
    setState(() {
      _readings = _readings.map((r) {
        final change = (DateTime.now().millisecond % 3 - 1) * 0.8;
        double newVal = r.value + change;
        if (r.sensorType == 'BATTERY') {
          newVal = newVal.clamp(11.0, 14.0);
        } else {
          newVal = newVal.clamp(0.0, 100.0);
        }
        String status = 'NORMAL';
        if (r.sensorType == 'TEMP') {
          if (newVal > 95) {
            status = 'CRITICAL';
          } else if (newVal > 85) {
            status = 'WARNING';
          }
        } else if (r.sensorType == 'OIL' || r.sensorType == 'TRANS') {
          if (newVal < 30) {
            status = 'CRITICAL';
          } else if (newVal < 50) {
            status = 'WARNING';
          }
        }
        String trend = change > 0.5 ? 'up' : (change < -0.5 ? 'down' : 'stable');
        return SensorReading(
          sensorType: r.sensorType,
          value: newVal,
          unit: r.unit,
          status: status,
          timestamp: DateTime.now(),
          label: r.label,
          trend: trend,
        );
      }).toList();
    });
  }

  String get _overallStatus {
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

    if (interval == _currentInterval && live == _wasLive && url == _lastSensorUrl) {
      return;
    }

    _currentInterval = interval;
    _wasLive = live;
    _lastSensorUrl = url;
    _timer?.cancel();

    if (live && url.isNotEmpty) {
      Future.microtask(() {
        if (!mounted) return;
        setState(() {
          _liveFetchFailed = false;
          _liveHadSuccessfulFetch = false;
        });
      });
      _fetchLive(url);
      _timer = Timer.periodic(
        Duration(seconds: interval),
        (_) => _fetchLive(url),
      );
    } else {
      setState(() {
        _readings = _initialReadings();
        _liveFetchFailed = false;
        _liveHadSuccessfulFetch = false;
      });
      _timer = Timer.periodic(
        Duration(seconds: interval),
        (_) => _simulateUpdate(),
      );
    }
  }

  Future<void> _fetchLive(String baseUrl) async {
    final payload = await SensorApiService.fetchLatest(baseUrl);
    if (!mounted) return;
    if (payload != null) {
      setState(() {
        _readings = _mapPayloadToReadings(payload);
        _liveFetchFailed = false;
        _liveHadSuccessfulFetch = true;
      });
    } else {
      setState(() {
        _liveFetchFailed = true;
        _liveHadSuccessfulFetch = false;
      });
    }
  }

  List<SensorReading> _mapPayloadToReadings(SensorBridgePayload p) {
    final now = DateTime.now();
    final oilPct = p.engineOilLimit > 0
        ? (p.engineOil / p.engineOilLimit * 100).clamp(0.0, 100.0)
        : 0.0;
    final transPct = p.gearOilLimit > 0
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

  (double value, String unit) _formatTempForDisplay(SensorReading r, String tempUnit) {
    if (r.sensorType != 'TEMP') return (r.value, r.unit);
    if (tempUnit == 'fahrenheit') {
      final f = r.value * 9 / 5 + 32;
      return (f, '°F');
    }
    return (r.value, '°C');
  }

  List<Widget> _buildSensorRows(SettingsProvider settings) {
    final cards = _readings.map((r) {
      final (value, unit) = _formatTempForDisplay(r, settings.temperatureUnit);
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
            if (b != null) ...[
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
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
    final provider = context.watch<MaintenanceProvider>();
    final settings = context.watch<SettingsProvider>();
    _updateTimerIfNeeded(settings);
    final lastUpdate = _readings.isNotEmpty
        ? intl.DateFormat('HH:mm:ss').format(_readings.first.timestamp)
        : '--:--:--';

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
                if (settings.useLiveSensors &&
                    !_liveHadSuccessfulFetch &&
                    !_liveFetchFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
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
                            const SizedBox(width: 12),
                            const Expanded(
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
                if (settings.useLiveSensors && _liveFetchFailed)
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
                if (settings.useLiveSensors &&
                    _liveHadSuccessfulFetch &&
                    !_liveFetchFailed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Icon(Icons.sensors, color: AppColors.success, size: 22),
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

                // قراءة العداد والأزرار
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.speed, color: AppColors.primary, size: 28),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'قراءة العداد',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${intl.NumberFormat('#,###').format(provider.data.currentMileage)} كم',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      children: [
                        IconButton.filled(
                          onPressed: () => MileageUpdateDialog.show(context),
                          icon: const Icon(Icons.edit),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          onPressed: () => OilChangeDialog.show(context),
                          icon: const Icon(Icons.build, size: 18),
                          label: const Text('تغيير زيت'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.success,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // بطاقة حالة الزيت
                const OilChangeCard(),
                const SizedBox(height: 20),

                // مستشعرات 2×2 — صفوف بدل GridView لتفادي قصّ المحتوى على الويب
                ..._buildSensorRows(settings),
                const SizedBox(height: 20),

                // ملخص الإحصائيات
                Row(
                  children: [
                    _StatChip(
                      label: 'طبيعي',
                      count: _readings.where((r) => r.status == 'NORMAL').length,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'تحذير',
                      count: _readings.where((r) => r.status == 'WARNING').length,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'حرجة',
                      count: _readings.where((r) => r.status == 'CRITICAL').length,
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
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: $count',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
