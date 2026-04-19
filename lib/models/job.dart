class Job {
  final String id;
  final String title;
  final String company;
  final String description;
  final String location;
  final String? locationRange;
  final String salary;
  final String employmentType;
  final List<String> requirements;
  final List<String> gigImages;
  final String postedBy;
  final String posterId;
  final DateTime postedDate;
  final String status;
  final String? category;
  // Revenue/monetization fields
  final bool isFeatured;
  final bool isUrgent;
  final DateTime? featuredUntil;
  final int? offerAmount;
  final String escrowStatus;
  final int escrowAmount;
  // Chat/bid agreement fields
  final bool chatEnabled;
  final int? agreedAmountPesewas;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    required this.location,
    this.locationRange,
    required this.salary,
    required this.employmentType,
    required this.requirements,
    required this.gigImages,
    required this.postedBy,
    required this.posterId,
    required this.postedDate,
    required this.status,
    this.category,
    this.isFeatured = false,
    this.isUrgent = false,
    this.featuredUntil,
    this.offerAmount,
    this.escrowStatus = 'none',
    this.escrowAmount = 0,
    this.chatEnabled = false,
    this.agreedAmountPesewas,
  });

  bool get isCurrentlyFeatured =>
      isFeatured &&
      featuredUntil != null &&
      featuredUntil!.isAfter(DateTime.now());

  /// Agreed amount in GHS
  double? get agreedAmountGhs =>
      agreedAmountPesewas != null ? agreedAmountPesewas! / 100 : null;

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      company: json['company'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      locationRange: json['locationRange'],
      salary: json['salary'] ?? '',
      employmentType: json['employmentType'] ?? '',
      requirements: (json['requirements'] as List?)?.cast<String>() ?? const [],
      gigImages: (json['gigImages'] as List?)?.cast<String>() ?? const [],
      postedBy: json['postedBy'] ?? '',
      posterId: json['posterId'] ?? '',
      postedDate: json['postedDate'] != null
          ? DateTime.tryParse(json['postedDate']) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] ?? 'active',
      category: json['category'],
      isFeatured: json['isFeatured'] ?? false,
      isUrgent: json['isUrgent'] ?? false,
      featuredUntil: json['featuredUntil'] != null
          ? DateTime.tryParse(json['featuredUntil'])
          : null,
      offerAmount: json['offerAmount'],
      escrowStatus: json['escrowStatus'] ?? 'none',
      escrowAmount: json['escrowAmount'] ?? 0,
      chatEnabled: json['chatEnabled'] ?? false,
      agreedAmountPesewas: json['agreedAmountPesewas'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'company': company,
      'description': description,
      'location': location,
      'locationRange': locationRange,
      'salary': salary,
      'employmentType': employmentType,
      'requirements': requirements,
      'gigImages': gigImages,
      'postedBy': postedBy,
      'posterId': posterId,
      'postedDate': postedDate.toIso8601String(),
      'status': status,
      'category': category,
      'isFeatured': isFeatured,
      'isUrgent': isUrgent,
      'featuredUntil': featuredUntil?.toIso8601String(),
      'offerAmount': offerAmount,
      'escrowStatus': escrowStatus,
      'escrowAmount': escrowAmount,
      'chatEnabled': chatEnabled,
      'agreedAmountPesewas': agreedAmountPesewas,
    };
  }
}
