import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/historical_data.dart';
import '../providers/settings_provider.dart';
import '../services/history_api_service.dart';
import '../theme/app_theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _selectedSensor = 'all';
  String _selectedPeriod = 'today';
  List<HistoricalData> _historicalData = const [];
  bool _isLoading = false;
  bool _loadFailed = false;
  String _lastBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final baseUrl = context.watch<SettingsProvider>().sensorServerBaseUrl.trim();
    if (baseUrl != _lastBaseUrl) {
      _lastBaseUrl = baseUrl;
      _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    final baseUrl = context.read<SettingsProvider>().sensorServerBaseUrl;
    final deviceId = context.read<SettingsProvider>().deviceId;
    if (baseUrl.trim().isEmpty) {
      setState(() {
        _historicalData = const [];
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
      final rows = await HistoryApiService.fetchHistory(
        baseUrl: baseUrl,
        period: _selectedPeriod,
        deviceId: deviceId,
      );
      if (!mounted) return;
      setState(() {
        _historicalData = rows;
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

  double _convertTemp(double celsius, String tempUnit) {
    if (tempUnit == 'fahrenheit') return celsius * 9 / 5 + 32;
    return celsius;
  }

  List<double> _getValuesForSensor(String sensor, String tempUnit) {
    if (sensor == 'all') return _historicalData.map((d) => _convertTemp(d.temp, tempUnit)).toList();
    switch (sensor) {
      case 'oil':
        return _historicalData.map((d) => d.oil).toList();
      case 'temp':
        return _historicalData.map((d) => _convertTemp(d.temp, tempUnit)).toList();
      case 'battery':
        return _historicalData.map((d) => d.battery).toList();
      case 'trans':
        return _historicalData.map((d) => d.trans).toList();
      default:
        return _historicalData.map((d) => d.temp).toList();
    }
  }

  (double avg, double max, double min) _calculateStats(String sensor, String tempUnit) {
    final values = _getValuesForSensor(sensor, tempUnit);
    if (values.isEmpty) return (0, 0, 0);
    final avg = values.reduce((a, b) => a + b) / values.length;
    final max = values.reduce((a, b) => a > b ? a : b);
    final min = values.reduce((a, b) => a < b ? a : b);
    return (avg, max, min);
  }

  LineChartData _buildChartData(String tempUnit) {
    if (_historicalData.isEmpty) {
      return LineChartData(
        minX: 0,
        maxX: 1,
        minY: 0,
        maxY: 1,
        lineBarsData: [],
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      );
    }

    final lineBarsData = <LineChartBarData>[];

    if (_selectedSensor == 'all') {
      lineBarsData.addAll([
        _buildLineBar(
          _historicalData.map((d) => d.oil).toList(),
          AppColors.success,
          'زيت المحرك',
        ),
        _buildLineBar(
          _historicalData.map((d) => _convertTemp(d.temp, tempUnit)).toList(),
          AppColors.warning,
          'حرارة المحرك',
        ),
        _buildLineBar(
          _historicalData.map((d) => d.trans).toList(),
          AppColors.pink,
          'زيت القير',
        ),
      ]);
    } else {
      final values = _getValuesForSensor(_selectedSensor, tempUnit);
      final color = _getSensorColor(_selectedSensor);
      final label = _getSensorLabel(_selectedSensor);
      lineBarsData.add(_buildLineBar(values, color, label));
    }

    final allValues = _selectedSensor == 'temp' || _selectedSensor == 'all'
        ? _historicalData.expand((d) => [d.oil, _convertTemp(d.temp, tempUnit), d.battery, d.trans]).toList()
        : _historicalData.expand((d) => [d.oil, d.temp, d.battery, d.trans]).toList();
    final minY = (allValues.reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, double.infinity);
    final maxY = allValues.reduce((a, b) => a > b ? a : b) + 5;

    return LineChartData(
      minX: 0,
      maxX: (_historicalData.length - 1).toDouble(),
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: (maxY - minY) / 5,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.grey.withValues(alpha: 0.2),
          strokeWidth: 1,
        ),
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 36,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
              ),
            ),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 3,
            getTitlesWidget: (value, meta) {
              final idx = value.round();
              if (idx >= 0 && idx < _historicalData.length) {
                return Text(
                  _historicalData[idx].timestamp,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 10,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: lineBarsData,
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
            String label;
            if (_selectedSensor == 'all') {
              if (spot.barIndex == 0) {
                label = 'زيت: ${spot.y.toStringAsFixed(0)}%';
              } else if (spot.barIndex == 1) {
                final unit = tempUnit == 'fahrenheit' ? '°F' : '°C';
                label = 'حرارة: ${spot.y.toStringAsFixed(0)}$unit';
              } else {
                label = 'قير: ${spot.y.toStringAsFixed(0)}%';
              }
            } else {
              final suffix = _selectedSensor == 'temp' ? (tempUnit == 'fahrenheit' ? '°F' : '°C') : '';
              label = '${_getSensorLabel(_selectedSensor)}: ${spot.y.toStringAsFixed(1)}$suffix';
            }
            return LineTooltipItem(
              label,
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            );
          }).toList(),
          getTooltipColor: (touchedSpot) => AppColors.primary,
          tooltipRoundedRadius: 8,
        ),
      ),
    );
  }

  LineChartBarData _buildLineBar(List<double> values, Color color, String label) {
    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: _selectedSensor == 'all' ? 2 : 3,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Color _getSensorColor(String sensor) {
    switch (sensor) {
      case 'oil':
        return AppColors.success;
      case 'temp':
        return AppColors.warning;
      case 'battery':
        return AppColors.purple;
      case 'trans':
        return AppColors.pink;
      default:
        return AppColors.primary;
    }
  }

  String _getSensorLabel(String sensor) {
    switch (sensor) {
      case 'oil':
        return 'زيت المحرك';
      case 'temp':
        return 'حرارة المحرك';
      case 'battery':
        return 'البطارية';
      case 'trans':
        return 'زيت القير';
      default:
        return '';
    }
  }

  String _formatValue(String sensor, double value, String tempUnit) {
    switch (sensor) {
      case 'oil':
      case 'trans':
        return '${value.toStringAsFixed(0)}%';
      case 'temp':
        return '${value.toStringAsFixed(0)}${tempUnit == 'fahrenheit' ? '°F' : '°C'}';
      case 'battery':
        return '${value.toStringAsFixed(1)}V';
      default:
        return value.toStringAsFixed(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final tempUnit = settings.temperatureUnit;
    final stats = _calculateStats(_selectedSensor, tempUnit);
    final displaySensor = _selectedSensor == 'all' ? 'temp' : _selectedSensor;

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
                // الفلاتر
                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        value: _selectedSensor,
                        items: const {
                          'all': 'جميع القراءات',
                          'oil': 'زيت المحرك',
                          'temp': 'حرارة المحرك',
                          'battery': 'البطارية',
                          'trans': 'زيت القير',
                        },
                        onChanged: (v) => setState(() => _selectedSensor = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FilterDropdown(
                        value: _selectedPeriod,
                        items: const {
                          'today': 'اليوم',
                          'week': 'هذا الأسبوع',
                          'month': 'هذا الشهر',
                        },
                        onChanged: (v) {
                          setState(() => _selectedPeriod = v!);
                          _fetchHistory();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _fetchHistory,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('تحديث البيانات'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                if (settings.sensorServerBaseUrl.trim().isEmpty)
                  _NoticeCard(
                    icon: Icons.link_off,
                    color: AppColors.warning,
                    message:
                        'حدد عنوان سيرفر الحساسات من الإعدادات لعرض السجل الحقيقي.',
                  )
                else if (_isLoading)
                  _NoticeCard(
                    icon: Icons.sync,
                    color: AppColors.primary,
                    message: 'جاري جلب السجل التاريخي...',
                  )
                else if (_loadFailed)
                  _NoticeCard(
                    icon: Icons.cloud_off,
                    color: AppColors.critical,
                    message: 'تعذر جلب السجل التاريخي. تأكد من عنوان السيرفر.',
                  )
                else if (_historicalData.isEmpty)
                  _NoticeCard(
                    icon: Icons.inbox_outlined,
                    color: AppColors.primary,
                    message: 'لا توجد قراءات محفوظة لهذه الفترة بعد.',
                  ),
                if (settings.sensorServerBaseUrl.trim().isNotEmpty)
                  const SizedBox(height: 20),

                // بطاقات الإحصائيات
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'المتوسط',
                        value: _formatValue(displaySensor, stats.$1, tempUnit),
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'أعلى قيمة',
                        value: _formatValue(displaySensor, stats.$2, tempUnit),
                        color: AppColors.critical,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'أقل قيمة',
                        value: _formatValue(displaySensor, stats.$3, tempUnit),
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // الرسم البياني
                Container(
                  padding: const EdgeInsets.all(12),
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
                  height: 220,
                  child: LineChart(_buildChartData(tempUnit)),
                ),
                const SizedBox(height: 20),

                // دليل الألوان (عند all)
                if (_selectedSensor == 'all') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _LegendItem(color: AppColors.success, label: 'زيت'),
                      const SizedBox(width: 16),
                      _LegendItem(color: AppColors.warning, label: 'حرارة'),
                      const SizedBox(width: 16),
                      _LegendItem(color: AppColors.pink, label: 'قير'),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // جدول البيانات
                const Text(
                  'البيانات الأخيرة',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        AppColors.primary.withValues(alpha: 0.08),
                      ),
                      columns: const [
                        DataColumn(label: Text('الوقت')),
                        DataColumn(label: Text('زيت')),
                        DataColumn(label: Text('حرارة')),
                        DataColumn(label: Text('بطارية')),
                        DataColumn(label: Text('قير')),
                      ],
                      rows: _historicalData.take(8).map((row) {
                        final tempVal = _convertTemp(row.temp, tempUnit);
                        final tempSuffix = tempUnit == 'fahrenheit' ? '°F' : '°C';
                        return DataRow(
                          cells: [
                            DataCell(Text(row.timestamp)),
                            DataCell(Text('${row.oil.toStringAsFixed(0)}%')),
                            DataCell(Text('${tempVal.toStringAsFixed(0)}$tempSuffix')),
                            DataCell(Text('${row.battery.toStringAsFixed(1)}V')),
                            DataCell(Text('${row.trans.toStringAsFixed(0)}%')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _FilterDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: items.entries
            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border(top: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
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
          width: 12,
          height: 12,
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
