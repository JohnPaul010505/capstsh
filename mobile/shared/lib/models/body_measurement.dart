class BodyMeasurement {
  final String id;
  final String memberId;
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armCm;
  final double? thighCm;
  final DateTime measuredAt;

  BodyMeasurement({
    required this.id,
    required this.memberId,
    this.weightKg,
    this.heightCm,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    required this.measuredAt,
  });

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) => BodyMeasurement(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
    chestCm: (json['chest_cm'] as num?)?.toDouble(),
    waistCm: (json['waist_cm'] as num?)?.toDouble(),
    hipsCm: (json['hips_cm'] as num?)?.toDouble(),
    armCm: (json['arm_cm'] as num?)?.toDouble(),
    thighCm: (json['thigh_cm'] as num?)?.toDouble(),
    measuredAt: DateTime.parse(json['measured_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'body_fat_pct': bodyFatPct,
    'chest_cm': chestCm,
    'waist_cm': waistCm,
    'hips_cm': hipsCm,
    'arm_cm': armCm,
    'thigh_cm': thighCm,
    'measured_at': measuredAt.toIso8601String(),
  };
}
