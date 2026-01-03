import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/screens/add_friend_screen.dart';
import 'package:strik_app/screens/notifications_screen.dart';

class FriendsScreen extends StatelessWidget {
  const FriendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FriendController());

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Teman Strik'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Teman'),
              Tab(text: 'Ranking'),
              Tab(text: 'Aktivitas'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => Get.to(() => const NotificationsScreen()),
            ),
            IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => Get.to(() => const AddFriendScreen()),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildFriendsAndRequestsList(controller),
            _buildLeaderboardList(controller),
            _buildActivityFeedList(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsAndRequestsList(FriendController controller) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Requests Section
          Obx(() {
            if (controller.pendingRequests.isNotEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Permintaan Berteman',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: controller.pendingRequests.length,
                    itemBuilder: (context, index) {
                      final request = controller.pendingRequests[index];
                      final sender = request['sender'];
                      final senderName = sender?['username'] ?? 'Unknown';

                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(senderName[0].toUpperCase()),
                        ),
                        title: Text(senderName),
                        subtitle: const Text('Ingin berteman'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onPressed: () =>
                                  controller.acceptRequest(request['id']),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  controller.rejectRequest(request['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(),
                ],
              );
            }
            return const SizedBox.shrink();
          }),

          // Friends List
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Daftar Teman',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          Obx(() {
            if (controller.isLoadingFriends.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (controller.friends.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('Belum punya teman. Cari yuk!')),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.friends.length,
              itemBuilder: (context, index) {
                final friend = controller.friends[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(friend.username?[0].toUpperCase() ?? '?'),
                  ),
                  title: Text(friend.username ?? 'Unknown'),
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.touch_app,
                      color: Colors.amber,
                    ), // Nudge icon
                    onPressed: () => controller.sendNudge(friend.id),
                    tooltip: 'Strik! (Nudge)',
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList(FriendController controller) {
    controller.fetchLeaderboard(); // Trigger fetch when building this tab

    return Obx(() {
      if (controller.isLoadingLeaderboard.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.leaderboard.isEmpty) {
        return const Center(child: Text('Belum ada data ranking.'));
      }

      return ListView.separated(
        itemCount: controller.leaderboard.length,
        separatorBuilder: (c, i) => const Divider(),
        itemBuilder: (context, index) {
          final entry = controller.leaderboard[index];
          final user = entry['user']; // UserModel object
          final score = entry['score'];

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: index == 0 ? Colors.amber : Colors.grey[800],
              foregroundColor: index == 0 ? Colors.black : Colors.white,
              child: Text('${index + 1}'),
            ),
            title: Text(user.username ?? 'Unknown'),
            trailing: Text(
              '$score Habits',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          );
        },
      );
    });
  }

  Widget _buildActivityFeedList(FriendController controller) {
    controller.fetchActivityFeed();

    return Obx(() {
      if (controller.isLoadingActivity.value) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.activityFeed.isEmpty) {
        return const Center(
          child: Text('Belum ada aktivitas terbaru dari teman.'),
        );
      }

      return ListView.builder(
        itemCount: controller.activityFeed.length,
        itemBuilder: (context, index) {
          final log = controller.activityFeed[index];
          final habit = log['habit'];
          final user = habit['user'];
          final habitTitle = habit['title'];
          final userName = user['username'];
          final completedAt = DateTime.parse(log['completed_at']);

          return ListTile(
            leading: CircleAvatar(child: Text(userName[0].toUpperCase())),
            title: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(text: ' completed '),
                  TextSpan(
                    text: habitTitle,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            subtitle: Text(
              '${completedAt.day}/${completedAt.month} ${completedAt.hour}:${completedAt.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          );
        },
      );
    });
  }
}
