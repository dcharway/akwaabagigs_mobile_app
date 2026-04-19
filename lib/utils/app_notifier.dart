import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/notifications_provider.dart';

/// Routes all transient form feedback into the unified notification feed
/// backed by [NotificationsProvider]. Drop-in replacement for the
/// `ScaffoldMessenger.showSnackBar` pattern previously used throughout
/// the app.
class AppNotifier {
  static NotificationsProvider? _providerFor(BuildContext context) {
    try {
      return Provider.of<NotificationsProvider>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  static void info(BuildContext context, String message,
      {String title = 'Info'}) {
    _providerFor(context)?.pushInfo(message, title: title);
  }

  static void success(BuildContext context, String message,
      {String title = 'Success'}) {
    _providerFor(context)?.pushSuccess(message, title: title);
  }

  static void warning(BuildContext context, String message,
      {String title = 'Warning'}) {
    _providerFor(context)?.pushWarning(message, title: title);
  }

  static void error(BuildContext context, String message,
      {String title = 'Error'}) {
    _providerFor(context)?.pushError(message, title: title);
  }
}
