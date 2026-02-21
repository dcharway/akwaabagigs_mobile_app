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
  });

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
      requirements: List<String>.from(json['requirements'] ?? []),
      gigImages: List<String>.from(json['gigImages'] ?? []),
      postedBy: json['postedBy'] ?? '',
      posterId: json['posterId'] ?? '',
      postedDate: DateTime.tryParse(json['postedDate'] ?? '') ?? DateTime.now(),
      status: json['status'] ?? 'active',
      category: json['category'],
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
    };
  }
}
