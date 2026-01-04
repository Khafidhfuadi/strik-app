import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/screens/post_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FriendController>();
    controller.fetchNotifications();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tandai semua dibaca',
            onPressed: () {
              controller.markAllAsRead();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.notifications.isEmpty) {
          return const Center(child: Text('Belum ada notifikasi.'));
        }

        return ListView.builder(
          itemCount: controller.notifications.length,
          itemBuilder: (context, index) {
            final notif = controller.notifications[index];
            final sender = notif['sender'];
            final senderName = sender != null ? sender['username'] : 'System';
            final createdAt = DateTime.parse(notif['created_at']);
            final isRead = notif['is_read'] == true;
            final notifId = notif['id'];

            return Dismissible(
              key: Key(notifId),
              direction: DismissDirection.endToStart,
              background: Container(
                color: AppTheme.primary,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                child: const Icon(Icons.check, color: Colors.white),
              ),
              confirmDismiss: (direction) async {
                await controller.markNotificationAsRead(notifId);
                return false; // Don't remove from tree, just mark as read
              },
              child: Container(
                color: isRead
                    ? Colors.transparent
                    : AppTheme.primary.withValues(alpha: 0.1),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey : AppTheme.primary,
                    backgroundImage:
                        (sender != null && sender['avatar_url'] != null)
                        ? NetworkImage(sender['avatar_url'])
                        : null,
                    child: (sender != null && sender['avatar_url'] != null)
                        ? null
                        : sender != null
                        ? Text(
                            senderName[0].toUpperCase(),
                            style: TextStyle(
                              color: isRead ? Colors.white70 : Colors.black,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          )
                        : Icon(
                            Icons.notifications,
                            color: isRead ? Colors.white70 : Colors.black,
                          ),
                  ),
                  title: Text(
                    notif['title'] ?? 'Notification',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                      color: isRead ? Colors.white70 : Colors.white,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notif['body'] ?? '',
                        style: TextStyle(
                          color: isRead ? Colors.white60 : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  onTap: () {
                    if (!isRead) {
                      controller.markNotificationAsRead(notifId);
                    }

                    final postId = notif['post_id'];
                    final habitLogId = notif['habit_log_id'];

                    if (postId != null || habitLogId != null) {
                      Get.to(
                        () => PostDetailScreen(
                          postId: postId,
                          habitLogId: habitLogId,
                        ),
                      );
                    } else if (notif['type'] == 'reaction') {
                      // Fallback for old reaction notifications without IDs if any
                      Get.back();
                      Get.find<HomeController>().selectedIndex.value = 1;
                    }
                  },
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
