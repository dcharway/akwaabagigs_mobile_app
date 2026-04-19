import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
import '../models/conversation.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';
import 'live_chat_screen.dart';
import 'login_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen> {
  List<_ChatEntry> _chats = [];
  bool _isLoading = true;
  String? _error;
  LiveQuery? _liveQuery;
  Subscription? _messageSubscription;
  Subscription? _conversationSubscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeLiveQuery();
    // Register for conversation-change events from the global provider so
    // that conversations created elsewhere (e.g. LiveChatScreen) trigger a
    // reload even though this widget lives inside an IndexedStack.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notif = context.read<NotificationsProvider>();
      notif.onConversationChanged = _onConversationChanged;
    });
  }

  @override
  void dispose() {
    _unsubscribeLiveQuery();
    // Deregister callback to avoid calling setState on a disposed widget.
    try {
      final notif = context.read<NotificationsProvider>();
      if (notif.onConversationChanged == _onConversationChanged) {
        notif.onConversationChanged = null;
      }
    } catch (_) {}
    super.dispose();
  }

  void _onConversationChanged() {
    if (mounted) _loadChats();
  }

  /// Called by [HomeScreen] when the chat tab becomes visible so the
  /// list is always up-to-date even though IndexedStack keeps the
  /// widget alive.
  void reloadIfNeeded() => _loadChats();

  /// Load conversations and fetch the last message for each.
  Future<void> _loadChats() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final conversations = await ApiService.getConversations();
      final currentUserId = auth.user?.id ?? '';
      final entries = <_ChatEntry>[];

      for (final conv in conversations) {
        final otherName = conv.otherPartyName(currentUserId);
        entries.add(_ChatEntry(
          conversation: conv,
          otherPartyName: otherName,
          chatRoomId: conv.id, // Use Conversation objectId as unique key
          lastMessageText: conv.lastMessageText,
          lastMessageSenderId: conv.lastMessageSenderId,
          lastMessageTime: conv.lastMessageAt ?? conv.createdAt,
          currentUserId: currentUserId,
        ));
      }

      // Deduplicate by chatRoomId (keep the one with latest message)
      final seen = <String, _ChatEntry>{};
      for (final entry in entries) {
        final existing = seen[entry.chatRoomId];
        if (existing == null ||
            entry.lastMessageTime.isAfter(existing.lastMessageTime)) {
          seen[entry.chatRoomId] = entry;
        }
      }

      final unique = seen.values.toList()
        ..sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

      if (mounted) {
        setState(() {
          _chats = unique;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  /// LiveQuery on Message + Conversation classes to refresh in real-time.
  Future<void> _subscribeLiveQuery() async {
    try {
      _liveQuery = LiveQuery();

      final msgQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass));
      _messageSubscription = await _liveQuery!.client.subscribe(msgQuery);
      _messageSubscription!.on(LiveQueryEvent.create, (_) {
        if (mounted) _loadChats();
      });

      final convQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.conversationClass));
      _conversationSubscription =
          await _liveQuery!.client.subscribe(convQuery);
      _conversationSubscription!.on(LiveQueryEvent.create, (_) {
        if (mounted) _loadChats();
      });
      _conversationSubscription!.on(LiveQueryEvent.update, (_) {
        if (mounted) _loadChats();
      });
    } catch (_) {}
  }

  void _unsubscribeLiveQuery() {
    if (_liveQuery != null) {
      if (_messageSubscription != null) {
        _liveQuery!.client.unSubscribe(_messageSubscription!);
      }
      if (_conversationSubscription != null) {
        _liveQuery!.client.unSubscribe(_conversationSubscription!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated) {
      return _buildSignInPrompt(context);
    }

    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.amber600));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppColors.red500),
            const SizedBox(height: 16),
            const Text('Failed to load chats'),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loadChats,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 64, color: AppColors.gray400),
              const SizedBox(height: 16),
              const Text('No conversations yet',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text(
                'Apply for a gig and place a bid.\nChat unlocks when the poster accepts.',
                style: TextStyle(color: AppColors.gray500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.amber600,
      onRefresh: _loadChats,
      child: ListView.builder(
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          return _buildChatTile(_chats[index]);
        },
      ),
    );
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: AppColors.gray400),
            const SizedBox(height: 16),
            const Text('Sign in to view messages',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text(
              'Connect with gig posters and seekers',
              style: TextStyle(color: AppColors.gray500),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () async {
                final loggedIn = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
                if (loggedIn == true) _loadChats();
              },
              icon: const Icon(Icons.login),
              label: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(_ChatEntry chat) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final now = DateTime.now();
    final isToday = chat.lastMessageTime.day == now.day &&
        chat.lastMessageTime.month == now.month &&
        chat.lastMessageTime.year == now.year;
    final hasUnread = chat.hasNewMessage;

    // Build last message preview
    String preview;
    if (chat.lastMessageText != null) {
      final isMyMessage = chat.lastMessageSenderId == chat.currentUserId;
      preview = isMyMessage
          ? 'You: ${chat.lastMessageText}'
          : chat.lastMessageText!;
    } else {
      preview = 'Tap to start chatting';
    }

    return Container(
      decoration: BoxDecoration(
        color: hasUnread ? AppColors.amber50 : Colors.white,
        border: const Border(bottom: BorderSide(color: AppColors.gray200)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor:
              hasUnread ? AppColors.amber500 : AppColors.gray200,
          child: Text(
            chat.otherPartyName.isNotEmpty
                ? chat.otherPartyName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: hasUnread ? Colors.white : AppColors.gray700,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                chat.otherPartyName,
                style: TextStyle(
                  fontWeight:
                      hasUnread ? FontWeight.bold : FontWeight.w600,
                  color: AppColors.gray900,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              isToday
                  ? timeFormat.format(chat.lastMessageTime)
                  : dateFormat.format(chat.lastMessageTime),
              style: TextStyle(
                fontSize: 12,
                color: hasUnread ? AppColors.amber700 : AppColors.gray500,
                fontWeight:
                    hasUnread ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              // Job tag
              if (chat.conversation.jobTitle != null &&
                  chat.conversation.jobTitle!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.amber400.withAlpha(40),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    chat.conversation.jobTitle!,
                    style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.amber700,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Last message preview
              Expanded(
                child: Text(
                  preview,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasUnread
                        ? AppColors.gray800
                        : AppColors.gray500,
                    fontWeight:
                        hasUnread ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Unread badge
              if (hasUnread)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.amber600,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LiveChatScreen(
                jobId: chat.conversation.jobId ?? '',
                jobTitle: chat.conversation.jobTitle ?? '',
                otherPartyName: chat.otherPartyName,
                conversationId: chat.conversation.id,
              ),
            ),
          ).then((_) => _loadChats());
        },
      ),
    );
  }
}

/// Internal model combining conversation data with last-message metadata.
class _ChatEntry {
  final Conversation conversation;
  final String otherPartyName;
  final String chatRoomId;
  final String? lastMessageText;
  final String? lastMessageSenderId;
  final DateTime lastMessageTime;
  final String currentUserId;

  _ChatEntry({
    required this.conversation,
    required this.otherPartyName,
    required this.chatRoomId,
    this.lastMessageText,
    this.lastMessageSenderId,
    required this.lastMessageTime,
    required this.currentUserId,
  });

  /// Whether the last message was sent by the other party (potential unread).
  bool get hasNewMessage =>
      lastMessageSenderId != null && lastMessageSenderId != currentUserId;
}
