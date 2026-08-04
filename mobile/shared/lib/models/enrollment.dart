class Enrollment {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? dateOfBirth;
  final String? gender;
  final String? address;
  final String status;
  final String? confirmedAt;
  final String? confirmedBy;
  final String createdAt;

  Enrollment({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.address,
    required this.status,
    this.confirmedAt,
    this.confirmedBy,
    required this.createdAt,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) => Enrollment(
    id: json['id'] as String,
    fullName: json['full_name'] as String,
    email: json['email'] as String,
    phone: json['phone'] as String?,
    dateOfBirth: json['date_of_birth'] as String?,
    gender: json['gender'] as String?,
    address: json['address'] as String?,
    status: json['status'] as String,
    confirmedAt: json['confirmed_at'] as String?,
    confirmedBy: json['confirmed_by'] as String?,
    createdAt: json['created_at'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'email': email,
    'phone': phone,
    'date_of_birth': dateOfBirth,
    'gender': gender,
    'address': address,
    'status': status,
    'confirmed_at': confirmedAt,
    'confirmed_by': confirmedBy,
    'created_at': createdAt,
  };
}
