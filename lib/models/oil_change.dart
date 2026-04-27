/// سجل تغيير الزيت
class OilChange {
  final String id;
  final String date; // ISO format
  final int mileage;
  final String? notes;

  OilChange({
    required this.id,
    required this.date,
    required this.mileage,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'mileage': mileage,
        'notes': notes,
      };

  factory OilChange.fromJson(Map<String, dynamic> json) => OilChange(
        id: json['id'] as String,
        date: json['date'] as String,
        mileage: json['mileage'] as int,
        notes: json['notes'] as String?,
      );
}
