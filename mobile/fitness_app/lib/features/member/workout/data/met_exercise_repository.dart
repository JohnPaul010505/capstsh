import 'package:shared/services/supabase_client.dart';

class MetExercise {
  final String id;
  final String name;
  final String category;
  final double metValue;

  const MetExercise({
    required this.id,
    required this.name,
    required this.category,
    required this.metValue,
  });

  factory MetExercise.fromJson(Map<String, dynamic> json) => MetExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    category: json['category'] as String,
    metValue: (json['met_value'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'met_value': metValue,
  };
}

class SearchMetResponse {
  final List<MetExercise> matches;
  const SearchMetResponse({required this.matches});
  
  factory SearchMetResponse.fromJson(Map<String, dynamic> json) => SearchMetResponse(
    matches: (json['matches'] as List<dynamic>? ?? [])
        .map((m) => MetExercise.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}

class MetExerciseRepository {
  final SupabaseClientService _supabase = SupabaseClientService();

  MetExerciseRepository();

  Future<SearchMetResponse> search(String query) async {
    if (query.trim().length < 2) return const SearchMetResponse(matches: []);

    try {
      final result = await _supabase.client.rpc('search_met_exercises', params: {
        'search_query': query,
        'similarity_threshold': 0.4,
        'match_limit': 10,
      });
      
      final matches = (result as List<dynamic>? ?? [])
          .map((m) => MetExercise.fromJson(m as Map<String, dynamic>))
          .toList();
      
      return SearchMetResponse(matches: matches);
    } catch (_) {
      return const SearchMetResponse(matches: []);
    }
  }
}