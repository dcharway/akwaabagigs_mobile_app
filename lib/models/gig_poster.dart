class GigPoster {
  final String id;
  final String? userId;
  final String businessName;
  final String? businessDescription;
  final String contactEmail;
  final String contactPhone;
  final String location;
  final String? ghCardUrl;
  final String verificationStatus;
  final String? rejectionReason;
  final String? profilePictureUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  GigPoster({
    required this.id,
    this.userId,
    required this.businessName,
    this.businessDescription,
    required this.contactEmail,
    required this.contactPhone,
    required this.location,
    this.ghCardUrl,
    required this.verificationStatus,
    this.rejectionReason,
    this.profilePictureUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GigPoster.fromJson(Map<String, dynamic> json) {
    return GigPoster(
      id: json['id'] ?? '',
      userId: json['userId'],
      businessName: json['businessName'] ?? '',
      businessDescription: json['businessDescription'],
      contactEmail: json['contactEmail'] ?? '',
      contactPhone: json['contactPhone'] ?? '',
      location: json['location'] ?? '',
      ghCardUrl: json['ghCardUrl'],
      verificationStatus: json['verificationStatus'] ?? 'unverified',
      rejectionReason: json['rejectionReason'],
      profilePictureUrl: json['profilePictureUrl'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';
}
