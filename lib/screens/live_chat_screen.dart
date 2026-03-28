import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
import '../providers/auth_provider.dart';
import '../utils/colors.dart';

/// Asynchronous real-time chat between gig seeker and gig poster.
///
/// Full chat history is loaded from Back4App on open. New messages arrive
/// instantly via LiveQuery. Either party can send at any time — the other
/// sees the message when they next open the chat or immediately if online.
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

class _LiveChatScreenState extends State<LiveChatScreen>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  List<ParseObject> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasMoreHistory = true;
  bool _isLoadingMore = false;
  bool _showScrollToBottom = false;

  LiveQuery? _liveQuery;
  Subscription? _messageSubscription;
  Timer? _reconnectTimer;

  static const int _pageSize = 50;
  String get _chatRoomId => 'chat_${widget.jobId}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _loadMessages();
    _setupLiveQuery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _unsubscribeLiveQuery();
    _controller.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  /// Reconnect LiveQuery when app comes back to foreground.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNewMessages();
      _setupLiveQuery();
    } else if (state == AppLifecycleState.paused) {
      _unsubscribeLiveQuery();
    }
  }

  void _onScroll() {
    // Show "scroll to bottom" button when not at bottom
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80;
    if (_showScrollToBottom == atBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }

    // Load older messages when scrolled to top
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 50 &&
        _hasMoreHistory &&
        !_isLoadingMore) {
      _loadOlderMessages();
    }
  }

  // ============ MESSAGE LOADING ============

  /// Initial load: fetch the most recent messages.
  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', _chatRoomId)
        ..orderByDescending('createdAt')
        ..setLimit(_pageSize);

      final response = await query.query();
      if (response.success && response.results != null) {
        _messages = response.results!.cast<ParseObject>().reversed.toList();
        _hasMoreHistory = response.results!.length >= _pageSize;
      }
      _markMessagesAsRead();
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

  /// Pull-to-load older messages (pagination).
  Future<void> _loadOlderMessages() async {
    if (_messages.isEmpty || !_hasMoreHistory) return;
    setState(() => _isLoadingMore = true);

    try {
      final oldest = _messages.first;
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', _chatRoomId)
        ..whereLessThan('createdAt', oldest.createdAt!.toIso8601String())
        ..orderByDescending('createdAt')
        ..setLimit(_pageSize);

      final response = await query.query();
      if (response.success && response.results != null) {
        final older = response.results!.cast<ParseObject>().reversed.toList();
        _hasMoreHistory = response.results!.length >= _pageSize;
        if (older.isNotEmpty) {
          // Preserve scroll position when prepending
          final prevHeight = _scrollController.position.maxScrollExtent;
          setState(() => _messages.insertAll(0, older));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newHeight = _scrollController.position.maxScrollExtent;
            _scrollController.jumpTo(
                _scrollController.offset + (newHeight - prevHeight));
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingMore = false);
  }

  /// Fetch messages newer than the latest one we have (for app resume).
  Future<void> _refreshNewMessages() async {
    if (_messages.isEmpty) {
      _loadMessages();
      return;
    }
    try {
      final newest = _messages.last;
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', _chatRoomId)
        ..whereGreaterThan('createdAt', newest.createdAt!.toIso8601String())
        ..orderByAscending('createdAt');

      final response = await query.query();
      if (response.success && response.results != null) {
        for (final obj in response.results!) {
          final msg = obj as ParseObject;
          final exists = _messages.any((m) => m.objectId == msg.objectId);
          if (!exists) {
            _messages.add(msg);
          }
        }
        _markMessagesAsRead();
        if (mounted) {
          setState(() {});
          if (!_showScrollToBottom) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      }
    } catch (_) {}
  }

  // ============ LIVE QUERY ============

  Future<void> _setupLiveQuery() async {
    _unsubscribeLiveQuery();
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass))
        ..whereEqualTo('chatRoomId', _chatRoomId);

      _messageSubscription = await _liveQuery!.client.subscribe(query);

      // New message from either party
      _messageSubscription!.on(LiveQueryEvent.create, (value) {
        if (!mounted) return;
        final exists = _messages.any((m) => m.objectId == value.objectId);
        if (!exists) {
          setState(() => _messages.add(value));
          _markSingleMessageRead(value);
          // Auto-scroll only if user is near bottom
          if (!_showScrollToBottom) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      });

      // Message updated (e.g. read receipt)
      _messageSubscription!.on(LiveQueryEvent.update, (value) {
        if (!mounted) return;
        final index =
            _messages.indexWhere((m) => m.objectId == value.objectId);
        if (index >= 0) {
          setState(() => _messages[index] = value);
        }
      });

      // Start reconnection timer as fallback
      _reconnectTimer?.cancel();
      _reconnectTimer =
          Timer.periodic(const Duration(seconds: 30), (_) {
        _refreshNewMessages();
      });
    } catch (e) {
      debugPrint('LiveQuery setup failed: $e');
      // Fallback to polling
      _reconnectTimer?.cancel();
      _reconnectTimer =
          Timer.periodic(const Duration(seconds: 5), (_) {
        _refreshNewMessages();
      });
    }
  }

  void _unsubscribeLiveQuery() {
    if (_liveQuery != null && _messageSubscription != null) {
      _liveQuery!.client.unSubscribe(_messageSubscription!);
      _messageSubscription = null;
    }
    _reconnectTimer?.cancel();
  }

  // ============ READ RECEIPTS ============

  void _markMessagesAsRead() async {
    final currentUserId =
        context.read<AuthProvider>().user?.id ?? '';
    for (final msg in _messages) {
      if (msg.get<String>('senderId') != currentUserId &&
          msg.get<bool>('isRead') != true) {
        _markSingleMessageRead(msg);
      }
    }
  }

  void _markSingleMessageRead(ParseObject msg) async {
    final currentUserId =
        context.read<AuthProvider>().user?.id ?? '';
    if (msg.get<String>('senderId') != currentUserId &&
        msg.get<bool>('isRead') != true) {
      final update = ParseObject(Back4AppConfig.messageClass)
        ..objectId = msg.objectId
        ..set('isRead', true);
      update.save(); // Fire and forget
    }
  }

  // ============ SEND ============

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

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients) {
      if (animated) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  // ============ BUILD ============

  @override
  Widget build(BuildContext context) {
    final currentUserId =
        context.watch<AuthProvider>().user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName),
            Text('Re: ${widget.jobTitle}',
                style:
                    const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(),
                SizedBox(width: 5),
                Text('Live',
                    style:
                        TextStyle(fontSize: 11, color: Colors.white70)),
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
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x194CAF50),
            child: const Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text('Bid agreed — chat active',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32))),
              ],
            ),
          ),

          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF4CAF50)))
                : Stack(
                    children: [
                      _messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.chat_bubble_outline,
                                      size: 64,
                                      color: AppColors.gray400),
                                  const SizedBox(height: 16),
                                  const Text('No messages yet',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Send a message — ${widget.otherPartyName} will see it when they open the chat.',
                                    style: const TextStyle(
                                        color: AppColors.gray500,
                                        fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 16),
                              itemCount: _messages.length +
                                  (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                // Loading spinner at top
                                if (_isLoadingMore && index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppColors
                                                    .gray400),
                                      ),
                                    ),
                                  );
                                }

                                final msgIndex = _isLoadingMore
                                    ? index - 1
                                    : index;
                                final msg = _messages[msgIndex];
                                final isMe =
                                    msg.get<String>('senderId') ==
                                        currentUserId;

                                // Date separator
                                Widget? dateSeparator;
                                if (msgIndex == 0 ||
                                    _shouldShowDate(
                                        msgIndex)) {
                                  dateSeparator =
                                      _buildDateSeparator(
                                          msg.createdAt ??
                                              DateTime.now());
                                }

                                return Column(
                                  children: [
                                    if (dateSeparator != null)
                                      dateSeparator,
                                    _buildBubble(msg, isMe),
                                  ],
                                );
                              },
                            ),

                      // Scroll-to-bottom FAB
                      if (_showScrollToBottom)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.small(
                            backgroundColor: const Color(0xFF4CAF50),
                            onPressed: () =>
                                _scrollToBottom(animated: true),
                            child: const Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white),
                          ),
                        ),
                    ],
                  ),
          ),

          // Input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: AppColors.gray200)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _inputFocusNode,
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
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(Icons.send,
                              color: Colors.white),
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

  // ============ DATE SEPARATORS ============

  bool _shouldShowDate(int index) {
    final current = _messages[index].createdAt ?? DateTime.now();
    final previous = _messages[index - 1].createdAt ?? DateTime.now();
    return current.day != previous.day ||
        current.month != previous.month ||
        current.year != previous.year;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(date.year, date.month, date.day);

    String label;
    if (msgDate == today) {
      label = 'Today';
    } else if (msgDate == yesterday) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.gray200)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500)),
          ),
          const Expanded(child: Divider(color: AppColors.gray200)),
        ],
      ),
    );
  }

  // ============ MESSAGE BUBBLE ============

  Widget _buildBubble(ParseObject msg, bool isMe) {
    final timeFormat = DateFormat('h:mm a');
    final content = msg.get<String>('content') ?? '';
    final senderName = msg.get<String>('senderName') ?? '';
    final createdAt = msg.createdAt ?? DateTime.now();
    final isRead = msg.get<bool>('isRead') ?? false;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                child: Text(senderName,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray600)),
              ),
            Text(content,
                style: TextStyle(
                    color: isMe ? Colors.white : AppColors.gray900)),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(timeFormat.format(createdAt),
                    style: TextStyle(
                        fontSize: 10,
                        color: isMe
                            ? Colors.white70
                            : AppColors.gray500)),
                // Read receipt for own messages
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead
                        ? Colors.white
                        : Colors.white70,
                  ),
                ],
              ],
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
