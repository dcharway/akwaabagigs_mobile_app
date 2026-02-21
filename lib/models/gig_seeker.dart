class GigSeeker {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String location;
  final String? skills;
  final String? experience;
  final String? idDocumentUrl;
  final String verificationStatus;
  final String? rejectionReason;
  final bool canChat;
  final String? profilePictureUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  GigSeeker({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.location,
    this.skills,
    this.experience,
    this.idDocumentUrl,
    required this.verificationStatus,
    this.rejectionReason,
    required this.canChat,
    this.profilePictureUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GigSeeker.fromJson(Map<String, dynamic> json) {
    return GigSeeker(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      location: json['location'] ?? '',
      skills: json['skills'],
      experience: json['experience'],
      idDocumentUrl: json['idDocumentUrl'],
      verificationStatus: json['verificationStatus'] ?? 'unverified',
      rejectionReason: json['rejectionReason'],
      canChat: json['canChat'] ?? false,
      profilePictureUrl: json['profilePictureUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';
}
