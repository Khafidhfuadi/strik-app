import 'package:flutter/material.dart';
import 'package:strik_app/main.dart';
import 'package:strik_app/screens/create_habit_screen.dart';
import 'package:strik_app/core/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/widgets/habit_card.dart';
import 'package:strik_app/screens/statistics_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final _habitRepository = HabitRepository();
  List<Habit> _habits = [];
  Map<String, String> _habitLogs = {}; // habit_id -> status
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHabitsAndLogs();
  }

  Future<void> _fetchHabitsAndLogs() async {
    try {
      final habits = await _habitRepository.getHabits();
      final logs = await _habitRepository.getHabitLogsForDate(DateTime.now());

      if (mounted) {
        setState(() {
          _habits = habits;
          _habitLogs = logs;
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

  // Handle Swipe logic
  Future<bool?> _onDismiss(
    DismissDirection direction,
    Habit habit,
    String? currentStatus,
  ) async {
    final today = DateTime.now();
    String? newStatus;

    // Swipe Right -> Complete
    if (direction == DismissDirection.startToEnd) {
      if (currentStatus == 'completed') {
        // Already completed, swipe right again to undo? Or maybe ignore?
        // User request says "complete/un-complete (swipe right)"
        newStatus = null; // Un-complete
      } else {
        newStatus = 'completed';
      }
    }
    // Swipe Left -> Skip
    else if (direction == DismissDirection.endToStart) {
      if (currentStatus == 'skipped') {
        newStatus = null; // Un-skip
      } else {
        newStatus = 'skipped';
      }
    }

    try {
      if (newStatus == null) {
        await _habitRepository.deleteLog(habit.id!, today);
        if (mounted) {
          setState(() {
            _habitLogs.remove(habit.id!);
          });
        }
      } else {
        await _habitRepository.logHabit(habit.id!, today, newStatus);
        if (mounted) {
          setState(() {
            _habitLogs[habit.id!] = newStatus!;
          });
        }
      }
      return false; // Don't remove from list, just update state
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort habits: Incomplete first, then Completed/Skipped
    final sortedHabits = List<Habit>.from(_habits);
    sortedHabits.sort((a, b) {
      final aStatus = _habitLogs[a.id];
      final bStatus = _habitLogs[b.id];

      if (aStatus == null && bStatus != null) return -1;
      if (aStatus != null && bStatus == null) return 1;
      return 0;
    });

    // If index 1, show statistics (placeholder)
    if (_selectedIndex == 1) {
      return Scaffold(
        body: const StatisticsScreen(),
        bottomNavigationBar: _buildBottomNavigationBar(),
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
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _habits.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Belum ada kebiasaan nih',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _navigateAndRefresh,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Bikin Baru'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: sortedHabits.length,
              itemBuilder: (context, index) {
                final habit = sortedHabits[index];
                final status = _habitLogs[habit.id];

                return Dismissible(
                  key: Key(habit.id!),
                  confirmDismiss: (direction) =>
                      _onDismiss(direction, habit, status),
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary, // Greenish for check
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
                      color: const Color(0xFFFF5757), // Reddish for skip
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
            ),
      floatingActionButton: _habits.isNotEmpty
          ? FloatingActionButton(
              onPressed: _navigateAndRefresh,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      bottomNavigationBar: _buildBottomNavigationBar(),
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

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
  }
}
