import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, notifProvider, child) {
        final notifications = notifProvider.notifications;

        if (notifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "You'll be notified about gig updates, applications, and messages",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            if (notifProvider.unreadCount > 0)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${notifProvider.unreadCount} unread',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => notifProvider.markAllRead(),
                      child: const Text('Mark all read'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final notif = notifications[index];
                  return _buildNotificationTile(
                      context, notif, notifProvider, index);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotification notif,
    NotificationsProvider provider,
    int index,
  ) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('MMM d');
    final now = DateTime.now();
    final isToday = notif.timestamp.day == now.day &&
        notif.timestamp.month == now.month &&
        notif.timestamp.year == now.year;

    IconData icon;
    Color iconColor;

    switch (notif.type) {
      case 'job_update':
        icon = Icons.work;
        iconColor = Colors.blue;
        break;
      case 'new_application':
        icon = Icons.person_add;
        iconColor = Colors.green;
        break;
      case 'application_update':
        icon = Icons.assignment;
        iconColor = Colors.orange;
        break;
      case 'new_rating':
        icon = Icons.star;
        iconColor = Colors.amber;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Theme.of(context).colorScheme.primary;
    }

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: iconColor.withOpacity(0.15),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        notif.title,
        style: TextStyle(
          fontWeight: notif.isRead ? FontWeight.normal : FontWeight.bold,
        ),
      ),
      subtitle: Text(
        notif.message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        isToday
            ? timeFormat.format(notif.timestamp)
            : dateFormat.format(notif.timestamp),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
      tileColor: notif.isRead
          ? null
          : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
      onTap: () {
        provider.markRead(index);
      },
    );
  }
}
