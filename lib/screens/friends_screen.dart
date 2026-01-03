import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/screens/add_friend_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FriendController());

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teman Strik'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Teman'),
              Tab(text: 'Permintaan'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () {
                Get.to(() => const AddFriendScreen());
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildFriendsList(controller),
            _buildRequestsList(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(FriendController controller) {
    return Obx(() {
      if (controller.isLoadingFriends.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.friends.isEmpty) {
        return const Center(
          child: Text('Belum ada teman nih. Cari teman yuk!'),
        );
      }

      return ListView.builder(
        itemCount: controller.friends.length,
        itemBuilder: (context, index) {
          final friend = controller.friends[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(friend.username?[0].toUpperCase() ?? '?'),
            ),
            title: Text(friend.username ?? 'Unknown'),
            subtitle: Text('Joined ${friend.createdAt.year}'),
            // trailing: IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
          );
        },
      );
    });
  }

  Widget _buildRequestsList(FriendController controller) {
    return Obx(() {
      if (controller.isLoadingRequests.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.pendingRequests.isEmpty) {
        return const Center(child: Text('Gak ada permintaan pertemanan baru.'));
      }

      return ListView.builder(
        itemCount: controller.pendingRequests.length,
        itemBuilder: (context, index) {
          final request = controller.pendingRequests[index];
          final sender = request['sender']; // This is a Map
          final senderName = sender?['username'] ?? 'Unknown';

          return ListTile(
            leading: CircleAvatar(child: Text(senderName[0].toUpperCase())),
            title: Text(senderName),
            subtitle: const Text('Ingin berteman denganmu'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () => controller.acceptRequest(request['id']),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => controller.rejectRequest(request['id']),
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
