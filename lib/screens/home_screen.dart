import 'package:flutter/material.dart';
import 'package:strik_app/main.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/widgets/habit_card.dart';
import 'package:strik_app/widgets/weekly_habit_card.dart';
import 'package:strik_app/screens/statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String _currentTab = 'Today'; // 'Today', 'Weekly', 'Overall'
  final _habitRepository = HabitRepository();
  List<Habit> _habits = [];
  Map<String, String> _habitLogs = {}; // habit_id -> status (Today)
  Map<String, Map<String, String>> _weeklyLogs =
      {}; // habit_id -> date -> status
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHabitsAndLogs();
  }

  Future<void> _fetchHabitsAndLogs() async {
    try {
      final habits = await _habitRepository.getHabits();
      final today = DateTime.now();

      // Fetch today's logs
      final logs = await _habitRepository.getHabitLogsForDate(today);

      // Fetch weekly logs (current week Mon-Sun)
      final now = DateTime.now();
      final currentWeekday = now.weekday; // 1 (Mon) to 7 (Sun)
      final weekStart = now.subtract(Duration(days: currentWeekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final rangeLogs = await _habitRepository.getHabitLogsForRange(
        weekStart,
        weekEnd,
      );

      if (mounted) {
        setState(() {
          _habits = habits;
          _habitLogs = logs;
          _weeklyLogs = rangeLogs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<bool?> _onDismiss(
    DismissDirection direction,
    Habit habit,
    String? currentStatus,
  ) async {
    // ... existing dismiss logic ...
    // For brevity, keeping the logic but minimizing duplication if possible
    // Re-using the exact logic from before
    final today = DateTime.now();
    String? newStatus;

    if (direction == DismissDirection.startToEnd) {
      if (currentStatus == 'completed')
        newStatus = null;
      else
        newStatus = 'completed';
    } else if (direction == DismissDirection.endToStart) {
      if (currentStatus == 'skipped')
        newStatus = null;
      else
        newStatus = 'skipped';
    }

    try {
      if (newStatus == null) {
        await _habitRepository.deleteLog(habit.id!, today);
        if (mounted) setState(() => _habitLogs.remove(habit.id!));
      } else {
        await _habitRepository.logHabit(habit.id!, today, newStatus);
        if (mounted) setState(() => _habitLogs[habit.id!] = newStatus!);
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex == 1) {
      return Scaffold(
        body: const StatisticsScreen(),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    // Sort habits
    final sortedHabits = List<Habit>.from(_habits);
    sortedHabits.sort((a, b) {
      final aStatus = _habitLogs[a.id];
      final bStatus = _habitLogs[b.id];
      if (aStatus == null && bStatus != null) return -1;
      if (aStatus != null && bStatus == null) return 1;
      return 0;
    });

    // Calculate progress
    int completedCount = _habitLogs.values
        .where((s) => s == 'completed')
        .length;
    int totalCount = _habits.length; // Or active habits
    double progress = totalCount == 0 ? 0 : completedCount / totalCount;

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
            onPressed: _navigateAndRefresh, // Top right add button
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              children: [
                // Custom Tab Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      _buildTabChip('Today'),
                      const SizedBox(width: 12),
                      _buildTabChip('Weekly'),
                      const SizedBox(width: 12),
                      _buildTabChip('Overall'),
                    ],
                  ),
                ),

                // Progress Bar (Only visible on Today tab usually, but good overall)
                if (_currentTab == 'Today')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[800],
                          color: const Color(
                            0xFFFF5757,
                          ), // Red/Pinkish as in ref
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$completedCount completed • ${_habitLogs.values.where((s) => s == 'skipped').length} skipped',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                Expanded(
                  child: _currentTab == 'Today'
                      ? _buildTodayList(sortedHabits)
                      : _currentTab == 'Weekly'
                      ? _buildWeeklyList(_habits)
                      : const Center(
                          child: Text(
                            'Overall Coming Soon',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildTabChip(String label) {
    final isActive = _currentTab == label;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.grey[900]
              : Colors.transparent, // Active is darker bg
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayList(List<Habit> habits) {
    if (habits.isEmpty) {
      return const Center(
        child: Text('No habits yet', style: TextStyle(color: Colors.white54)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final status = _habitLogs[habit.id];
        return Dismissible(
          key: Key(habit.id!),
          confirmDismiss: (direction) => _onDismiss(direction, habit, status),
          background: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Icon(
                  status == 'completed' ? Icons.undo : Icons.check,
                  color: Colors.black,
                ),
                const SizedBox(width: 8),
                Text(
                  status == 'completed' ? 'un-check' : 'kelarin',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF5757),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  status == 'skipped' ? 'un-skip' : 'skip dlu',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  status == 'skipped' ? Icons.undo : Icons.close,
                  color: Colors.white,
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          child: HabitCard(habit: habit, status: status),
        );
      },
    );
  }

  Widget _buildWeeklyList(List<Habit> habits) {
    // Current week logic
    final now = DateTime.now();
    final currentWeekday = now.weekday;
    final weekStart = now.subtract(Duration(days: currentWeekday - 1));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: habits.length,
      itemBuilder: (context, index) {
        final habit = habits[index];
        final logs = _weeklyLogs[habit.id] ?? {};
        return WeeklyHabitCard(
          habit: habit,
          weeklyLogs: logs,
          weekStart: weekStart,
        );
      },
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      backgroundColor: AppTheme.surface,
      selectedItemColor: AppTheme.primary,
      unselectedItemColor: Colors.white54,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
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

  Future<void> _navigateAndRefresh() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateHabitScreen()),
    );
    _fetchHabitsAndLogs();
  }
}
