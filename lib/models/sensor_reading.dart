/// قراءة مستشعر
class SensorReading {
  final String sensorType; // OIL, TEMP, BATTERY, TRANS
  final double value;
  final String unit;
  final String status; // NORMAL, WARNING, CRITICAL
  final DateTime timestamp;
  final String label;
  final String trend; // up, down, stable

  SensorReading({
    required this.sensorType,
    required this.value,
    required this.unit,
    required this.status,
    required this.timestamp,
    required this.label,
    required this.trend,
  });
}
