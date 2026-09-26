import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nutrition_food.dart';
import 'supabase_client.dart';

class NutritionService {
  final SupabaseClient _client = SupabaseClientService().client;

  /// Searches through the FNRI food name, food group, and Filipino alias.
  /// The RPC performs the text[] alias search, which the PostgREST table
  /// filter syntax cannot express for this column reliably.
  Future<List<NutritionFood>> searchFoods(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final response = await _client.rpc(
      'search_nutrition_foods',
      params: {'search_query': q},
    );
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
