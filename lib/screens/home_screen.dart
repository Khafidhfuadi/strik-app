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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHabits();
  }

  Future<void> _fetchHabits() async {
    try {
      final habits = await _habitRepository.getHabits();
      setState(() {
        _habits = habits;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading habits: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              itemCount: _habits.length,
              itemBuilder: (context, index) {
                return HabitCard(habit: _habits[index]);
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
    _fetchHabits();
  }

  Future<void> _signOut(BuildContext context) async {
    await supabase.auth.signOut();
  }
}
