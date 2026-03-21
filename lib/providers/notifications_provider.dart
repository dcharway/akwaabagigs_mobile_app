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
  LiveQuery? _liveQuery;
  Subscription? _jobSubscription;
  Subscription? _applicationSubscription;
  Subscription? _ratingSubscription;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;

    try {
      _liveQuery = LiveQuery();

      // Subscribe to Job updates
      final jobQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.jobClass));
      _jobSubscription = await _liveQuery!.client.subscribe(jobQuery);

      _jobSubscription!.on(LiveQueryEvent.create, (value) {
        _addNotification(
          type: 'job_update',
          title: 'New Gig Posted',
          message: '${value.get<String>('title') ?? 'A new gig'} has been posted',
        );
      });

      _jobSubscription!.on(LiveQueryEvent.update, (value) {
        _addNotification(
          type: 'job_update',
          title: 'Gig Update',
          message: '${value.get<String>('title') ?? 'A gig'} has been updated',
        );
      });

      // Subscribe to Application updates
      final appQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.applicationClass));
      _applicationSubscription = await _liveQuery!.client.subscribe(appQuery);

      _applicationSubscription!.on(LiveQueryEvent.create, (value) {
        _addNotification(
          type: 'new_application',
          title: 'New Application',
          message: '${value.get<String>('fullName') ?? 'Someone'} applied to your gig',
        );
      });

      _applicationSubscription!.on(LiveQueryEvent.update, (value) {
        _addNotification(
          type: 'application_update',
          title: 'Application Update',
          message: 'An application status has changed to ${value.get<String>('status') ?? 'updated'}',
        );
      });

      // Subscribe to Rating updates
      final ratingQuery = QueryBuilder<ParseObject>(
          ParseObject(Back4AppConfig.ratingClass));
      _ratingSubscription = await _liveQuery!.client.subscribe(ratingQuery);

      _ratingSubscription!.on(LiveQueryEvent.create, (value) {
        _addNotification(
          type: 'new_rating',
          title: 'New Rating',
          message: 'You received a new rating of ${value.get<int>('rating') ?? 0}/5',
        );
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

  void _addNotification({
    required String type,
    required String title,
    required String message,
  }) {
    _notifications.insert(
      0,
      AppNotification(type: type, title: title, message: message),
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
      if (_ratingSubscription != null) {
        _liveQuery!.client.unSubscribe(_ratingSubscription!);
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
