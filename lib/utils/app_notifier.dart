import 'package:flutter/material.dart';

/// Lightweight transient feedback shown as a floating SnackBar.
///
/// This is the correct channel for form validation, success confirmations,
/// and error messages — things the user needs to see once and then dismiss.
/// Persistent gig and chat events go through [NotificationsProvider] instead.
class AppNotifier {
  static void info(BuildContext context, String message,
      {String title = 'Info'}) {
    _show(context, message, Colors.blueGrey);
  }

  static void success(BuildContext context, String message,
      {String title = 'Success'}) {
    _show(context, message, Colors.green);
  }

  static void warning(BuildContext context, String message,
      {String title = 'Warning'}) {
    _show(context, message, Colors.orange);
  }

  static void error(BuildContext context, String message,
      {String title = 'Error'}) {
    _show(context, message, Colors.redAccent);
  }

  static void _show(BuildContext context, String message, Color bg) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: bg),
    );
  }
}
