import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/conversation.dart';
import '../models/gig_seeker.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/colors.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherPartyName;
  final String? jobTitle;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherPartyName,
    this.jobTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _canChat = true;
  bool _isCheckingChatAccess = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _checkChatAccess();
    // Poll for new messages every 10 seconds for async experience
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshMessages();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkChatAccess() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.user?.id;

      // Check if the user is a poster for this conversation
      // Posters always have chat access
      final conversations = await ApiService.getConversations();
      final conversation = conversations
          .where((c) => c.id == widget.conversationId)
          .firstOrNull;

      if (conversation != null && currentUserId == conversation.posterId) {
        // User is the poster - always allowed
        if (mounted) {
          setState(() {
            _canChat = true;
            _isCheckingChatAccess = false;
          });
        }
        return;
      }

      // User is a seeker - check admin-controlled canChat field
      final seekerProfile = await ApiService.getGigSeekerProfile();
      if (mounted) {
        setState(() {
          _canChat = seekerProfile?.canChat ?? false;
          _isCheckingChatAccess = false;
        });
      }
    } catch (e) {
      // On error, allow chat (don't block on network issues)
      if (mounted) {
        setState(() {
          _canChat = true;
          _isCheckingChatAccess = false;
        });
      }
    }
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      _messages = await ApiService.getMessages(widget.conversationId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load messages: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  /// Silently refresh messages without showing loading indicator
  Future<void> _refreshMessages() async {
    try {
      final newMessages =
          await ApiService.getMessages(widget.conversationId);
      if (mounted && newMessages.length != _messages.length) {
        final wasAtBottom = _scrollController.hasClients &&
            _scrollController.position.pixels >=
                _scrollController.position.maxScrollExtent - 50;
        setState(() {
          _messages = newMessages;
        });
        if (wasAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (_) {
      // Silent refresh - don't show errors
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
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final message = await ApiService.sendMessage(
        conversationId: widget.conversationId,
        content: content,
      );
      setState(() {
        _messages.add(message);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      _messageController.text = content;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }

  Future<void> _reportMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Message'),
        content: const Text(
            'Are you sure you want to report this message for review?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.reportMessage(message.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message reported for review'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
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
            if (widget.jobTitle != null && widget.jobTitle!.isNotEmpty)
              Text(
                'Re: ${widget.jobTitle}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimary
                          .withOpacity(0.7),
                    ),
              ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh messages',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color:
                                  Theme.of(context).colorScheme.outline,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _canChat
                                  ? 'Start the conversation!'
                                  : 'Waiting for admin to enable chat access.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .outline,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMe =
                              message.senderId == currentUserId;
                          return _buildMessageBubble(
                              context, message, isMe);
                        },
                      ),
          ),
          // Chat input or disabled banner
          if (!_isCheckingChatAccess && !_canChat)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.amber50,
                border: Border(
                  top: BorderSide(
                    color: AppColors.amber400.withOpacity(0.5),
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 20, color: AppColors.amber700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chat disabled. An admin must verify your account to enable messaging.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.amber900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color:
                        Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      BuildContext context, Message message, bool isMe) {
    final timeFormat = DateFormat('h:mm a');

    return GestureDetector(
      onLongPress: isMe ? null : () => _reportMessage(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isMe
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
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
              if (message.flagged != null && message.censored != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Content moderated',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.orange),
                  ),
                ),
              // File attachment
              if (message.fileUrl != null &&
                  message.fileUrl!.isNotEmpty) ...[
                GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(message.fileUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Colors.white.withOpacity(0.15)
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.attach_file,
                          size: 16,
                          color: isMe
                              ? Theme.of(context)
                                  .colorScheme
                                  .onPrimary
                              : Theme.of(context)
                                  .colorScheme
                                  .primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            message.fileName ?? 'File',
                            style: TextStyle(
                              color: isMe
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimary
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary,
                              decoration:
                                  TextDecoration.underline,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              Text(
                message.displayContent,
                style: TextStyle(
                  color: isMe
                      ? Theme.of(context).colorScheme.onPrimary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timeFormat.format(message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isMe
                          ? Theme.of(context)
                              .colorScheme
                              .onPrimary
                              .withOpacity(0.7)
                          : Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
