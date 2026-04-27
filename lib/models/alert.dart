/// نموذج التنبيه
class Alert {
  final String id;
  final String alertType;
  final String riskLevel; // CRITICAL, HIGH, MEDIUM, LOW
  final String message;
  final String suggestedAction;
  final DateTime timestamp;
  final bool acknowledged;
  final String sensorType; // TEMP, OIL, BATTERY, TRANS

  Alert({
    required this.id,
    required this.alertType,
    required this.riskLevel,
    required this.message,
    required this.suggestedAction,
    required this.timestamp,
    this.acknowledged = false,
    required this.sensorType,
  });

  Alert copyWith({bool? acknowledged}) => Alert(
        id: id,
        alertType: alertType,
        riskLevel: riskLevel,
        message: message,
        suggestedAction: suggestedAction,
        timestamp: timestamp,
        acknowledged: acknowledged ?? this.acknowledged,
        sensorType: sensorType,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'alertType': alertType,
        'riskLevel': riskLevel,
        'message': message,
        'suggestedAction': suggestedAction,
        'timestamp': timestamp.toIso8601String(),
        'acknowledged': acknowledged,
        'sensorType': sensorType,
      };

  factory Alert.fromJson(Map<String, dynamic> json) => Alert(
        id: json['id'] as String,
        alertType: json['alertType'] as String,
        riskLevel: json['riskLevel'] as String,
        message: json['message'] as String,
        suggestedAction: json['suggestedAction'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        acknowledged: json['acknowledged'] as bool? ?? false,
        sensorType: json['sensorType'] as String,
      );
}
