import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/back4app_service.dart';

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
  WebSocketChannel? _channel;
  final List<AppNotification> _notifications = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;

    // Stop retrying after max attempts — the server likely doesn't support WebSocket
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: max reconnect attempts reached, giving up');
      return;
    }

    _isConnecting = true;

    try {
      final baseUrl = ApiService.baseUrl;
      if (baseUrl.isEmpty) {
        _isConnecting = false;
        return;
      }

      final uri = Uri.parse(baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = Uri(
        scheme: wsScheme,
        host: uri.host,
        port: uri.hasPort ? uri.port : null,
        path: '/ws',
      );

      _channel = WebSocketChannel.connect(wsUri);

      // Wait for the handshake to complete before listening
      await _channel!.ready;

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      notifyListeners();

      _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onDone: () {
          _isConnected = false;
          notifyListeners();
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('WebSocket stream error: $error');
          _isConnected = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _isConnected = false;
      _isConnecting = false;
      _channel = null;
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = json.decode(message as String);
      final type = data['type'] as String? ?? 'notification';

      AppNotification notification;

      switch (type) {
        case 'job_update':
          notification = AppNotification(
            type: type,
            title: 'Gig Update',
            message: data['message'] ?? 'A gig has been updated',
            data: data,
          );
          break;
        case 'new_application':
          notification = AppNotification(
            type: type,
            title: 'New Application',
            message: data['message'] ?? 'Someone applied to your gig',
            data: data,
          );
          break;
        case 'application_update':
          notification = AppNotification(
            type: type,
            title: 'Application Update',
            message:
                data['message'] ?? 'Your application status has changed',
            data: data,
          );
          break;
        case 'new_rating':
          notification = AppNotification(
            type: type,
            title: 'New Rating',
            message: data['message'] ?? 'You received a new rating',
            data: data,
          );
          break;
        default:
          notification = AppNotification(
            type: type,
            title: 'Notification',
            message: data['message'] ?? 'New notification',
            data: data,
          );
      }

      _notifications.insert(0, notification);
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling WebSocket message: $e');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: max reconnect attempts reached, stopping');
      return;
    }
    // Exponential backoff: 5s, 10s, 20s
    final delay = Duration(seconds: 5 * (1 << _reconnectAttempts));
    _reconnectTimer = Timer(delay, () {
      connect();
    });
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
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
