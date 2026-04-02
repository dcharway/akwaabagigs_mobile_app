import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

/// Private, asynchronous real-time chat between gig seeker and gig poster.
///
/// Access control: Only participants in the Conversation can see/send messages.
/// Messages are stored with the Conversation's objectId as the foreign key.
/// LiveQuery on the chatRoomId channel provides instant delivery.
class LiveChatScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;
  final String otherPartyName;
  /// If known, pass the Conversation objectId directly to skip lookup.
  final String? conversationId;

  const LiveChatScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
    required this.otherPartyName,
    this.conversationId,
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
  final Map<String, String> _localToServerIds = {};
  final Set<String> _failedMessageIds = {};

  bool _isLoading = true;
  bool _hasMoreHistory = true;
  bool _isLoadingMore = false;
  bool _showScrollToBottom = false;
  String _currentUserId = '';

  /// The Conversation's objectId — used as the foreign key on every message.
  String? _resolvedConversationId;

  /// The LiveQuery channel ID — always 'chat_{jobId}'.
  String get _chatRoomId => 'chat_${widget.jobId}';

  LiveQuery? _liveQuery;
  Subscription? _messageSubscription;
  Timer? _reconnectTimer;

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _currentUserId = context.read<AuthProvider>().user?.id ?? '';
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _resolveConversationAndLoad();
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshNewMessages();
      _setupLiveQuery();
    } else if (state == AppLifecycleState.paused) {
      _unsubscribeLiveQuery();
    }
  }

  /// Resolve the Conversation objectId, then load messages and start LiveQuery.
  Future<void> _resolveConversationAndLoad() async {
    if (widget.conversationId != null) {
      _resolvedConversationId = widget.conversationId;
    } else {
      // Find the conversation by participants + jobId
      try {
        final conversations = await ApiService.getConversations();
        final match = conversations.where((c) =>
            c.jobId == widget.jobId &&
            c.hasParticipant(_currentUserId)).firstOrNull;
        _resolvedConversationId = match?.id;
      } catch (_) {}
    }

    // If still no conversation, create one will happen on first send
    _loadMessages();
    _setupLiveQuery();
  }

  void _onScroll() {
    final atBottom = _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 80;
    if (_showScrollToBottom == atBottom) {
      setState(() => _showScrollToBottom = !atBottom);
    }
    if (_scrollController.hasClients &&
        _scrollController.position.pixels <= 50 &&
        _hasMoreHistory &&
        !_isLoadingMore) {
      _loadOlderMessages();
    }
  }

  // ============ MESSAGE LOADING ============

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);
    try {
      // Query by chatRoomId (the channel) — this matches how messages are saved
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
          final prevHeight = _scrollController.position.maxScrollExtent;
          setState(() => _messages.insertAll(0, older));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final newHeight = _scrollController.position.maxScrollExtent;
            _scrollController
                .jumpTo(_scrollController.offset + (newHeight - prevHeight));
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingMore = false);
  }

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
          if (!_messages.any((m) => m.objectId == msg.objectId)) {
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

      _messageSubscription!.on(LiveQueryEvent.create, (value) {
        if (!mounted) return;
        final serverId = value.objectId;
        // Deduplicate: check if this is our own optimistic message echoed back
        final isOwnEcho = _localToServerIds.values.contains(serverId);
        if (isOwnEcho) return;
        if (!_messages.any((m) => m.objectId == serverId)) {
          setState(() => _messages.add(value));
          _markSingleMessageRead(value);
          if (!_showScrollToBottom) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _scrollToBottom());
          }
        }
      });

      _messageSubscription!.on(LiveQueryEvent.update, (value) {
        if (!mounted) return;
        final index =
            _messages.indexWhere((m) => m.objectId == value.objectId);
        if (index >= 0) setState(() => _messages[index] = value);
      });

      _reconnectTimer?.cancel();
      _reconnectTimer =
          Timer.periodic(const Duration(seconds: 30), (_) {
        _refreshNewMessages();
      });
    } catch (e) {
      debugPrint('LiveQuery setup failed: $e');
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

  void _markMessagesAsRead() {
    for (final msg in _messages) {
      _markSingleMessageRead(msg);
    }
  }

  void _markSingleMessageRead(ParseObject msg) async {
    final msgId = msg.objectId ?? '';
    if (msgId.startsWith('_local_')) return;
    if (msg.get<String>('senderId') == _currentUserId) return;
    if (msg.get<bool>('isRead') == true) return;

    try {
      final update = ParseObject(Back4AppConfig.messageClass)
        ..objectId = msgId
        ..set('isRead', true);
      // Participants-only write: let Cloud Code handle ACL
      final acl = ParseACL()
        ..setPublicReadAccess(allowed: true)
        ..setPublicWriteAccess(allowed: true);
      update.setACL(acl);
      await update.save();
    } catch (_) {}
  }

  // ============ SEND (Optimistic UI) ============

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final user = await ParseUser.currentUser() as ParseUser?;
    if (user == null) return;

    final senderName =
        '${user.get<String>('firstName') ?? ''} ${user.get<String>('lastName') ?? ''}'
            .trim();

    // 1. Show optimistic message IMMEDIATELY
    final localId = '_local_${DateTime.now().microsecondsSinceEpoch}';
    final localMsg = ParseObject(Back4AppConfig.messageClass)
      ..set('chatRoomId', _chatRoomId)
      ..set('conversationId', _resolvedConversationId ?? _chatRoomId)
      ..set('senderId', user.objectId)
      ..set('senderName', senderName)
      ..set('content', text)
      ..set('isRead', false);
    localMsg.objectId = localId;

    setState(() => _messages.add(localMsg));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // 2. Save to Back4App
    try {
      final serverMsg = ParseObject(Back4AppConfig.messageClass)
        ..set('chatRoomId', _chatRoomId)
        ..set('conversationId', _resolvedConversationId ?? _chatRoomId)
        ..set('senderId', user.objectId)
        ..set('senderName', senderName)
        ..set('content', text)
        ..set('isRead', false);

      final acl = ParseACL()
        ..setPublicReadAccess(allowed: true)
        ..setWriteAccess(userId: user.objectId!, allowed: true);
      serverMsg.setACL(acl);

      final response = await serverMsg.save();

      if (response.success && response.result != null) {
        final saved = response.result as ParseObject;
        if (mounted) {
          _localToServerIds[localId] = saved.objectId!;
          setState(() {
            final idx = _messages.indexWhere((m) => m.objectId == localId);
            if (idx >= 0) _messages[idx] = saved;
          });
        }

        // 3. Update the Conversation record
        _updateConversationAfterSend(text, user.objectId!);
      } else {
        debugPrint(
            'Message save failed: ${response.error?.code} ${response.error?.message}');
        _markAsFailed(localId);
      }
    } catch (e) {
      debugPrint('Message save exception: $e');
      _markAsFailed(localId);
    }
  }

  /// Update the parent Conversation with last message info.
  Future<void> _updateConversationAfterSend(
      String text, String senderId) async {
    try {
      String? convId = _resolvedConversationId;

      // If we don't have a resolved ID, find it
      if (convId == null || convId.isEmpty) {
        final convQuery = QueryBuilder<ParseObject>(
            ParseObject(Back4AppConfig.conversationClass))
          ..whereEqualTo('participants', _currentUserId)
          ..whereEqualTo('jobId', widget.jobId)
          ..setLimit(1);
        final convResponse = await convQuery.query();
        if (convResponse.success &&
            convResponse.results != null &&
            convResponse.results!.isNotEmpty) {
          convId = convResponse.results!.first.objectId;
          _resolvedConversationId = convId;
        }
      }

      if (convId != null && convId.isNotEmpty) {
        final conv = ParseObject(Back4AppConfig.conversationClass)
          ..objectId = convId
          ..set('lastMessageText', text)
          ..set('lastMessageSenderId', senderId)
          ..set('lastMessageAt', DateTime.now().toIso8601String());
        conv.setIncrement('messageCount', 1);

        final acl = ParseACL()
          ..setPublicReadAccess(allowed: true)
          ..setPublicWriteAccess(allowed: true);
        conv.setACL(acl);

        await conv.save();
      }
    } catch (_) {
      // Non-critical — chat list preview may be stale
    }
  }

  void _markAsFailed(String localId) {
    if (mounted) setState(() => _failedMessageIds.add(localId));
  }

  Future<void> _retryMessage(String localId) async {
    final idx = _messages.indexWhere((m) => m.objectId == localId);
    if (idx < 0) return;
    final text = _messages[idx].get<String>('content') ?? '';
    setState(() {
      _messages.removeAt(idx);
      _failedMessageIds.remove(localId);
    });
    _controller.text = text;
    _sendMessage();
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
    final currentUserId = _currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherPartyName),
            Text('Re: ${widget.jobTitle}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0x194CAF50),
            child: const Row(
              children: [
                Icon(Icons.check_circle, size: 16, color: Color(0xFF4CAF50)),
                SizedBox(width: 8),
                Text('Bid agreed — chat active',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : Stack(
                    children: [
                      _messages.isEmpty
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 16),
                              itemCount:
                                  _messages.length + (_isLoadingMore ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (_isLoadingMore && index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Center(
                                      child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.gray400)),
                                    ),
                                  );
                                }
                                final msgIndex =
                                    _isLoadingMore ? index - 1 : index;
                                final msg = _messages[msgIndex];
                                final isMe =
                                    msg.get<String>('senderId') ==
                                        currentUserId;
                                Widget? dateSeparator;
                                if (msgIndex == 0 ||
                                    _shouldShowDate(msgIndex)) {
                                  dateSeparator = _buildDateSeparator(
                                      msg.createdAt ?? DateTime.now());
                                }
                                return Column(
                                  children: [
                                    if (dateSeparator != null) dateSeparator,
                                    _buildBubble(msg, isMe),
                                  ],
                                );
                              },
                            ),
                      if (_showScrollToBottom)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.small(
                            backgroundColor: const Color(0xFF4CAF50),
                            onPressed: () => _scrollToBottom(animated: true),
                            child: const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white),
                          ),
                        ),
                    ],
                  ),
          ),
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
                      onPressed: _sendMessage,
                      icon: const Icon(Icons.send, color: Colors.white),
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
    final msgId = msg.objectId ?? '';
    final isLocal = msgId.startsWith('_local_');
    final isFailed = _failedMessageIds.contains(msgId);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? isFailed
                  ? const Color(0xFFE57373)
                  : isLocal
                      ? const Color(0xFF81C784)
                      : const Color(0xFF4CAF50)
              : AppColors.gray100,
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
                        color: isMe ? Colors.white70 : AppColors.gray500)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (isFailed)
                    GestureDetector(
                      onTap: () => _retryMessage(msgId),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 14, color: Colors.white),
                          SizedBox(width: 2),
                          Text('Retry',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    )
                  else if (isLocal)
                    const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                            strokeWidth: 1.5, color: Colors.white70))
                  else
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 14,
                      color: isRead ? Colors.white : Colors.white70,
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
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
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
            color: Colors.greenAccent, shape: BoxShape.circle),
      ),
    );
  }
}
