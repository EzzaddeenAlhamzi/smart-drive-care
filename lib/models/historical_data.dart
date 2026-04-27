/// نقطة بيانات تاريخية
class HistoricalData {
  final String timestamp; // HH:MM
  final DateTime? recordedAt;
  final double oil;
  final double temp;
  final double battery;
  final double trans;

  HistoricalData({
    required this.timestamp,
    this.recordedAt,
    required this.oil,
    required this.temp,
    required this.battery,
    required this.trans,
  });

  factory HistoricalData.fromServer(Map<String, dynamic> json) {
    final rawTs = (json['timestamp'] as String?) ?? '';
    DateTime? dt;
    try {
      dt = DateTime.parse(rawTs).toLocal();
    } catch (_) {
      dt = null;
    }
    double d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;

    return HistoricalData(
      timestamp: dt != null
          ? '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
          : '--:--',
      recordedAt: dt,
      oil: d(json['oil']),
      temp: d(json['temp']),
      battery: d(json['battery']),
      trans: d(json['trans']),
    );
  }
}
