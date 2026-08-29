class NutritionFood {
  final String id;
  final String foodName;
  final List<String> aliases;
  final String category;
  final String servingLabel;
  final double servingSizeG;
  final double caloriesKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String source;

  NutritionFood({
    required this.id,
    required this.foodName,
    required this.aliases,
    required this.category,
    required this.servingLabel,
    required this.servingSizeG,
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.source,
  });

  factory NutritionFood.fromJson(Map<String, dynamic> json) => NutritionFood(
    id: json['id'] as String,
    foodName: json['food_name'] as String,
    aliases: (json['aliases'] as List<dynamic>?)?.cast<String>() ?? const [],
    category: json['category'] as String? ?? '',
    servingLabel: json['serving_label'] as String? ?? '',
    servingSizeG: (json['serving_size_g'] as num?)?.toDouble() ?? 0.0,
    caloriesKcal: (json['calories_kcal'] as num?)?.toDouble() ?? 0.0,
    proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
    carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
    fatG: (json['fat_g'] as num?)?.toDouble() ?? 0.0,
    source: json['source'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'food_name': foodName,
    'aliases': aliases,
    'category': category,
    'serving_label': servingLabel,
    'serving_size_g': servingSizeG,
    'calories_kcal': caloriesKcal,
    'protein_g': proteinG,
    'carbs_g': carbsG,
    'fat_g': fatG,
    'source': source,
  };
}
