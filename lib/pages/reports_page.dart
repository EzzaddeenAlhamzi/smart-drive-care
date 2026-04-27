import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fl_chart/fl_chart.dart';
import '../providers/settings_provider.dart';
import '../services/export_service.dart';
import '../theme/app_theme.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  double _convertTemp(double celsius, String tempUnit) {
    if (tempUnit == 'fahrenheit') return celsius * 9 / 5 + 32;
    return celsius;
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tempUnit = settings.temperatureUnit;
    // بيانات محاكاة
    const totalReadings = 2880;
    const normalReadings = 2160;
    const warnings = 518;
    const critical = 202;
    const avgTemp = 86.5;
    const avgOil = 73.2;
    const avgBattery = 12.5;
    const avgTrans = 62.8;

    final weeklyAverages = [
      {'day': 'السبت', 'oil': 78.0, 'temp': 85.0},
      {'day': 'الأحد', 'oil': 76.0, 'temp': 87.0},
      {'day': 'الإثنين', 'oil': 74.0, 'temp': 86.0},
      {'day': 'الثلاثاء', 'oil': 72.0, 'temp': 88.0},
      {'day': 'الأربعاء', 'oil': 71.0, 'temp': 85.0},
      {'day': 'الخميس', 'oil': 73.0, 'temp': 86.0},
      {'day': 'الجمعة', 'oil': 75.0, 'temp': 84.0},
    ];

    final alertsByType = [
      {'type': 'حرارة عالية', 'count': 85, 'trend': 'up'},
      {'type': 'انخفاض الزيت', 'count': 56, 'trend': 'down'},
      {'type': 'مشاكل البطارية', 'count': 42, 'trend': 'stable'},
      {'type': 'زيت القير', 'count': 37, 'trend': 'down'},
    ];

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
                      subtitle:
                          '${((normalReadings / totalReadings) * 100).toStringAsFixed(0)}%',
                      color: AppColors.success,
                    ),
                    _SummaryCard(
                      label: 'تحذيرات',
                      value: intl.NumberFormat('#,###').format(warnings),
                      subtitle:
                          '${((warnings / totalReadings) * 100).toStringAsFixed(0)}%',
                      color: AppColors.warning,
                    ),
                    _SummaryCard(
                      label: 'حالات حرجة',
                      value: intl.NumberFormat('#,###').format(critical),
                      subtitle:
                          '${((critical / totalReadings) * 100).toStringAsFixed(0)}%',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(List<Map<String, dynamic>> weeklyAverages) {
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
                maxY: 100,
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
                    value: 75,
                    color: AppColors.success,
                    title: '75%',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 18,
                    color: AppColors.warning,
                    title: '18%',
                    radius: 45,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: 7,
                    color: AppColors.critical,
                    title: '7%',
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
