class Conversation {
  final String id;
  final String? jobId;
  final String? jobTitle;
  final String posterId;
  final String posterName;
  final String seekerEmail;
  final String seekerName;
  final String participantA;
  final String participantB;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  Conversation({
    required this.id,
    this.jobId,
    this.jobTitle,
    required this.posterId,
    required this.posterName,
    required this.seekerEmail,
    required this.seekerName,
    required this.participantA,
    required this.participantB,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      jobId: json['jobId'],
      jobTitle: json['jobTitle'],
      posterId: json['posterId'] ?? '',
      posterName: json['posterName'] ?? '',
      seekerEmail: json['seekerEmail'] ?? '',
      seekerName: json['seekerName'] ?? '',
      participantA: json['participantA'] ?? json['posterId'] ?? '',
      participantB: json['participantB'] ?? json['seekerEmail'] ?? '',
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'])
          : null,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'posterId': posterId,
      'posterName': posterName,
      'seekerEmail': seekerEmail,
      'seekerName': seekerName,
      'participantA': participantA,
      'participantB': participantB,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String content;
  final String? fileUrl;
  final String? fileName;
  final String? fileType;
  final bool isRead;
  final String? flagged;
  final String? flagCategory;
  final String? censored;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.content,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.isRead,
    this.flagged,
    this.flagCategory,
    this.censored,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      conversationId: json['conversationId'] ?? '',
      senderId: json['senderId'] ?? '',
      senderName: json['senderName'] ?? '',
      content: json['content'] ?? '',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileType: json['fileType'],
      isRead: json['isRead'] ?? false,
      flagged: json['flagged'],
      flagCategory: json['flagCategory'],
      censored: json['censored'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String get displayContent => censored ?? content;
}
