import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../config/back4app_config.dart';

class AppNotification {
  final String type;
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? data;
  bool isRead;

  AppNotification({
    required this.type,
    required this.title,
    required this.message,
    DateTime? timestamp,
    this.data,
    this.isRead = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NotificationsProvider extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _defaultsAdded = false;
  LiveQuery? _liveQuery;
  Subscription? _jobSubscription;
  Subscription? _applicationSubscription;
  Subscription? _messageSubscription;
  Subscription? _conversationSubscription;

  /// The only notification types the feed will accept.
  /// Gig category: job lifecycle, applications, bids.
  /// Chat category: messages, conversations.
  static const _gigTypes = {
    'welcome',
    'tip_seeker',
    'tip_poster',
    'tip_bid',
    'job_update',
    'job_completed',
    'new_application',
    'application_update',
    'application_approved',
    'bid_agreed',
    'bid_approved',
    'bid_rejected',
  };
  static const _chatTypes = {
    'new_message',
    'new_conversation',
  };

  /// Callback invoked when a conversation is created or updated via
  /// LiveQuery.  ChatListScreen registers itself here so it can reload.
  VoidCallback? onConversationChanged;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    // Add default welcome alerts once
    if (!_defaultsAdded) {
      _addDefaults();
      _defaultsAdded = true;
    }

    try {
      _liveQuery = LiveQuery();

      // ---- Job updates (for seekers: new gigs; for posters: status changes) ----
      final jobQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.jobClass));
      _jobSubscription = await _liveQuery!.client.subscribe(jobQuery);

      _jobSubscription!.on(LiveQueryEvent.create, (value) {
        _addNotification(
          type: 'job_update',
          title: 'New Gig Posted',
          message:
              '${value.get<String>('title') ?? 'A new gig'} has been posted',
          data: {'jobId': value.objectId},
        );
      });

      _jobSubscription!.on(LiveQueryEvent.update, (value) {
        final status = value.get<String>('status') ?? '';
        if (status == 'bid_agreed') {
          _addNotification(
            type: 'bid_agreed',
            title: 'Bid Accepted!',
            message:
                'A bid on "${value.get<String>('title') ?? 'your gig'}" has been accepted. Chat is now active.',
            data: {'jobId': value.objectId},
          );
        } else if (status == 'completed') {
          _addNotification(
            type: 'job_completed',
            title: 'Gig Completed',
            message:
                '"${value.get<String>('title') ?? 'A gig'}" has been marked as completed.',
            data: {'jobId': value.objectId},
          );
        } else {
          _addNotification(
            type: 'job_update',
            title: 'Gig Updated',
            message:
                '${value.get<String>('title') ?? 'A gig'} has been updated',
            data: {'jobId': value.objectId},
          );
        }
      });

      // ---- Application updates (for posters: new applicants; for seekers: status) ----
      final appQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.applicationClass));
      _applicationSubscription =
          await _liveQuery!.client.subscribe(appQuery);

      _applicationSubscription!.on(LiveQueryEvent.create, (value) {
        _addNotification(
          type: 'new_application',
          title: 'New Application',
          message:
              '${value.get<String>('fullName') ?? 'Someone'} applied to your gig',
          data: {
            'jobId': value.get<String>('jobId'),
            'applicationId': value.objectId,
          },
        );
      });

      _applicationSubscription!.on(LiveQueryEvent.update, (value) {
        final bidStatus = value.get<String>('bidStatus') ?? '';
        final appStatus = value.get<String>('status') ?? '';

        if (bidStatus == 'approved') {
          _addNotification(
            type: 'bid_approved',
            title: 'Your Bid Was Accepted!',
            message:
                'Your bid of GH₵${((value.get<int>('bidAmountPesewas') ?? 0) / 100).round()} was accepted. Chat is now enabled.',
            data: {'applicationId': value.objectId},
          );
        } else if (bidStatus == 'rejected') {
          _addNotification(
            type: 'bid_rejected',
            title: 'Bid Not Accepted',
            message:
                'Your bid was not accepted. Try a different amount or gig.',
            data: {'applicationId': value.objectId},
          );
        } else if (appStatus == 'approved') {
          _addNotification(
            type: 'application_approved',
            title: 'Application Approved',
            message: 'Your application has been approved!',
            data: {'applicationId': value.objectId},
          );
        } else {
          _addNotification(
            type: 'application_update',
            title: 'Application Update',
            message:
                'Application status changed to ${value.get<String>('status') ?? 'updated'}',
            data: {'applicationId': value.objectId},
          );
        }
      });

      // ---- Message updates (for chat notifications) ----
      final msgQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.messageClass));
      _messageSubscription =
          await _liveQuery!.client.subscribe(msgQuery);

      _messageSubscription!.on(LiveQueryEvent.create, (value) {
        _addNotification(
          type: 'new_message',
          title: 'New Message',
          message:
              '${value.get<String>('senderName') ?? 'Someone'}: ${_truncate(value.get<String>('content') ?? '', 50)}',
          data: {'chatRoomId': value.get<String>('chatRoomId')},
        );
      });

      // ---- Conversation updates (new conversation created or updated) ----
      final convQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.conversationClass));
      _conversationSubscription =
          await _liveQuery!.client.subscribe(convQuery);

      _conversationSubscription!.on(LiveQueryEvent.create, (value) {
        final jobTitle = value.get<String>('jobTitle') ?? 'a gig';
        _addNotification(
          type: 'new_conversation',
          title: 'New Conversation',
          message: 'A conversation was started for "$jobTitle".',
          data: {'conversationId': value.objectId},
        );
        onConversationChanged?.call();
      });

      _conversationSubscription!.on(LiveQueryEvent.update, (value) {
        onConversationChanged?.call();
      });

      _isConnected = true;
      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      debugPrint('LiveQuery connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      notifyListeners();
    }
  }

  /// Default welcome alerts for new users.
  void _addDefaults() {
    _notifications.addAll([
      AppNotification(
        type: 'welcome',
        title: 'Welcome to Akwaaba Gigs!',
        message:
            'Browse gigs, apply, and connect with employers across Ghana.',
        isRead: false,
      ),
      AppNotification(
        type: 'tip_seeker',
        title: 'Tip: Get Verified',
        message:
            'Verify your ID in Profile to unlock chat and get more gig opportunities.',
        isRead: false,
      ),
      AppNotification(
        type: 'tip_poster',
        title: 'Tip: Post Your First Gig',
        message:
            'Go to the Gigs tab and tap "Post Gig" to find skilled workers.',
        isRead: false,
      ),
      AppNotification(
        type: 'tip_bid',
        title: 'How Bidding Works',
        message:
            'Apply for a gig and place a bid in 50 or 100 GH₵ increments. Chat unlocks when the poster accepts.',
        isRead: false,
      ),
    ]);
    notifyListeners();
  }

  String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  void _addNotification({
    required String type,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) {
    if (!_gigTypes.contains(type) && !_chatTypes.contains(type)) return;

    _notifications.insert(
      0,
      AppNotification(type: type, title: title, message: message, data: data),
    );
    notifyListeners();
  }

  void markAllRead() {
    for (final n in _notifications) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void markRead(int index) {
    if (index >= 0 && index < _notifications.length) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  void disconnect() {
    if (_liveQuery != null) {
      if (_jobSubscription != null) {
        _liveQuery!.client.unSubscribe(_jobSubscription!);
      }
      if (_applicationSubscription != null) {
        _liveQuery!.client.unSubscribe(_applicationSubscription!);
      }
      if (_messageSubscription != null) {
        _liveQuery!.client.unSubscribe(_messageSubscription!);
      }
      if (_conversationSubscription != null) {
        _liveQuery!.client.unSubscribe(_conversationSubscription!);
      }
    }
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
