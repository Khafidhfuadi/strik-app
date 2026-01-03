import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/friend_controller.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';
import 'package:strik_app/widgets/custom_text_field.dart';

class AddFriendScreen extends StatelessWidget {
  const AddFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Find existing controller
    final FriendController controller = Get.find();
    final TextEditingController searchController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Cari Teman')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CustomTextField(
              controller: searchController,
              label: 'Username',
              hintText: 'Cari username teman...',
              onChanged: (value) {
                // Debounce could be added here, but for now simple direct call or explicit search button
              },
              onSubmitted: (value) {
                controller.searchUsers(value);
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                controller.searchUsers(searchController.text);
              },
              child: const Text('Cari'),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Obx(() {
                if (controller.isSearching.value) {
                  return const Center(child: CustomLoadingIndicator());
                }

                if (controller.searchResults.isEmpty) {
                  return const Center(
                    child: Text('Hasil pencarian akan muncul di sini.'),
                  );
                }

                return ListView.builder(
                  itemCount: controller.searchResults.length,
                  itemBuilder: (context, index) {
                    final user = controller.searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(user.username?[0].toUpperCase() ?? '?'),
                      ),
                      title: Text(user.username ?? 'Unknown'),
                      trailing: IconButton(
                        icon: const Icon(Icons.person_add),
                        onPressed: () {
                          controller.sendFriendRequest(user.id);
                        },
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
