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
  // KYC fields
  final String kycStatus; // none, pending, verified, failed
  final double? kycScore; // Face match percentage
  final String? kycJobId; // Smile ID job reference
  final String? verifiedDocType; // GHANA_CARD, VOTER_ID, etc.
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
    this.kycStatus = 'none',
    this.kycScore,
    this.kycJobId,
    this.verifiedDocType,
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
      kycStatus: json['kycStatus'] ?? 'none',
      kycScore: (json['kycScore'] is num)
          ? (json['kycScore'] as num).toDouble()
          : null,
      kycJobId: json['kycJobId'],
      verifiedDocType: json['verifiedDocType'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';
  bool get isKycVerified => kycStatus == 'verified';
  bool get isKycPending => kycStatus == 'pending';
}
