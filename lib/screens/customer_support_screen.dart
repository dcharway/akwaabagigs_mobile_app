import 'package:flutter/material.dart';
import '../utils/colors.dart';

class CustomerSupportScreen extends StatelessWidget {
  const CustomerSupportScreen({super.key});

  static const _faqs = [
    {
      'q': 'How do I post a gig?',
      'a': 'Go to the Gigs tab and tap "Post Gig". Fill in the details, '
          'upload images, and complete payment to publish.',
    },
    {
      'q': 'How do I apply for a gig?',
      'a': 'Browse gigs, tap one you like, and tap "Apply". You\'ll need to '
          'place a bid — chat unlocks when the poster accepts.',
    },
    {
      'q': 'How does bidding work?',
      'a': 'After applying, submit a bid in GH₵. The poster reviews bids '
          'and accepts one. Chat is enabled once a bid is agreed.',
    },
    {
      'q': 'How do I get verified?',
      'a': 'Go to Profile → Verify Identity. Select your document type '
          '(Ghana Card, Voter\'s ID, etc.) and complete the scan.',
    },
    {
      'q': 'How does payment work?',
      'a': 'Payments are processed via Mobile Money (MoMo). Escrow holds '
          'funds securely until the gig is completed.',
    },
    {
      'q': 'How do I contact the poster/seeker?',
      'a': 'Once a bid is accepted, the Chat tab unlocks for direct '
          'messaging between both parties.',
    },
    {
      'q': 'How do I buy from the Store?',
      'a': 'Go to the Store tab, browse products, tap one, select quantity, '
          'enter your MoMo number, and tap Buy.',
    },
    {
      'q': 'I have another question',
      'a': 'Email us at support@akwaabagigs.com or call +233 XX XXX XXXX '
          'during business hours (Mon-Fri 8am-5pm GMT).',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.amber600,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqs.length,
        itemBuilder: (context, index) {
          final faq = _faqs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: Icon(Icons.help_outline,
                  color: AppColors.amber600, size: 22),
              title: Text(
                faq['q']!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    faq['a']!,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.gray600),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
