class Rating {
  final String id;
  final String jobId;
  final String applicationId;
  final String posterId;
  final String posterName;
  final String gigSeekerId;
  final String gigSeekerName;
  final int rating;
  final String? review;
  final DateTime createdAt;

  Rating({
    required this.id,
    required this.jobId,
    required this.applicationId,
    required this.posterId,
    required this.posterName,
    required this.gigSeekerId,
    required this.gigSeekerName,
    required this.rating,
    this.review,
    required this.createdAt,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    return Rating(
      id: json['id'] ?? '',
      jobId: json['jobId'] ?? '',
      applicationId: json['applicationId'] ?? '',
      posterId: json['posterId'] ?? '',
      posterName: json['posterName'] ?? '',
      gigSeekerId: json['gigSeekerId'] ?? '',
      gigSeekerName: json['gigSeekerName'] ?? '',
      rating: json['rating'] ?? 0,
      review: json['review'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class SeekerRatingSummary {
  final double averageRating;
  final int totalRatings;
  final List<Rating> ratings;

  SeekerRatingSummary({
    required this.averageRating,
    required this.totalRatings,
    required this.ratings,
  });

  factory SeekerRatingSummary.fromJson(Map<String, dynamic> json) {
    final ratingsJson = json['ratings'] as List<dynamic>? ?? [];
    return SeekerRatingSummary(
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      totalRatings: json['totalRatings'] ?? 0,
      ratings: ratingsJson.map((r) => Rating.fromJson(r)).toList(),
    );
  }
}
