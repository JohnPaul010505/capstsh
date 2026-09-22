import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One AI goal suggestion (POST /api/ai/goal-adjustments,
/// ai-service/routers/goals.py). goal_type carries the goal's title.
class GoalSuggestion {
  final String goalType;
  final double currentValue;
  final double suggestedValue;
  final String reason;

  const GoalSuggestion({
    required this.goalType,
    required this.currentValue,
    required this.suggestedValue,
    required this.reason,
  });

  factory GoalSuggestion.fromJson(Map<String, dynamic> json) => GoalSuggestion(
        goalType: json['goal_type'] as String? ?? '',
        currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
        suggestedValue: (json['suggested_value'] as num?)?.toDouble() ?? 0,
        reason: json['reason'] as String? ?? '',
      );
}

class GoalSuggestionService {
  /// Returns suggestions; an empty list with a non-null error means the
  /// service was unreachable (callers show their own empty state).
  Future<List<GoalSuggestion>> getSuggestions(String memberId) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${aiApiBaseUrl()}/api/ai/goal-adjustments'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'member_id': memberId}),
          )
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        return (jsonDecode(resp.body) as List)
            .map((e) => GoalSuggestion.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      debugPrint('GOAL SUGGESTIONS error ${resp.statusCode}: ${resp.body}');
      return const [];
    } catch (e) {
      debugPrint('GOAL SUGGESTIONS unreachable: $e');
      return const [];
    }
  }
}
