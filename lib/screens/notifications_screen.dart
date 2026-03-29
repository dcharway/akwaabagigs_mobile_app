import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notifications_provider.dart';
import '../utils/colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationsProvider>(
      builder: (context, notifProvider, child) {
        final notifications = notifProvider.notifications;

        if (notifications.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  const Text('No notifications',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                    "You'll be notified about gig updates, bids, messages, and more",
                    style: TextStyle(
                        color: AppColors.gray500, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            // Header bar
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: AppColors.gray200)),
              ),
              child: Row(
                children: [
                  if (notifProvider.unreadCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.amber500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${notifProvider.unreadCount} new',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ] else
                    const Text('All caught up',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.gray500)),
                  const Spacer(),
                  if (notifProvider.unreadCount > 0)
                    TextButton(
                      onPressed: () => notifProvider.markAllRead(),
                      child: const Text('Mark all read',
                          style: TextStyle(fontSize: 13)),
                    ),
                  if (notifications.isNotEmpty)
                    TextButton(
                      onPressed: () => notifProvider.clearAll(),
                      child: Text('Clear all',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.gray500)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  return _buildNotificationTile(
                      context, notifications[index], notifProvider, index);
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

    final style = _getNotifStyle(notif.type);

    return Container(
      decoration: BoxDecoration(
        color: notif.isRead ? Colors.white : AppColors.amber50,
        border: const Border(
            bottom: BorderSide(color: AppColors.gray200, width: 0.5)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: style.color.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(style.icon, color: style.color, size: 22),
        ),
        title: Text(
          notif.title,
          style: TextStyle(
            fontWeight:
                notif.isRead ? FontWeight.w500 : FontWeight.bold,
            fontSize: 14,
            color: AppColors.gray900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            notif.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: notif.isRead ? AppColors.gray500 : AppColors.gray700,
            ),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              isToday
                  ? timeFormat.format(notif.timestamp)
                  : dateFormat.format(notif.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: notif.isRead
                    ? AppColors.gray400
                    : AppColors.amber700,
                fontWeight:
                    notif.isRead ? FontWeight.normal : FontWeight.w600,
              ),
            ),
            if (!notif.isRead)
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.amber500,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        onTap: () => provider.markRead(index),
      ),
    );
  }

  _NotifStyle _getNotifStyle(String type) {
    switch (type) {
      case 'welcome':
        return _NotifStyle(Icons.celebration, AppColors.amber600);
      case 'tip_seeker':
        return _NotifStyle(Icons.verified, AppColors.blue600);
      case 'tip_poster':
        return _NotifStyle(Icons.campaign, AppColors.amber600);
      case 'tip_bid':
        return _NotifStyle(Icons.gavel, AppColors.purple600);
      case 'job_update':
        return _NotifStyle(Icons.work, AppColors.blue600);
      case 'job_completed':
        return _NotifStyle(Icons.check_circle, const Color(0xFF4CAF50));
      case 'new_application':
        return _NotifStyle(Icons.person_add, const Color(0xFF4CAF50));
      case 'application_update':
      case 'application_approved':
        return _NotifStyle(Icons.assignment, AppColors.amber600);
      case 'bid_agreed':
      case 'bid_approved':
        return _NotifStyle(Icons.handshake, const Color(0xFF4CAF50));
      case 'bid_rejected':
        return _NotifStyle(Icons.cancel, AppColors.red600);
      case 'new_rating':
        return _NotifStyle(Icons.star, AppColors.amber500);
      case 'new_message':
        return _NotifStyle(Icons.chat_bubble, const Color(0xFF4CAF50));
      default:
        return _NotifStyle(Icons.notifications, AppColors.gray600);
    }
  }
}

class _NotifStyle {
  final IconData icon;
  final Color color;
  _NotifStyle(this.icon, this.color);
}
