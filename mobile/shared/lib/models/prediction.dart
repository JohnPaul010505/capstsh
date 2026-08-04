class Prediction {
  final String id;
  final String memberId;
  final String metricName;
  final double? predictedValue;
  final String? predictedDate;
  final double? confidence;
  final DateTime createdAt;

  Prediction({
    required this.id,
    required this.memberId,
    required this.metricName,
    this.predictedValue,
    this.predictedDate,
    this.confidence,
    required this.createdAt,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) => Prediction(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    metricName: json['metric_name'] as String,
    predictedValue: (json['predicted_value'] as num?)?.toDouble(),
    predictedDate: json['predicted_date'] as String?,
    confidence: (json['confidence'] as num?)?.toDouble(),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
