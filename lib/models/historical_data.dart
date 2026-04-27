/// نقطة بيانات تاريخية
class HistoricalData {
  final String timestamp; // HH:MM
  final double oil;
  final double temp;
  final double battery;
  final double trans;

  HistoricalData({
    required this.timestamp,
    required this.oil,
    required this.temp,
    required this.battery,
    required this.trans,
  });
}
