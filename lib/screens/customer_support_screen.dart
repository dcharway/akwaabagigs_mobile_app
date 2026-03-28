import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/support_chat_provider.dart';
import '../utils/colors.dart';

/// AI-powered customer support chatbot using Flutter AI Toolkit.
///
/// This is the ONLY screen that uses flutter_ai_toolkit. All person-to-person
/// chat between gig seekers and gig posters uses the Back4App LiveQuery-based
/// LiveChatScreen instead.
class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  late SupportChatProvider _provider;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _provider = SupportChatProvider(
      userId: auth.user?.id,
      userEmail: auth.user?.email,
    );
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer Support'),
            Text(
              'AI-powered help — available 24/7',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
        actions: [
          // AI badge
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.smart_toy, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('AI',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
      body: LlmChatView(
        provider: _provider,
        welcomeMessage:
            'Hello! 👋 I\'m the Akwaaba Gigs support assistant.\n\n'
            'I can help you with posting gigs, applying, payments, '
            'verification, escrow, and more.\n\n'
            'What do you need help with?',
        style: LlmChatViewStyle(
          backgroundColor: Colors.white,
          submitButtonStyle: ActionButtonStyle(
            icon: Icons.send,
            iconColor: Colors.white,
            iconDecoration: const BoxDecoration(
              color: AppColors.amber600,
              shape: BoxShape.circle,
            ),
          ),
          userMessageStyle: UserMessageStyle(
            decoration: BoxDecoration(
              color: AppColors.amber600,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(4),
              ),
            ),
            textStyle: const TextStyle(color: Colors.white, fontSize: 15),
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
    );
  }
}
