class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? firebaseUid;
  final String? role; // 'seeker', 'poster', or null
  final String? profileImageUrl;
  final bool isAdmin;
  final bool phoneVerified;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.firebaseUid,
    this.role,
    this.profileImageUrl,
    this.isAdmin = false,
    this.phoneVerified = false,
    this.createdAt,
    this.updatedAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isSeeker => role == 'seeker';
  bool get isPoster => role == 'poster';
  bool get hasRole => role != null && role!.isNotEmpty;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      firstName: json['firstName'] ?? '',
      lastName: json['lastName'] ?? '',
      phone: json['phone'],
      firebaseUid: json['firebaseUid'],
      role: json['role'],
      profileImageUrl: json['profileImageUrl'],
      isAdmin: json['isAdmin'] ?? false,
      phoneVerified: json['phoneVerified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'firebaseUid': firebaseUid,
      'role': role,
      'profileImageUrl': profileImageUrl,
      'isAdmin': isAdmin,
      'phoneVerified': phoneVerified,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
