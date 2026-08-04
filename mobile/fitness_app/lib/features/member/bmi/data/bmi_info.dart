import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';

/// Resolved BMI value with its WHO category label.
class BmiInfo {
  final double bmi;
  final String label;
  final DateTime measuredAt;

  const BmiInfo({required this.bmi, required this.label, required this.measuredAt});
}

/// Computes a [BmiInfo] from a single body-measurement row, or null when the
/// row can't produce a BMI (missing height/weight or invalid values).
BmiInfo? bmiFromMeasurement({
  required num? heightCm,
  required num? weightKg,
  required DateTime measuredAt,
}) {
  final height = heightCm?.toDouble();
  final weight = weightKg?.toDouble();
  if (height == null || height <= 0 || weight == null) return null;
  final h = height / 100;
  return BmiInfo(bmi: weight / (h * h), label: bmiCategoryLabel(weight / (h * h)), measuredAt: measuredAt);
}

String bmiCategoryLabel(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Normal';
  if (bmi < 30) return 'Overweight';
  return 'Obese';
}

Color bmiCategoryColor(double bmi) {
  if (bmi < 18.5) return const Color(0xFF64D2FF);
  if (bmi < 25) return ClayTokens.clayAccent;
  if (bmi < 30) return ClayTokens.clayWarning;
  return ClayTokens.clayError;
}
