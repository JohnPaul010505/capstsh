class MealRecord {
  final String id;
  final String memberId;
  final String mealType;
  final String foodItems;
  final int? calories;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;
  final DateTime recordedAt;

  MealRecord({
    required this.id,
    required this.memberId,
    required this.mealType,
    required this.foodItems,
    this.calories,
    this.proteinG,
    this.carbsG,
    this.fatG,
    required this.recordedAt,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) => MealRecord(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    mealType: json['meal_type'] as String,
    foodItems: json['food_items'] as String,
    calories: json['calories'] as int?,
    proteinG: (json['protein_g'] as num?)?.toDouble(),
    carbsG: (json['carbs_g'] as num?)?.toDouble(),
    fatG: (json['fat_g'] as num?)?.toDouble(),
    recordedAt: DateTime.parse(json['recorded_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'meal_type': mealType,
    'food_items': foodItems,
    'calories': calories,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
  };
}
