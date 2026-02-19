import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/controllers/user_profile_controller.dart';
import 'package:strik_app/widgets/primary_button.dart';

class UserProfileBottomSheet extends StatelessWidget {
  final String userId;

  const UserProfileBottomSheet({super.key, required this.userId});

  static void show(BuildContext context, String userId) {
    Get.bottomSheet(
      UserProfileBottomSheet(userId: userId),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UserProfileController(), tag: userId);
    controller.loadUserProfile(userId);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          Obx(() {
            if (controller.isLoading.value) {
              return Shimmer.fromColors(
                baseColor: Colors.grey[800]!,
                highlightColor: Colors.grey[700]!,
                child: Column(
                  children: [
                    // Avatar skeleton
                    Container(
                      width: 78,
                      height: 78,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Username skeleton
                    Container(
                      width: 120,
                      height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle skeleton
                    Container(
                      width: 90,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats row skeleton
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Button skeleton
                    Container(
                      width: 140,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ],
                ),
              );
            }

            final user = controller.user.value;
            if (user == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  'User not found',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            final daysSinceJoined = DateTime.now()
                .difference(user.createdAt)
                .inDays;

            return Column(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundImage: user.avatarUrl != null
                        ? NetworkImage(user.avatarUrl!)
                        : null,
                    backgroundColor: Colors.grey[800],
                    child: user.avatarUrl == null
                        ? Text(
                            user.username?[0].toUpperCase() ?? '?',
                            style: const TextStyle(
                              fontSize: 28,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // Username
                Text(
                  user.username ?? 'Unknown',
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle: Days since joined
                Text(
                  '$daysSinceJoined Hari di Strik',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    // Level & XP
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFFFD700),
                        title: 'Lvl. ${user.level}',
                        subtitle: '${(user.xp).toStringAsFixed(0)} XP',
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Active Habits
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.check_circle_rounded,
                        iconColor: const Color(0xFF4CAF50),
                        title: '${controller.activeHabitCount.value}',
                        subtitle: 'Habit Aktif',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Action Button
                _buildActionButton(controller),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(UserProfileController controller) {
    return Obx(() {
      final status = controller.friendshipStatus.value;
      switch (status) {
        case 'self':
          return const SizedBox.shrink();

        case 'accepted':
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text(
                  'Berteman',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          );

        case 'pending':
          return Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: 'Terima',
                  onPressed: () => controller.acceptFriendRequest(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.rejectFriendRequest(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Tolak',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
            ],
          );

        case 'sent':
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Center(
              child: Text(
                'Menunggu Konfirmasi',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.white38,
                ),
              ),
            ),
          );

        case 'none':
        default:
          return SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Tambah Teman',
              onPressed: () => controller.sendFriendRequest(),
            ),
          );
      }
    });
  }
}
