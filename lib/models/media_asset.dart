class MediaAsset {
  final String id;
  final String title;
  final String? fileUrl;
  final String mediaType; // 'image' or 'video'
  final String? mimeType;
  final int? sizeBytes;
  final bool isActive;
  final String? uploader;
  final DateTime createdAt;

  MediaAsset({
    required this.id,
    required this.title,
    this.fileUrl,
    required this.mediaType,
    this.mimeType,
    this.sizeBytes,
    this.isActive = true,
    this.uploader,
    required this.createdAt,
  });

  bool get isVideo =>
      mediaType == 'video' ||
      (mimeType != null && mimeType!.startsWith('video/'));

  bool get isImage =>
      mediaType == 'image' ||
      (mimeType != null && mimeType!.startsWith('image/'));

  factory MediaAsset.fromJson(Map<String, dynamic> json) {
    return MediaAsset(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      fileUrl: json['fileUrl'],
      mediaType: json['mediaType'] ?? 'image',
      mimeType: json['mimeType'],
      sizeBytes: json['sizeBytes'],
      isActive: json['isActive'] ?? true,
      uploader: json['uploader'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
