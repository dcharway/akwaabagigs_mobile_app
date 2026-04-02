import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';
import '../models/job.dart';
import '../utils/colors.dart';
import '../screens/live_chat_screen.dart';

class AsyncChatButton extends StatefulWidget {
  final Job job;
  final String otherPartyName;

  const AsyncChatButton({
    super.key,
    required this.job,
    required this.otherPartyName,
  });

  @override
  State<AsyncChatButton> createState() => _AsyncChatButtonState();
}

class _AsyncChatButtonState extends State<AsyncChatButton> {
  late bool _chatEnabled;
  int? _agreedAmount;
  LiveQuery? _liveQuery;
  Subscription? _jobSubscription;

  @override
  void initState() {
    super.initState();
    _chatEnabled = widget.job.chatEnabled;
    _agreedAmount = widget.job.agreedAmountPesewas;
    _subscribeToJobUpdates();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  Future<void> _subscribeToJobUpdates() async {
    try {
      _liveQuery = LiveQuery();
      final query = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.jobClass))
        ..whereEqualTo('objectId', widget.job.id);

      _jobSubscription = await _liveQuery!.client.subscribe(query);

      _jobSubscription!.on(LiveQueryEvent.update, (value) {
        if (mounted) {
          setState(() {
            _chatEnabled = value.get<bool>('chatEnabled') ?? false;
            _agreedAmount = value.get<int>('agreedAmountPesewas');
          });
        }
      });
    } catch (e) {
      // LiveQuery not available — fall back to current state
    }
  }

  void _unsubscribe() {
    if (_liveQuery != null && _jobSubscription != null) {
      _liveQuery!.client.unSubscribe(_jobSubscription!);
    }
  }

  void _openChat() {
    if (!_chatEnabled) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveChatScreen(
          jobId: widget.job.id,
          jobTitle: widget.job.title,
          otherPartyName: widget.otherPartyName,
          posterId: widget.job.posterId,
          posterName: widget.job.postedBy,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agreedGhs = _agreedAmount != null
        ? (_agreedAmount! / 100).toStringAsFixed(0)
        : null;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _chatEnabled ? _openChat : null,
        icon: Icon(
          _chatEnabled ? Icons.chat_bubble : Icons.lock_outline,
          size: 20,
        ),
        label: Text(
          _chatEnabled
              ? 'Start Chat${agreedGhs != null ? ' (GH₵$agreedGhs agreed)' : ''}'
              : 'Chat Locked — Agree on Bid First',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _chatEnabled ? const Color(0xFF4CAF50) : AppColors.gray400,
          foregroundColor: Colors.white,
          minimumSize: const Size(200, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          elevation: _chatEnabled ? 4 : 0,
          shadowColor: _chatEnabled
              ? const Color(0x664CAF50)
              : Colors.transparent,
        ),
      ),
    );
  }
}
