import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_food.dart';
import 'supabase_client.dart';

class NutritionService {
  final SupabaseClient _client = SupabaseClientService().client;

  Future<List<NutritionFood>> searchFoods(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    final response = await _client
        .from('nutrition_foods')
        .select()
        .or('food_name.ilike.%$q%,category.ilike.%$q%')
        .order('food_name', ascending: true)
        .limit(20);
    return (response as List)
        .map((e) => NutritionFood.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<NutritionFood?> lookupByName(String name) async {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return null;
    final response = await _client
        .from('nutrition_foods')
        .select()
        .ilike('food_name', '%$q%')
        .maybeSingle();
    if (response == null || response.isEmpty) return null;
    return NutritionFood.fromJson(response);
  }

  Future<List<NutritionFood>> getAllFoods() async {
    final response = await _client
        .from('nutrition_foods')
        .select()
        .order('food_name', ascending: true);
    return (response as List)
        .map((e) => NutritionFood.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
