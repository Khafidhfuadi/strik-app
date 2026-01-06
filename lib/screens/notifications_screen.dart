import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/screens/post_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _scrollController = ScrollController();
  final controller = Get.find<FriendController>();

  @override
  void initState() {
    super.initState();
    controller.fetchNotifications(refresh: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      controller.loadMoreNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Tandai semua dibaca',
            onPressed: () {
              controller.markAllNotificationsAsRead();
            },
          ),
        ],
      ),
      body: Obx(() {
        if (controller.notifications.isEmpty &&
            !controller.isLoadingMoreNotifications.value) {
          return const Center(child: Text('Belum ada notifikasi.'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            await controller.fetchNotifications(refresh: true);
          },
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount:
                controller.notifications.length +
                (controller.isLoadingMoreNotifications.value ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == controller.notifications.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final notif = controller.notifications[index];
              final sender = notif['sender'];
              final senderName = sender != null ? sender['username'] : 'System';
              final createdAt = DateTime.parse(notif['created_at']);
              final isRead = notif['is_read'] == true;
              final notifId = notif['id'];

              return Dismissible(
                key: Key(notifId),
                // Allow both directions
                direction: DismissDirection.horizontal,
                // Background for Swipe Right -> Delete (Red)
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                // Background for Swipe Left -> Mark Read (Green/Blue)
                secondaryBackground: Container(
                  color: Colors.blue,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.mark_email_read, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  if (direction == DismissDirection.endToStart) {
                    // Swipe Left: Mark as Read
                    await controller.markNotificationAsRead(notifId);
                    // Return false so item stays in list (just updates status)
                    return false;
                  } else {
                    // Swipe Right: Delete
                    // Return true to proceed with dismiss animation and call onDismissed
                    return true;
                  }
                },
                onDismissed: (direction) {
                  if (direction == DismissDirection.startToEnd) {
                    controller.deleteNotification(notifId);
                  }
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
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
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
          ),
        );
      }),
    );
  }
}
