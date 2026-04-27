import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fl_chart/fl_chart.dart';
import '../models/alert.dart';
import '../models/historical_data.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../services/alerts_api_service.dart';
import '../services/history_api_service.dart';
import '../theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<HistoricalData> _rows = const [];
  List<Alert> _alerts = const [];
  bool _isLoading = false;
  bool _loadFailed = false;
  String _lastBaseUrl = '';

  double _convertTemp(double celsius, String tempUnit) {
    if (tempUnit == 'fahrenheit') return celsius * 9 / 5 + 32;
    return celsius;
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseUrl = context.watch<SettingsProvider>().sensorServerBaseUrl.trim();
    if (baseUrl != _lastBaseUrl) {
      _lastBaseUrl = baseUrl;
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    final baseUrl = context.read<SettingsProvider>().sensorServerBaseUrl;
    if (baseUrl.trim().isEmpty) {
      setState(() {
        _rows = const [];
        _alerts = const [];
        _isLoading = false;
        _loadFailed = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });

    try {
      final results = await Future.wait([
        HistoryApiService.fetchHistory(baseUrl: baseUrl, period: 'month'),
        AlertsApiService.fetchAlerts(baseUrl),
      ]);
      if (!mounted) return;
      setState(() {
        _rows = results[0] as List<HistoricalData>;
        _alerts = results[1] as List<Alert>;
        _isLoading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
  }

  String _dayLabel(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الإثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      default:
        return '-';
    }
  }

  ({int total, int normal, int warnings, int critical}) _summaryFromReadings() {
    int normal = 0;
    int warnings = 0;
    int critical = 0;
    for (final r in _rows) {
      final tempCritical = r.temp > 95;
      final tempWarning = r.temp > 85;
      final batteryCritical = r.battery < 11;
      final batteryWarning = r.battery < 12;
      final oilCritical = r.oil < 30;
      final oilWarning = r.oil < 50;
      final transCritical = r.trans < 30;
      final transWarning = r.trans < 50;

      final isCritical = tempCritical || batteryCritical || oilCritical || transCritical;
      final isWarning =
          tempWarning || batteryWarning || oilWarning || transWarning;

      if (isCritical) {
        critical++;
      } else if (isWarning) {
        warnings++;
      } else {
        normal++;
      }
    }
    return (total: _rows.length, normal: normal, warnings: warnings, critical: critical);
  }

  List<Map<String, dynamic>> _weeklyAverages() {
    final now = DateTime.now();
    final dayBuckets = <String, List<HistoricalData>>{};
    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final key = '${d.year}-${d.month}-${d.day}';
      dayBuckets[key] = [];
    }

    for (final r in _rows) {
      final dt = r.recordedAt;
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month}-${dt.day}';
      final bucket = dayBuckets[key];
      if (bucket != null) bucket.add(r);
    }

    final out = <Map<String, dynamic>>[];
    dayBuckets.forEach((key, list) {
      final parts = key.split('-').map(int.parse).toList();
      final dt = DateTime(parts[0], parts[1], parts[2]);
      if (list.isEmpty) {
        out.add({'day': _dayLabel(dt.weekday), 'oil': 0.0, 'temp': 0.0});
      } else {
        final oilAvg = list.map((e) => e.oil).reduce((a, b) => a + b) / list.length;
        final tempAvg = list.map((e) => e.temp).reduce((a, b) => a + b) / list.length;
        out.add({
          'day': _dayLabel(dt.weekday),
          'oil': double.parse(oilAvg.toStringAsFixed(1)),
          'temp': double.parse(tempAvg.toStringAsFixed(1)),
        });
      }
    });
    return out;
  }

  List<Map<String, dynamic>> _alertsByType() {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));
    final recent = _alerts.where((a) => a.timestamp.isAfter(monthAgo)).toList();

    final groups = <String, List<Alert>>{};
    for (final a in recent) {
      final key = a.sensorType;
      groups.putIfAbsent(key, () => []).add(a);
    }

    String sensorLabel(String sensorType) {
      switch (sensorType) {
        case 'TEMP':
          return 'حرارة عالية';
        case 'OIL':
          return 'انخفاض الزيت';
        case 'BATTERY':
          return 'مشاكل البطارية';
        case 'TRANS':
          return 'زيت القير';
        default:
          return 'تنبيهات عامة';
      }
    }

    String trendFor(List<Alert> list) {
      final weekAgo = now.subtract(const Duration(days: 7));
      final twoWeeksAgo = now.subtract(const Duration(days: 14));
      final current = list.where((a) => a.timestamp.isAfter(weekAgo)).length;
      final prev = list
          .where((a) => a.timestamp.isAfter(twoWeeksAgo) && a.timestamp.isBefore(weekAgo))
          .length;
      if (current > prev) return 'up';
      if (current < prev) return 'down';
      return 'stable';
    }

    final out = groups.entries
        .map((e) => {
              'type': sensorLabel(e.key),
              'count': e.value.length,
              'trend': trendFor(e.value),
            })
        .toList();
    out.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return out.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tempUnit = settings.temperatureUnit;
    final summary = _summaryFromReadings();
    final totalReadings = summary.total;
    final normalReadings = summary.normal;
    final warnings = summary.warnings;
    final critical = summary.critical;

    final double avgTemp = _rows.isEmpty
        ? 0.0
        : _rows.map((r) => r.temp).reduce((a, b) => a + b) / _rows.length;
    final double avgOil = _rows.isEmpty
        ? 0.0
        : _rows.map((r) => r.oil).reduce((a, b) => a + b) / _rows.length;
    final double avgBattery = _rows.isEmpty
        ? 0.0
        : _rows.map((r) => r.battery).reduce((a, b) => a + b) / _rows.length;
    final double avgTrans = _rows.isEmpty
        ? 0.0
        : _rows.map((r) => r.trans).reduce((a, b) => a + b) / _rows.length;

    final weeklyAverages = _weeklyAverages();
    final alertsByType = _alertsByType();

    final now = DateTime.now();
    final monthName = intl.DateFormat('MMMM yyyy').format(now);

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
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'التقارير',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                        Text(
                          'تقارير شاملة عن أداء المركبة',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await ExportService.exportReportsPdf(
                            monthName: monthName,
                            totalReadings: totalReadings,
                            normalReadings: normalReadings,
                            warnings: warnings,
                            critical: critical,
                            avgOil: avgOil,
                            avgTemp: avgTemp,
                            avgBattery: avgBattery,
                            avgTrans: avgTrans,
                            tempUnit: tempUnit,
                            alertsByType: alertsByType,
                            weeklyAverages: weeklyAverages,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تصدير التقرير بنجاح'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('فشل التصدير: $e'),
                                backgroundColor: AppColors.critical,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('تصدير PDF'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (settings.sensorServerBaseUrl.trim().isEmpty)
                  _NoticeCard(
                    icon: Icons.link_off,
                    color: AppColors.warning,
                    message: 'حدد عنوان السيرفر من الإعدادات لعرض تقارير حقيقية.',
                  )
                else if (_isLoading)
                  _NoticeCard(
                    icon: Icons.sync,
                    color: AppColors.primary,
                    message: 'جاري تحميل بيانات التقرير...',
                  )
                else if (_loadFailed)
                  _NoticeCard(
                    icon: Icons.cloud_off,
                    color: AppColors.critical,
                    message: 'تعذر تحميل البيانات. تحقق من اتصال السيرفر.',
                  ),
                const SizedBox(height: 20),

                // Banner فترة التقرير
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.success.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_month,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'تقرير الشهر الحالي',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              monthName,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // بطاقات الملخص 4
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                  children: [
                    _SummaryCard(
                      label: 'إجمالي القراءات',
                      value: intl.NumberFormat('#,###').format(totalReadings),
                      color: AppColors.primary,
                    ),
                    _SummaryCard(
                      label: 'قراءات طبيعية',
                      value: intl.NumberFormat('#,###').format(normalReadings),
                      subtitle: totalReadings == 0
                          ? '0%'
                          : '${((normalReadings / totalReadings) * 100).toStringAsFixed(0)}%',
                      color: AppColors.success,
                    ),
                    _SummaryCard(
                      label: 'تحذيرات',
                      value: intl.NumberFormat('#,###').format(warnings),
                      subtitle: totalReadings == 0
                          ? '0%'
                          : '${((warnings / totalReadings) * 100).toStringAsFixed(0)}%',
                      color: AppColors.warning,
                    ),
                    _SummaryCard(
                      label: 'حالات حرجة',
                      value: intl.NumberFormat('#,###').format(critical),
                      subtitle: totalReadings == 0
                          ? '0%'
                          : '${((critical / totalReadings) * 100).toStringAsFixed(0)}%',
                      color: AppColors.critical,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // الرسوم البيانية
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 500;
                    return isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildBarChart(weeklyAverages),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPieChart(),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildBarChart(weeklyAverages),
                              const SizedBox(height: 16),
                              _buildPieChart(),
                            ],
                          );
                  },
                ),
                const SizedBox(height: 24),

                // متوسطات القراءات الشهرية
                const Text(
                  'متوسطات القراءات الشهرية',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _AvgCard(
                      label: 'زيت المحرك',
                      value: '$avgOil%',
                      color: AppColors.success,
                    ),
                    _AvgCard(
                      label: 'حرارة المحرك',
                      value: '${_convertTemp(avgTemp, tempUnit).toStringAsFixed(1)}${tempUnit == 'fahrenheit' ? '°F' : '°C'}',
                      color: AppColors.warning,
                    ),
                    _AvgCard(
                      label: 'البطارية',
                      value: '${avgBattery.toStringAsFixed(1)}V',
                      color: AppColors.purple,
                    ),
                    _AvgCard(
                      label: 'زيت القير',
                      value: '$avgTrans%',
                      color: AppColors.pink,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // التنبيهات حسب النوع
                const Text(
                  'التنبيهات حسب النوع',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                ...alertsByType.asMap().entries.map((e) {
                  final i = e.key + 1;
                  final item = e.value;
                  final trend = item['trend'] as String;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$i',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['type'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${item['count']} تنبيه',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (trend == 'up')
                          Icon(Icons.trending_up,
                              color: AppColors.critical, size: 20),
                        if (trend == 'down')
                          Icon(Icons.trending_down,
                              color: AppColors.success, size: 20),
                        if (trend == 'stable')
                          Icon(Icons.trending_flat,
                              color: Colors.grey, size: 20),
                      ],
                    ),
                  );
                }),
                if (alertsByType.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'لا توجد تنبيهات خلال الفترة الحالية.',
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> weeklyAverages) {
    final maxY = weeklyAverages.isEmpty
        ? 100.0
        : (weeklyAverages
                    .expand((e) => [e['oil'] as double, e['temp'] as double])
                    .fold<double>(0, (p, v) => v > p ? v : p) +
                10)
            .clamp(50, 160)
            .toDouble();
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'المتوسطات الأسبوعية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barGroups: weeklyAverages.asMap().entries.map((e) {
                  final i = e.key;
                  final d = e.value;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: d['oil'] as double,
                        color: AppColors.success,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: d['temp'] as double,
                        color: AppColors.warning,
                        width: 8,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                    showingTooltipIndicators: [0, 1],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < weeklyAverages.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              weeklyAverages[idx]['day'] as String,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 28,
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: AppColors.success, label: 'زيت'),
              const SizedBox(width: 16),
              _LegendItem(color: AppColors.warning, label: 'حرارة'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final summary = _summaryFromReadings();
    final total = summary.total == 0 ? 1 : summary.total;
    final normalPct = ((summary.normal / total) * 100).roundToDouble();
    final warningPct = ((summary.warnings / total) * 100).roundToDouble();
    final criticalPct = ((summary.critical / total) * 100).roundToDouble();
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'توزيع الحالات',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: normalPct,
                    color: AppColors.success,
                    title: '${normalPct.toInt()}%',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: warningPct,
                    color: AppColors.warning,
                    title: '${warningPct.toInt()}%',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: criticalPct,
                    color: AppColors.critical,
                    title: '${criticalPct.toInt()}%',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              swapAnimationDuration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            children: [
              _LegendItem(color: AppColors.success, label: 'طبيعي'),
              _LegendItem(color: AppColors.warning, label: 'تحذير'),
              _LegendItem(color: AppColors.critical, label: 'حرج'),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;

  const _NoticeCard({
    required this.icon,
    required this.color,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(top: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvgCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AvgCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
