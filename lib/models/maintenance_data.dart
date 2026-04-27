import 'oil_change.dart';

/// بيانات الصيانة الرئيسية
class MaintenanceData {
  final int currentMileage;
  final int oilChangeInterval;
  final OilChange? lastOilChange;
  final List<OilChange> oilChangeHistory;

  MaintenanceData({
    required this.currentMileage,
    required this.oilChangeInterval,
    this.lastOilChange,
    required this.oilChangeHistory,
  });

  MaintenanceData copyWith({
    int? currentMileage,
    int? oilChangeInterval,
    OilChange? lastOilChange,
    List<OilChange>? oilChangeHistory,
  }) =>
      MaintenanceData(
        currentMileage: currentMileage ?? this.currentMileage,
        oilChangeInterval: oilChangeInterval ?? this.oilChangeInterval,
        lastOilChange: lastOilChange ?? this.lastOilChange,
        oilChangeHistory: oilChangeHistory ?? this.oilChangeHistory,
      );

  Map<String, dynamic> toJson() => {
        'currentMileage': currentMileage,
        'oilChangeInterval': oilChangeInterval,
        'lastOilChange': lastOilChange?.toJson(),
        'oilChangeHistory': oilChangeHistory.map((e) => e.toJson()).toList(),
      };

  factory MaintenanceData.fromJson(Map<String, dynamic> json) {
    final history = (json['oilChangeHistory'] as List?)
            ?.map((e) => OilChange.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final last = json['lastOilChange'] != null
        ? OilChange.fromJson(json['lastOilChange'] as Map<String, dynamic>)
        : null;
    return MaintenanceData(
      currentMileage: json['currentMileage'] as int? ?? 50000,
      oilChangeInterval: json['oilChangeInterval'] as int? ?? 5000,
      lastOilChange: last,
      oilChangeHistory: history.isNotEmpty ? history : (last != null ? [last] : []),
    );
  }
}

/// حالة الزيت
enum OilStatus { normal, warning, critical }
