import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';

/// Custom [LlmProvider] that bridges the Flutter AI Toolkit's chat UI
/// to Back4App Parse messaging with LiveQuery for real-time updates.
///
/// This is NOT an AI/LLM provider — it wraps person-to-person messaging
/// through the toolkit's polished chat interface.
class Back4AppChatProvider extends ChangeNotifier implements LlmProvider {
  final String chatRoomId;
  final String currentUserId;
  final String currentUserName;
  final String otherPartyName;

  LiveQuery? _liveQuery;
  Subscription? _messageSubscription;
  List<ChatMessage> _history = [];

  Back4AppChatProvider({
    required this.chatRoomId,
    required this.currentUserId,
    required this.currentUserName,
    required this.otherPartyName,
  }) {
    _loadHistory();
    _subscribeLiveQuery();
  }

  @override
  List<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> newHistory) {
    _history = newHistory.toList();
    notifyListeners();
  }

  /// Load existing messages from Back4App and convert to ChatMessage format.
  Future<void> _loadHistory() async {
    try {
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', chatRoomId)
        ..orderByAscending('createdAt');

      final response = await query.query();
      if (response.success && response.results != null) {
        _history = response.results!.map((e) {
          final obj = e as ParseObject;
          final senderId = obj.get<String>('senderId') ?? '';
          final isMe = senderId == currentUserId;
          final content = obj.get<String>('content') ?? '';
          final sender = obj.get<String>('senderName') ?? '';

          return ChatMessage(
            origin: isMe ? MessageOrigin.user : MessageOrigin.llm,
            text: isMe ? content : '[$sender] $content',
          );
        }).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load chat history: $e');
    }
  }

  /// Subscribe to LiveQuery for real-time incoming messages.
  Future<void> _subscribeLiveQuery() async {
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', chatRoomId);

      _messageSubscription = await _liveQuery!.client.subscribe(query);

      _messageSubscription!.on(LiveQueryEvent.create, (value) {
        final senderId = value.get<String>('senderId') ?? '';
        // Only add messages from the OTHER party (own messages are
        // already added via sendMessageStream)
        if (senderId != currentUserId) {
          final sender = value.get<String>('senderName') ?? otherPartyName;
          final content = value.get<String>('content') ?? '';

          _history.add(ChatMessage(
            origin: MessageOrigin.llm,
            text: '[$sender] $content',
          ));
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('LiveQuery subscription failed: $e');
    }
  }

  /// Send a message to Back4App and yield a confirmation response.
  /// The toolkit calls this when the user submits text.
  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    try {
      // Save message to Back4App
      final message = ParseObject(Back4AppConfig.messageClass)
        ..set('chatRoomId', chatRoomId)
        ..set('conversationId', chatRoomId)
        ..set('senderId', currentUserId)
        ..set('senderName', currentUserName)
        ..set('content', prompt)
        ..set('isRead', false);

      final response = await message.save();
      if (!response.success) {
        yield 'Failed to send message. Please try again.';
        return;
      }

      // Yield empty string — we don't generate a bot reply.
      // The other party's reply comes via LiveQuery and is added
      // to history as an "llm" message automatically.
      yield '';
    } catch (e) {
      yield 'Error: ${e.toString()}';
    }
  }

  /// Not used for person-to-person chat, but required by the interface.
  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    // Delegate to sendMessageStream for consistency
    yield* sendMessageStream(prompt, attachments: attachments);
  }

  /// Clean up LiveQuery subscription.
  void dispose() {
    if (_liveQuery != null && _messageSubscription != null) {
      _liveQuery!.client.unSubscribe(_messageSubscription!);
    }
  }
}
