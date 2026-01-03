import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';
import 'package:strik_app/screens/create_habit_screen.dart';

import 'package:strik_app/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/widgets/habit_card.dart';
import 'package:strik_app/widgets/weekly_habit_card.dart';
import 'package:strik_app/screens/statistics_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Inject the controller
    final HabitController controller = Get.find();
    final HomeController homeController = Get.find();
    // Check if we need to manage local state for tabs.
    // Since it's UI state, we can use a local Rx or a simple wrapper content.
    // Let's use Rx for tab index and current tab string within this build scope is fine,
    // or better, make a small controller or just use Obx with local variables if minimal.
    // For simplicity, let's keep the tab state locally in a GetxController or just variables in a wrapper?
    // Actually, `HomeScreen` is top level, let's just add tab state to HabitController
    // or create a `HomeController`? HabitController is about data.
    // Let's use Rx variables inside `build`? No, that resets on rebuild.
    // Let's create a minimal controller for Home UI state or add to HabitController.
    // Re-reading implementation plan: "Convert to StatelessWidget".
    // I will add a _selectedIndex and _currentTab to a local Rx variable or use a micro-controller.
    // Let's use a nested Obx or ValueBuilder?
    // Easiest is to add UI state to HabitController OR just make a small HomeStateController.
    // I'll add UI state to a simple HomeStateController defined in this file for now to keep it clean.

    // HomeController is obtained via Get.find() from initialBinding

    return Obx(() {
      if (homeController.selectedIndex.value == 1) {
        return Scaffold(
          body: const StatisticsScreen(),
          bottomNavigationBar: _buildBottomNavigationBar(homeController),
        );
      }

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(
            'Habits',
            style: GoogleFonts.spaceGrotesk(
              fontWeight: FontWeight.bold,
              fontSize: 28,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppTheme.background,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _navigateAndRefresh(context),
            ),
          ],
        ),
        body: controller.isLoading.value
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : Column(
                children: [
                  // Tab Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        _buildTabChip('Today', homeController),
                        const SizedBox(width: 12),
                        _buildTabChip('Weekly', homeController),
                        const SizedBox(width: 12),
                        _buildTabChip('Overall', homeController),
                      ],
                    ),
                  ),

                  // Progress Bar
                  if (homeController.currentTab.value == 'Today')
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: controller.todayProgress,
                            backgroundColor: Colors.grey[800],
                            color: const Color(0xFFFF5757),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${controller.todayLogs.values.where((s) => s == 'completed').length} completed • ${controller.todayLogs.values.where((s) => s == 'skipped').length} skipped',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                  Expanded(
                    child: homeController.currentTab.value == 'Today'
                        ? _buildTodayList(controller)
                        : homeController.currentTab.value == 'Weekly'
                        ? _buildWeeklyList(controller)
                        : const Center(
                            child: Text(
                              'Overall Coming Soon',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                  ),
                ],
              ),
        bottomNavigationBar: _buildBottomNavigationBar(homeController),
      );
    });
  }

  Widget _buildTabChip(String label, HomeController homeController) {
    return GestureDetector(
      onTap: () => homeController.currentTab.value = label,
      child: Obx(() {
        final isActive = homeController.currentTab.value == label;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.grey[900] : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildTodayList(HabitController controller) {
    if (controller.habits.isEmpty) {
      return const Center(
        child: Text('No habits yet', style: TextStyle(color: Colors.white54)),
      );
    }
    // Use sorted habits from controller
    final habits = controller.sortedHabits;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        // Must observe individual log changes if using Obx above,
        // but since we are inside Obx(build), any change to .value of logs maps triggers rebuild.
        // Actually Obx checks observables accessed.
        // accessing controller.todayLogs[id] is reactive if the map itself notifies or if we use RxMap properly.
        final status = controller.todayLogs[habit.id];

        return Dismissible(
          key: Key(habit.id!),
          confirmDismiss: (direction) async {
            await controller.toggleHabitStatus(habit, status, direction);
            return false; // Toggle handled in controller
          },
          background: _buildSwipeBackground(
            Alignment.centerLeft,
            status == 'completed' ? Icons.undo : Icons.check,
            status == 'completed' ? 'un-check' : 'kelarin',
            AppTheme.primary,
            Colors.black,
          ),
          secondaryBackground: _buildSwipeBackground(
            Alignment.centerRight,
            status == 'skipped' ? Icons.undo : Icons.close,
            status == 'skipped' ? 'un-skip' : 'skip dlu',
            const Color(0xFFFF5757),
            Colors.white,
          ),
          child: HabitCard(habit: habit, status: status),
        );
      },
    );
  }

  Widget _buildSwipeBackground(
    Alignment alignment,
    IconData icon,
    String text,
    Color color,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerLeft) ...[
            Icon(icon, color: textColor),
            const SizedBox(width: 8),
          ],
          Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (alignment == Alignment.centerRight) ...[
            const SizedBox(width: 8),
            Icon(icon, color: textColor),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyList(HabitController controller) {
    // Current week logic is inside controller for data but UI needs range?
    // The WeeklyHabitCard just takes the logs map.
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final weekStart = now.subtract(Duration(days: currentWeekday - 1));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: controller.habits.length,
      itemBuilder: (context, index) {
        final habit = controller.habits[index];
        final logs = controller.weeklyLogs[habit.id] ?? {};
        return WeeklyHabitCard(
          habit: habit,
          weeklyLogs: logs,
          weekStart: weekStart,
        );
      },
    );
  }

  Widget _buildBottomNavigationBar(HomeController homeController) {
    return BottomNavigationBar(
      backgroundColor: AppTheme.surface,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: Colors.white54,
      currentIndex: homeController.selectedIndex.value,
      onTap: (index) => homeController.selectedIndex.value = index,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.grid_view_rounded),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Stats',
        ),
      ],
    );
  }

  void _navigateAndRefresh(BuildContext context) async {
    // With Get, we can use Get.to
    // But since main.dart isn't updated yet, Get.to might fail if GetMaterialApp isn't modifying navigator key?
    // Actually Get.to works if GetMaterialApp is used.
    // I will assume I'll update appropriate main.dart soon.
    // If NOT using GetMaterialApp, standard Navigator works but we want to refactor.
    // I will use Get.to().

    await Get.to(() => const CreateHabitScreen());
    Get.find<HabitController>().fetchHabitsAndLogs();
  }
}
