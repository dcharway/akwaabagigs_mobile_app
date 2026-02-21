class Application {
  final String id;
  final String jobId;
  final String email;
  final String fullName;
  final String phone;
  final String? position;
  final String? idDocumentName;
  final String? idDocumentType;
  final String? resumeName;
  final DateTime applicationDate;
  final String status;
  final Map<String, dynamic>? verificationResult;
  final DateTime? verifiedDate;
  final String? rejectionReason;
  final String? rejectionResolution;
  final String? jobTitle;
  final String? jobCompany;

  Application({
    required this.id,
    required this.jobId,
    required this.email,
    required this.fullName,
    required this.phone,
    this.position,
    this.idDocumentName,
    this.idDocumentType,
    this.resumeName,
    required this.applicationDate,
    required this.status,
    this.verificationResult,
    this.verifiedDate,
    this.rejectionReason,
    this.rejectionResolution,
    this.jobTitle,
    this.jobCompany,
  });

  factory Application.fromJson(Map<String, dynamic> json) {
    return Application(
      id: json['id'] ?? '',
      jobId: json['jobId'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      phone: json['phone'] ?? '',
      position: json['position'],
      idDocumentName: json['idDocumentName'],
      idDocumentType: json['idDocumentType'],
      resumeName: json['resumeName'],
      applicationDate:
          DateTime.tryParse(json['applicationDate'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'pending_verification',
      verificationResult: json['verificationResult'] is Map
          ? Map<String, dynamic>.from(json['verificationResult'])
          : null,
      verifiedDate: json['verifiedDate'] != null
          ? DateTime.tryParse(json['verifiedDate'])
          : null,
      rejectionReason: json['rejectionReason'],
      rejectionResolution: json['rejectionResolution'],
      jobTitle: json['jobTitle'],
      jobCompany: json['jobCompany'],
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending_verification':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  bool get isPending => status == 'pending_verification';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
