class MediaAsset {
  final String id;
  final String title;
  final String? description;
  final String? fileUrl;
  final String? thumbnailUrl;
  final String mediaType;
  final String? mimeType;
  final int? sizeBytes;
  final bool isActive;
  final String? uploader;
  final DateTime createdAt;

  // ---- Sponsored / campaign fields ----
  final bool isSponsored;
  final String? advertiserName;
  final String? ctaLabel;
  final String? ctaUrl;
  final String? campaignId;
  final int priority;
  final DateTime? scheduleStart;
  final DateTime? scheduleEnd;

  MediaAsset({
    required this.id,
    required this.title,
    this.description,
    this.fileUrl,
    this.thumbnailUrl,
    required this.mediaType,
    this.mimeType,
    this.sizeBytes,
    this.isActive = true,
    this.uploader,
    required this.createdAt,
    this.isSponsored = false,
    this.advertiserName,
    this.ctaLabel,
    this.ctaUrl,
    this.campaignId,
    this.priority = 0,
    this.scheduleStart,
    this.scheduleEnd,
  });

  bool get isVideo =>
      mediaType == 'video' ||
      (mimeType != null && mimeType!.startsWith('video/'));

  bool get isImage =>
      mediaType == 'image' ||
      (mimeType != null && mimeType!.startsWith('image/'));

  bool get hasCta => ctaLabel != null && ctaLabel!.isNotEmpty;

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      fileUrl: json['fileUrl'],
      thumbnailUrl: json['thumbnailUrl'],
      mediaType: json['mediaType'] ?? 'image',
      mimeType: json['mimeType'],
      sizeBytes: json['sizeBytes'],
      isActive: json['isActive'] ?? true,
      uploader: json['uploader'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      isSponsored: json['isSponsored'] ?? false,
      advertiserName: json['advertiserName'],
      ctaLabel: json['ctaLabel'],
      ctaUrl: json['ctaUrl'],
      campaignId: json['campaignId'],
      priority: json['priority'] ?? 0,
      scheduleStart: json['scheduleStart'] != null
          ? DateTime.tryParse(json['scheduleStart'])
          : null,
      scheduleEnd: json['scheduleEnd'] != null
          ? DateTime.tryParse(json['scheduleEnd'])
          : null,
    );
  }
}
