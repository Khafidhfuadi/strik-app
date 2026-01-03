import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:strik_app/controllers/habit_controller.dart';
import 'package:strik_app/controllers/home_controller.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/screens/habit_detail_screen.dart';
import 'package:strik_app/screens/social_screen.dart';

import 'package:strik_app/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/widgets/habit_card.dart';
import 'package:strik_app/widgets/weekly_habit_card.dart';
import 'package:strik_app/screens/statistics_screen.dart';
import 'package:strik_app/widgets/custom_loading_indicator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    final homeController = Get.find<HomeController>();
    // Initialize PageController based on current tab
    int initialPage = 0;
    if (homeController.currentTab.value == 'Mingguan') initialPage = 1;
    _pageController = PageController(initialPage: initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    // Sync tab change from PageView
    final homeController = Get.find<HomeController>();
    final tabs = ['Harian', 'Mingguan'];
    if (index >= 0 && index < tabs.length) {
      homeController.currentTab.value = tabs[index];
    }
  }

  void _onTabTapped(int index) {
    // Sync PageView from tab tap
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    // State update happens via PageView listener or manually if needed,
    // but PageView's onPageChanged will fire and update controller.
  }

  @override
  Widget build(BuildContext context) {
    final HabitController controller = Get.find();
    final HomeController homeController = Get.find();

    return Obx(() {
      final navBar = _buildBottomNavigationBar(homeController);

      if (homeController.selectedIndex.value == 1) {
        return SocialScreen(bottomNavigationBar: navBar);
      }

      if (homeController.selectedIndex.value == 2) {
        return Scaffold(
          body: const StatisticsScreen(),
          bottomNavigationBar: navBar,
        );
      }

      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Row(
            children: [
              Text(
                'Strik',
                style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Lottie.asset(
                'assets/src/strik-logo.json',
                width: 35,
                height: 35,
                repeat: false,
              ),
            ],
          ),
          backgroundColor: AppTheme.background,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _navigateAndRefresh(context),
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.white),
              onPressed: () => homeController.logout(),
            ),
          ],
        ),
        body: controller.isLoading.value
            ? const Center(child: CustomLoadingIndicator())
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
                        _buildTabChip('Harian', 0, homeController),
                        const SizedBox(width: 12),
                        _buildTabChip('Mingguan', 1, homeController),
                      ],
                    ),
                  ),

                  // Content Area with PageView
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: _onTabChanged,
                      children: [
                        // Today Page
                        _buildTodayPage(controller),
                        // Weekly Page
                        _buildWeeklyList(controller),
                      ],
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: navBar,
      );
    });
  }

  Widget _buildTabChip(String label, int index, HomeController homeController) {
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: Obx(() {
        final isActive = homeController.currentTab.value == label;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
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

  Widget _buildTodayPage(HabitController controller) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                '${controller.todayLogs.values.where((s) => s == 'completed').length} kelar • ${controller.todayLogs.values.where((s) => s == 'skipped').length} skip',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.grey[500],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildTodayList(controller)),
      ],
    );
  }

  Widget _buildTodayList(HabitController controller) {
    if (controller.habits.isEmpty) {
      return const Center(
        child: Text(
          'Belum ada habit nih, gass bikin!',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    // Use sorted habits from controller
    final habits = controller.sortedHabits;

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];

        return Obx(() {
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
              status == 'completed' ? 'batalin' : 'sikat',
              AppTheme.primary,
              Colors.black,
            ),
            secondaryBackground: _buildSwipeBackground(
              Alignment.centerRight,
              status == 'skipped' ? Icons.undo : Icons.close,
              status == 'skipped' ? 'gajadi' : 'skip dlu',
              const Color(0xFFFF5757),
              Colors.white,
            ),
            child: HabitCard(
              habit: habit,
              status: status,
              onTap: () => Get.to(() => HabitDetailScreen(habit: habit)),
            ),
          );
        });
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
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final weekStart = now.subtract(Duration(days: currentWeekday - 1));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: controller.habits.length,
      itemBuilder: (context, index) {
        final habit = controller.habits[index];
        return Obx(() {
          final logs = controller.weeklyLogs[habit.id] ?? {};
          return WeeklyHabitCard(
            habit: habit,
            weeklyLogs: logs,
            weekStart: weekStart,
          );
        });
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
          icon: Icon(Icons.people_alt_rounded),
          label: 'Social',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Stats',
        ),
      ],
    );
  }

  void _navigateAndRefresh(BuildContext context) async {
    await Get.to(() => const CreateHabitScreen());
    Get.find<HabitController>().fetchHabitsAndLogs();
  }
}
