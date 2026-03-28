import 'package:flutter/foundation.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';

/// Custom [LlmProvider] for the Akwaaba Gigs customer support AI chatbot.
///
/// Uses Back4App Cloud Functions to process support queries. The Cloud
/// Function can be connected to any AI backend (Gemini, GPT, Claude, etc.)
/// or return rule-based responses for common questions.
class SupportChatProvider extends ChangeNotifier implements LlmProvider {
  List<ChatMessage> _history = [];
  final String? userId;
  final String? userEmail;

  SupportChatProvider({this.userId, this.userEmail});

  @override
  List<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> newHistory) {
    _history = newHistory.toList();
    notifyListeners();
  }

  @override
  Stream<String> sendMessageStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    try {
      // Try Cloud Function first (can be wired to any AI backend)
      final response =
          await ParseCloudFunction('customerSupportChat').execute(
        parameters: {
          'message': prompt,
          'userId': userId,
          'email': userEmail,
        },
      );

      if (response.success && response.result != null) {
        final reply = response.result is Map
            ? (response.result['reply'] ?? response.result.toString())
            : response.result.toString();
        yield reply;
        return;
      }
    } catch (_) {
      // Cloud function not deployed — use local FAQ
    }

    // Local rule-based fallback for common questions
    yield _getLocalResponse(prompt);
  }

  @override
  Stream<String> generateStream(
    String prompt, {
    Iterable<Attachment> attachments = const [],
  }) async* {
    yield* sendMessageStream(prompt, attachments: attachments);
  }

  String _getLocalResponse(String prompt) {
    final q = prompt.toLowerCase();

    if (q.contains('post') && q.contains('gig')) {
      return 'To post a gig:\n\n'
          '1. Go to the **Gigs** tab\n'
          '2. Tap the **Post Gig** button\n'
          '3. Fill in the details (title, location, pay, etc.)\n'
          '4. Complete the payment (GH₵117.50 including VAT)\n'
          '5. Your gig goes live!\n\n'
          'Need help with something else?';
    }

    if (q.contains('bid') || q.contains('apply')) {
      return 'To apply and bid on a gig:\n\n'
          '1. Browse gigs in the **Gigs** tab\n'
          '2. Tap a gig → **Apply & Bid**\n'
          '3. Fill in your details\n'
          '4. Choose a bid amount (50 or 100 GH₵ increments)\n'
          '5. Wait for the poster to accept your bid\n'
          '6. Chat unlocks once your bid is accepted!\n\n'
          'Free users get 5 applications per month.';
    }

    if (q.contains('chat') || q.contains('message')) {
      return 'Chat is activated after the gig poster accepts your bid:\n\n'
          '1. Apply for a gig and place your bid\n'
          '2. The poster reviews and approves your bid\n'
          '3. The **green chat button** activates\n'
          '4. Messages are delivered in real-time!\n\n'
          'Both parties must agree on the bid amount first.';
    }

    if (q.contains('payment') || q.contains('momo') || q.contains('pay')) {
      return 'We accept the following payment methods:\n\n'
          '• **Mobile Money** — MTN, Vodafone, AirtelTigo\n'
          '• **Cash** — Pay at authorized agents\n'
          '• **Bank Transfer** — GCB Bank\n\n'
          'Gig posting costs GH₵117.50 (GH₵100 + 15% VAT + 2.5% platform fee).';
    }

    if (q.contains('verify') || q.contains('kyc') || q.contains('id')) {
      return 'To verify your identity:\n\n'
          '1. Go to **Profile** → **Verify your ID**\n'
          '2. Select your document type (Ghana Card, Voter ID, etc.)\n'
          '3. Take a selfie and scan your ID\n'
          '4. AI verification checks your identity\n'
          '5. You get a **Verified** badge!\n\n'
          'Verified users get access to chat and higher visibility.';
    }

    if (q.contains('escrow') || q.contains('fund')) {
      return 'Escrow protects both parties:\n\n'
          '1. Poster funds escrow via MoMo\n'
          '2. Akwaaba holds the funds securely\n'
          '3. Worker completes the job\n'
          '4. Poster releases payment to worker\n'
          '5. A 5% service fee is deducted\n\n'
          'Go to **My Gigs** → select a gig → **Escrow** to get started.';
    }

    if (q.contains('store') || q.contains('buy') || q.contains('product')) {
      return 'The **Akwaaba Store** lets you buy products:\n\n'
          '1. Go to the **Store** tab\n'
          '2. Browse products by category\n'
          '3. Tap a product for details\n'
          '4. Enter your MoMo number and delivery address\n'
          '5. Complete payment\n\n'
          'Products are curated by verified admins.';
    }

    if (q.contains('password') || q.contains('reset') || q.contains('forgot')) {
      return 'To reset your password:\n\n'
          '• **From login screen**: Tap "Forgot Password?" → enter your email\n'
          '• **From profile**: Settings → **Reset Password via Email**\n'
          '• **Change password**: Settings → **Change Password**\n\n'
          'A reset link will be sent to your registered email.';
    }

    if (q.contains('contact') || q.contains('support') || q.contains('help')) {
      return 'You can reach us at:\n\n'
          '• **Email**: support@akwaabagigs.com\n'
          '• **In-app**: This chat is available 24/7\n\n'
          'For urgent issues, please email us directly.';
    }

    if (q.contains('hello') || q.contains('hi') || q.contains('hey')) {
      return 'Hello! 👋 Welcome to Akwaaba Gigs support.\n\n'
          'I can help with:\n'
          '• Posting gigs\n'
          '• Applying & bidding\n'
          '• Payments & MoMo\n'
          '• Identity verification\n'
          '• Escrow & payouts\n'
          '• Password & account\n'
          '• Store purchases\n\n'
          'What do you need help with?';
    }

    return 'I can help you with:\n\n'
        '• **Post a gig** — How to create and pay for a gig listing\n'
        '• **Apply & bid** — How to apply for gigs and place bids\n'
        '• **Chat** — When and how chat is activated\n'
        '• **Payments** — MoMo, cash, bank transfer options\n'
        '• **Verification** — How to verify your ID\n'
        '• **Escrow** — How escrow payments work\n'
        '• **Store** — How to buy products\n'
        '• **Password** — How to reset your password\n'
        '• **Contact support** — How to reach us\n\n'
        'Try asking about any of these topics!';
  }
}
