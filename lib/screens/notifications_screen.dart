import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:timeago/timeago.dart' as timeago;

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<FriendController>();
    controller.fetchNotifications();

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
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

            return ListTile(
              leading: CircleAvatar(
                child: sender != null
                    ? Text(senderName[0].toUpperCase())
                    : const Icon(Icons.notifications),
              ),
              title: Text(notif['title'] ?? 'Notification'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['body'] ?? ''),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              isThreeLine: true,
            );
          },
        );
      }),
    );
  }
}
