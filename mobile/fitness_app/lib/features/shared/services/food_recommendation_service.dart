import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared/services/supabase_client.dart';

import 'api_config.dart';

/// One AI food suggestion (POST /api/ai/food-recommendations,
/// ai-service/routers/food.py — Filipino dishes aligned with nutrition_foods).
class FoodSuggestion {
  final String foodName;
  final String portion;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String reason;

  const FoodSuggestion({
    required this.foodName,
    required this.portion,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.reason,
  });

  factory FoodSuggestion.fromJson(Map<String, dynamic> json) => FoodSuggestion(
        foodName: json['food_name'] as String? ?? '',
        portion: json['portion'] as String? ?? '',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0,
        carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0,
        fatG: (json['fat_g'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String? ?? '',
      );
}

class FoodSuggestionsResult {
  final List<FoodSuggestion> suggestions;
  final String? error;

  const FoodSuggestionsResult({required this.suggestions, this.error});
}

/// Objective 6: personalized Filipino meal suggestions, persisted into
/// food_recommendations (Table 18: meal_type, food_name, portion_size, reason).
class FoodRecommendationService {
  Future<FoodSuggestionsResult> getSuggestions(String memberId, String mealType) async {
    List<FoodSuggestion> parsed = const [];
    String? error;
    try {
      final resp = await http
          .post(
            Uri.parse('${aiApiBaseUrl()}/api/ai/food-recommendations'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'member_id': memberId, 'meal_type': mealType}),
          )
          .timeout(const Duration(seconds: 25));
      if (resp.statusCode == 200) {
        parsed = (jsonDecode(resp.body) as List)
            .map((e) => FoodSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
      } else {
        error = 'Suggestion service error (${resp.statusCode})';
        debugPrint('FOOD RECOMMENDATIONS error ${resp.statusCode}: ${resp.body}');
      }
    } catch (e) {
      debugPrint('FOOD RECOMMENDATIONS unreachable: $e');
      error = 'Could not reach the suggestion service';
    }
    if (parsed.isNotEmpty) {
      await _persist(memberId, mealType, parsed);
    }
    return FoodSuggestionsResult(suggestions: parsed, error: error);
  }

  /// Best-effort persist (Table 18). A failure must never block the card.
  Future<void> _persist(String memberId, String mealType, List<FoodSuggestion> suggestions) async {
    try {
      final client = SupabaseClientService().client;
      for (final s in suggestions) {
        await client.from('food_recommendations').insert({
          'member_id': memberId,
          'meal_type': mealType,
          'food_name': s.foodName,
          'portion_size': s.portion,
          'reason': s.reason,
        });
      }
    } catch (e) {
      debugPrint('FOOD RECOMMENDATIONS persist failed: $e');
    }
  }
}
