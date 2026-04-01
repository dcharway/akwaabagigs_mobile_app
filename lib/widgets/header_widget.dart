import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../screens/chat_list_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/login_screen.dart';

class HeaderWidget extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onChatTap;

  const HeaderWidget({super.key, this.onMenuTap, this.onChatTap});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationsProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Menu Button
              GestureDetector(
                onTap: onMenuTap,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.amber500, AppColors.amber700],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amber600.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.menu, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              // Logo and Title
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.amber500, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akwaaba',
                        style: TextStyle(
                          fontSize: 20,
                          color: AppColors.amber900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        authProvider.isAuthenticated
                            ? 'Welcome, ${authProvider.user?.firstName ?? 'User'}'
                            : 'Your Service Hub',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          // Chat + Notification buttons
          Row(
            children: [
              // Chat Button
              GestureDetector(
                onTap: () {
                  if (onChatTap != null) {
                    onChatTap!();
                  } else if (!authProvider.isAuthenticated) {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ChatListScreen()));
                  }
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.gray100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.gray700,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Notification Button
              GestureDetector(
                onTap: () {
                  if (!authProvider.isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  );
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.gray100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.gray700,
                        size: 20,
                      ),
                    ),
                    if (notifProvider.unreadCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.red500,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${notifProvider.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
