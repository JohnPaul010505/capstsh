class Goal {
  final String id;
  final String memberId;
  final String title;
  final String? description;
  final double? targetValue;
  final double? currentValue;
  final String? unit;
  final String? deadline;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.id,
    required this.memberId,
    required this.title,
    this.description,
    this.targetValue,
    this.currentValue,
    this.unit,
    this.deadline,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String?,
    targetValue: (json['target_value'] as num?)?.toDouble(),
    currentValue: (json['current_value'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    deadline: json['deadline'] as String?,
    status: json['status'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'member_id': memberId,
    'title': title,
    'description': description,
    'target_value': targetValue,
    'current_value': currentValue,
    'unit': unit,
    'deadline': deadline,
    'status': status,
  };
}
