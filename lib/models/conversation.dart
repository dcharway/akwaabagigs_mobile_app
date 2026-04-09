class Conversation {
  final String id;
  final String type;
  final String? jobId;
  final String? jobTitle;
  final String posterId;
  final String posterName;
  final String? seekerId;
  final String seekerEmail;
  final String seekerName;
  /// Array of user IDs in this conversation (many-to-many).
  final List<String> participants;
  /// Display names keyed by userId for rendering.
  final Map<String, String> participantNames;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final int messageCount;
  final DateTime createdAt;

  Conversation({
    required this.id,
    this.type = 'one_to_one',
    this.jobId,
    this.jobTitle,
    required this.posterId,
    required this.posterName,
    this.seekerId,
    required this.seekerEmail,
    required this.seekerName,
    required this.participants,
    this.participantNames = const {},
    this.lastMessageText,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.messageCount = 0,
    required this.createdAt,
  });

  /// Check if a user is part of this conversation.
  bool hasParticipant(String userId) => participants.contains(userId);

  /// Get the display name for a participant.
  String nameOf(String userId) => participantNames[userId] ?? 'Unknown';

  /// Get the "other" party name given the current user's ID.
  String otherPartyName(String currentUserId) {
    // Find the first participant that isn't the current user
    for (final uid in participants) {
      if (uid != currentUserId) {
        return participantNames[uid] ?? 'Unknown';
      }
    }
    // Fallback to legacy fields
    if (currentUserId == posterId) return seekerName;
    return posterName;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Parse participants array — support both new array and legacy A/B fields
    List<String> participants;
    if (json['participants'] is List) {
      participants = List<String>.from(json['participants']);
    } else {
      // Build from legacy fields
      final a = json['participantA'] ?? json['posterId'] ?? '';
      final b = json['participantB'] ?? json['seekerEmail'] ?? '';
      participants = [if (a.isNotEmpty) a, if (b.isNotEmpty) b];
    }

    // Parse participant names map
    Map<String, String> participantNames;
    if (json['participantNames'] is Map) {
      participantNames = Map<String, String>.from(json['participantNames']);
    } else {
      participantNames = {};
      final posterId = json['posterId'] ?? '';
      final posterName = json['posterName'] ?? '';
      final seekerEmail = json['seekerEmail'] ?? '';
      final seekerName = json['seekerName'] ?? '';
      if (posterId.isNotEmpty && posterName.isNotEmpty) {
        participantNames[posterId] = posterName;
      }
      if (seekerEmail.isNotEmpty && seekerName.isNotEmpty) {
        participantNames[seekerEmail] = seekerName;
      }
    }

    return Conversation(
      id: json['id'] ?? '',
      type: json['type'] ?? 'one_to_one',
      jobId: json['jobId'],
      jobTitle: json['jobTitle'],
      posterId: json['posterId'] ?? '',
      posterName: json['posterName'] ?? '',
      seekerId: json['seekerId'],
      seekerEmail: json['seekerEmail'] ?? '',
      seekerName: json['seekerName'] ?? '',
      participants: participants,
      participantNames: participantNames,
      lastMessageText: json['lastMessageText'],
      lastMessageSenderId: json['lastMessageSenderId'],
      lastMessageAt: json['lastMessageAt'] != null
          ? DateTime.tryParse(json['lastMessageAt'])
          : null,
      messageCount: json['messageCount'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'posterId': posterId,
      'posterName': posterName,
      'seekerId': seekerId,
      'seekerEmail': seekerEmail,
      'seekerName': seekerName,
      'participants': participants,
      'participantNames': participantNames,
      'lastMessageText': lastMessageText,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageAt': lastMessageAt?.toIso8601String(),
      'messageCount': messageCount,
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
