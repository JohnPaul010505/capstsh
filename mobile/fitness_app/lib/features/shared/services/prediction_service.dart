import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

/// One forecast line returned by `POST /api/ai/predictions`
/// (ai-service/routers/predictions.py, local scikit-learn - no Gemini needed).
class PredictionResult {
  final String predictionType;
  final double currentValue;
  final double predictedValue;
  final String unit;
  final int daysAhead;
  final double confidence;

  const PredictionResult({
    required this.predictionType,
    required this.currentValue,
    required this.predictedValue,
    required this.unit,
    required this.daysAhead,
    required this.confidence,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) => PredictionResult(
        predictionType: json['prediction_type'] as String? ?? '',
        currentValue: (json['current_value'] as num?)?.toDouble() ?? 0,
        predictedValue: (json['predicted_value'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
        daysAhead: (json['days_ahead'] as num?)?.toInt() ?? 30,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );

  bool get isRetention => predictionType == 'retention_risk';

  /// high / medium / low - mirrors services/ml.py retention_risk() thresholds.
  String get riskLabel {
    if (!isRetention) return '';
    if (predictedValue > 0.7) return 'high';
    if (predictedValue > 0.4) return 'medium';
    return 'low';
  }
}

/// Outcome of one forecast request. A 404 ("Not enough data") is a normal
/// outcome for new members, not an error.
class MemberForecast {
  final List<PredictionResult> results;
  final bool notEnoughData;
  final String? error;

  const MemberForecast({
    required this.results,
    this.notEnoughData = false,
    this.error,
  });

  PredictionResult? byType(String type) {
    for (final r in results) {
      if (r.predictionType == type) return r;
    }
    return null;
  }

  PredictionResult? get retention {
    for (final r in results) {
      if (r.isRetention) return r;
    }
    return null;
  }
}

class PredictionService {
  Future<MemberForecast> getForecast(String memberId, {int daysAhead = 30}) async {
    try {
      final resp = await http
          .post(
            Uri.parse('${aiApiBaseUrl()}/api/ai/predictions'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'member_id': memberId, 'days_ahead': daysAhead}),
          )
          .timeout(const Duration(seconds: 20));

      if (resp.statusCode == 200) {
        final list = (jsonDecode(resp.body) as List)
            .map((e) => PredictionResult.fromJson(e as Map<String, dynamic>))
            .toList();
        return MemberForecast(results: list);
      }
      if (resp.statusCode == 404) {
        String? detail;
        try {
          detail = (jsonDecode(resp.body) as Map<String, dynamic>)['detail'] as String?;
        } catch (_) {}
        return MemberForecast(results: const [], notEnoughData: true, error: detail);
      }
      return MemberForecast(
        results: const [],
        error: 'Prediction service error (${resp.statusCode})',
      );
    } catch (e) {
      debugPrint('PREDICTION SERVICE unreachable: $e');
      return MemberForecast(
        results: const [],
        error: 'Could not reach the prediction service',
      );
    }
  }
}
