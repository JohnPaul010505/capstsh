import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_record.dart';
import 'supabase_client.dart';

class MealService {
  final SupabaseClient _client;

  MealService() : _client = SupabaseClientService().client;

  Future<List<MealRecord>> getMeals(String memberId, {DateTime? date}) async {
    var query = _client
        .from('meal_records')
        .select()
        .eq('member_id', memberId);

    if (date != null) {
      final dateStr = date.toIso8601String().split('T')[0];
      query = query
          .gte('recorded_at', '${dateStr}T00:00:00')
          .lte('recorded_at', '${dateStr}T23:59:59');
    }

    final response = await query.order('recorded_at', ascending: false);
    return (response as List).map((e) => MealRecord.fromJson(e)).toList();
  }

  Future<MealRecord> createMeal(MealRecord meal) async {
    final response = await _client
        .from('meal_records')
        .insert(meal.toJson())
        .select()
        .single();
    return MealRecord.fromJson(response);
  }
}
