import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
import '../providers/auth_provider.dart';
import '../utils/colors.dart';

/// Real-time person-to-person chat between gig seeker and gig poster.
///
/// Uses Back4App Parse LiveQuery for instant message delivery.
/// Only accessible after the poster accepts a bid (Job.chatEnabled == true).
class LiveChatScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String otherPartyName;

  const LiveChatScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.otherPartyName,
  });

  @override
  State<LiveChatScreen> createState() => _LiveChatScreenState();
}

class _LiveChatScreenState extends State<LiveChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ParseObject> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  LiveQuery? _liveQuery;
  Subscription? _messageSubscription;

  String get _chatRoomId => 'chat_${widget.jobId}';

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupLiveQuery();
  }

  @override
  void dispose() {
    _unsubscribeLiveQuery();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', _chatRoomId)
        ..orderByAscending('createdAt');

      final response = await query.query();
      if (response.success && response.results != null) {
        _messages = response.results!.cast<ParseObject>();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _setupLiveQuery() async {
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', _chatRoomId);

      _messageSubscription = await _liveQuery!.client.subscribe(query);

      _messageSubscription!.on(LiveQueryEvent.create, (value) {
        if (mounted) {
          final exists = _messages.any((m) => m.objectId == value.objectId);
          if (!exists) {
            setState(() => _messages.add(value));
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      });
    } catch (e) {
      debugPrint('LiveQuery setup failed: $e');
    }
  }

  void _unsubscribeLiveQuery() {
    if (_liveQuery != null && _messageSubscription != null) {
      _liveQuery!.client.unSubscribe(_messageSubscription!);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();

    try {
      final user = await ParseUser.currentUser() as ParseUser?;
      if (user == null) throw Exception('Not authenticated');

      final senderName =
          '${user.get<String>('firstName') ?? ''} ${user.get<String>('lastName') ?? ''}'
              .trim();

      final message = ParseObject(Back4AppConfig.messageClass)
        ..set('chatRoomId', _chatRoomId)
        ..set('conversationId', _chatRoomId)
        ..set('senderId', user.objectId)
        ..set('senderName', senderName)
        ..set('content', text)
        ..set('isRead', false);

      final response = await message.save();
      if (response.success && response.result != null) {
        final newMsg = response.result as ParseObject;
        final exists = _messages.any((m) => m.objectId == newMsg.objectId);
        if (!exists) {
          setState(() => _messages.add(newMsg));
        }
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    }

    if (mounted) setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentUserId = authProvider.user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName),
            Text(
              'Re: ${widget.jobTitle}',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          // Live indicator
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(),
                SizedBox(width: 5),
                Text('Live',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Bid-agreed banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x194CAF50),
            child: const Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text(
                  'Bid agreed — chat active',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ),
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                size: 64, color: AppColors.gray400),
                            const SizedBox(height: 16),
                            const Text('No messages yet',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            const Text('Start the conversation!',
                                style: TextStyle(
                                    color: AppColors.gray500, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe =
                              msg.get<String>('senderId') == currentUserId;
                          return _buildBubble(msg, isMe);
                        },
                      ),
          ),
          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.gray200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: AppColors.gray100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ParseObject msg, bool isMe) {
    final timeFormat = DateFormat('h:mm a');
    final content = msg.get<String>('content') ?? '';
    final senderName = msg.get<String>('senderName') ?? '';
    final createdAt = msg.createdAt ?? DateTime.now();

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF4CAF50) : AppColors.gray100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray600,
                  ),
                ),
              ),
            Text(
              content,
              style: TextStyle(
                color: isMe ? Colors.white : AppColors.gray900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeFormat.format(createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMe ? Colors.white70 : AppColors.gray500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing green dot for live indicator.
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
