import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../providers/auth_provider.dart';
import '../screens/chat_list_screen.dart';
import '../screens/login_screen.dart';

class HeaderWidget extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onChatTap;

  const HeaderWidget({super.key, this.onMenuTap, this.onChatTap});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // ---- Left: menu + logo + title ----
          // Wrapped in Expanded so a long user name does not push the
          // right-side action button off-screen.
          Expanded(
            child: Row(
              children: [
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
                    child: const Icon(Icons.menu,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.amber500, width: 2),
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
                // The text column must flex so long names truncate instead
                // of overflowing the outer Row.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Akwaaba',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // ---- Right: single Chat action ----
          // The Alerts icon has been removed: chat is now the single
          // destination for both conversations and notifications.
          GestureDetector(
            onTap: () {
              if (onChatTap != null) {
                onChatTap!();
              } else if (!authProvider.isAuthenticated) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LoginScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const ChatListScreen()),
                );
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
        ],
      ),
    );
  }
}
