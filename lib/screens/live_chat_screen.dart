import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/back4app_chat_provider.dart';
import '../utils/colors.dart';

/// Real-time chat screen built on the Flutter AI Toolkit's [LlmChatView].
///
/// Uses [Back4AppChatProvider] as a custom [LlmProvider] that bridges
/// the toolkit's polished chat UI to Back4App Parse messaging with
/// LiveQuery for instant delivery.
///
/// Activation: This screen is only reachable AFTER the gig poster
/// accepts the seeker's bid (Job.chatEnabled == true), enforced by
/// [AsyncChatButton] on the job details screen.
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
  Back4AppChatProvider? _chatProvider;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initProvider();
  }

  Future<void> _initProvider() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.user?.id ?? '';
    final userName = auth.user?.fullName ?? 'User';

    _chatProvider = Back4AppChatProvider(
      chatRoomId: 'chat_${widget.jobId}',
      currentUserId: userId,
      currentUserName: userName,
      otherPartyName: widget.otherPartyName,
    );

    if (mounted) setState(() => _isInitializing = false);
  }

  @override
  void dispose() {
    _chatProvider?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        actions: const [
          Padding(
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
          // Chat view
          Expanded(
            child: _isInitializing || _chatProvider == null
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF4CAF50)))
                : LlmChatView(
                    provider: _chatProvider!,
                    welcomeMessage:
                        'Chat with ${widget.otherPartyName} about "${widget.jobTitle}". '
                        'Messages are delivered in real-time.',
                    style: LlmChatViewStyle(
                      backgroundColor: Colors.white,
                      submitButtonStyle: ActionButtonStyle(
                        icon: Icons.send,
                        iconColor: Colors.white,
                        iconDecoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      userMessageStyle: UserMessageStyle(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: const Radius.circular(16),
                            bottomRight: const Radius.circular(4),
                          ),
                        ),
                        textStyle:
                            const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                      llmMessageStyle: LlmMessageStyle(
                        decoration: BoxDecoration(
                          color: AppColors.gray100,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: const Radius.circular(4),
                            bottomRight: const Radius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
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
