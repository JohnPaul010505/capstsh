class Profile {
  final String id;
  final String role;
  final String fullName;
  final String email;
  final String code;
  final String? phone;
  final String? avatarUrl;
  final String? dateOfBirth;
  final String? gender;
  final DateTime createdAt;
  final DateTime updatedAt;

  Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    required this.code,
    this.phone,
    this.avatarUrl,
    this.dateOfBirth,
    this.gender,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'] as String,
    role: json['role'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    code: json['code'] as String,
    phone: json['phone'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    gender: json['gender'] as String?,
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'full_name': fullName,
    'email': email,
    'code': code,
    'phone': phone,
    'avatar_url': avatarUrl,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
