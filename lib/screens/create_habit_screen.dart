import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/widgets/custom_text_field.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/data/repositories/habit_repository.dart';
import 'package:strik_app/main.dart'; // For supabase instance if needed directly, or auth

class CreateHabitScreen extends StatefulWidget {
  const CreateHabitScreen({super.key});

  @override
  State<CreateHabitScreen> createState() => _CreateHabitScreenState();
}

class _CreateHabitScreenState extends State<CreateHabitScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isRepeat = true;
  int _selectedFrequencyIndex = 0; // 0: Daily, 1: Weekly, 2: Monthly
  final List<String> _frequencies = ['Tiap Hari', 'Mingguan', 'Bulanan'];
  final List<String> _days = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
  final Set<int> _selectedDays = {0, 1, 2, 3, 4, 5, 6}; // Default all days

  // Weekly Frequency
  int _weeklyFrequency = 1;

  // Monthly Date Selection
  final Set<int> _selectedMonthlyDates = {};

  bool _isReminder = false;
  TimeOfDay? _reminderTime;

  // Colors
  final List<Color> _colors = [
    const Color(0xFF14B8A6), // Teal
    const Color(0xFF3B82F6), // Blue
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEC4899), // Pink
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFF10B981), // Emerald
  ];
  int _selectedColorIndex = 0;

  bool _isLoading = false;
  final _habitRepository = HabitRepository();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primary,
              onPrimary: Colors.black,
              surface: AppTheme.surface,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: AppTheme.surface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  Future<void> _saveHabit() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi nama kebiasaannya dulu dong bestie!'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      String frequency;
      List<int>? daysOfWeek;
      int? frequencyCount;

      if (!_isRepeat) {
        // Default to daily if repeat is off, or maybe handled differently?
        // Assuming "Repeat" switch effectively disables custom recurrence, maybe implies "One time"?
        // But schema says frequency is NOT NULL. Let's assume Daily with all days if off, or just standard Daily.
        // Actually, if Repeat is OFF, it might mean "Just once" or simply not a recurring habit?
        // The user prompt implied "Repeat" switch. Let's assume Daily for now but we might want to clarify.
        // For now, let's treat it as Daily.
        frequency = 'daily';
        daysOfWeek = [0, 1, 2, 3, 4, 5, 6];
      } else {
        // Map Indonesian labels back to English values for DB constraint
        final Map<int, String> frequencyMap = {
          0: 'daily',
          1: 'weekly',
          2: 'monthly',
        };
        frequency = frequencyMap[_selectedFrequencyIndex] ?? 'daily';

        if (_selectedFrequencyIndex == 0) {
          // Tiap Hari (Daily)
          daysOfWeek = _selectedDays.toList()..sort();
        } else if (_selectedFrequencyIndex == 1) {
          // Mingguan (Weekly)
          frequencyCount = _weeklyFrequency;
        } else if (_selectedFrequencyIndex == 2) {
          // Bulanan (Monthly)
          daysOfWeek = _selectedMonthlyDates.toList()..sort();
        }
      }

      final habit = Habit(
        userId: user.id,
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        color:
            '0x${_colors[_selectedColorIndex].value.toRadixString(16).toUpperCase()}',
        frequency: frequency,
        daysOfWeek: daysOfWeek,
        frequencyCount: frequencyCount,
        reminderTime: _reminderTime,
        reminderEnabled: _isReminder,
      );

      await _habitRepository.createHabit(habit);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Yah error: $e')));
        print(e);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            children: const [
              TextSpan(text: 'Bikin '),
              TextSpan(
                text: 'Kebiasaan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        centerTitle: false,
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextField(
              controller: _titleController,
              label: 'Nama Kebiasaan',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Detailnya, Bestie?',
                labelStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: AppTheme.surface,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Warnamu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _colors.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final isSelected = _selectedColorIndex == index;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedColorIndex = index),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _colors[index],
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionContainer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Diulang Gak?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _isRepeat,
                        onChanged: (value) => setState(() => _isRepeat = value),
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  if (_isRepeat) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: List.generate(_frequencies.length, (index) {
                          final isSelected = _selectedFrequencyIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(
                                () => _selectedFrequencyIndex = index,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _frequencies[index],
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.black
                                        : Colors.white60,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Frequency Specific Content
                    if (_selectedFrequencyIndex == 0) ...[
                      // Daily
                      const Text(
                        'Hari apa aja?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_days.length, (index) {
                          final isSelected = _selectedDays.contains(index);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedDays.remove(index);
                                } else {
                                  _selectedDays.add(index);
                                }
                              });
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey[800]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _days[index],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ] else if (_selectedFrequencyIndex == 1) ...[
                      // Weekly
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Berapa kali seminggu?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (_weeklyFrequency > 1) {
                                      setState(() => _weeklyFrequency--);
                                    }
                                  },
                                ),
                                Text(
                                  '$_weeklyFrequency',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (_weeklyFrequency < 7) {
                                      setState(() => _weeklyFrequency++);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_weeklyFrequency == 7)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Tiap hari dong!',
                            style: TextStyle(
                              color: AppTheme.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ] else if (_selectedFrequencyIndex == 2) ...[
                      // Monthly
                      const Text(
                        'Tanggal berapa aja?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(31, (index) {
                          final day = index + 1;
                          final isSelected = _selectedMonthlyDates.contains(
                            day,
                          );
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedMonthlyDates.remove(day);
                                } else {
                                  _selectedMonthlyDates.add(day);
                                }
                              });
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primary
                                    : AppTheme.surface,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primary
                                      : Colors.grey[800]!,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$day',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionContainer(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Ingetin Dong',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Switch(
                        value: _isReminder,
                        onChanged: (value) {
                          setState(() {
                            _isReminder = value;
                            if (_isReminder && _reminderTime == null) {
                              _reminderTime = const TimeOfDay(
                                hour: 9,
                                minute: 0,
                              );
                            }
                          });
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                      ),
                    ],
                  ),
                  if (_isReminder) ...[
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey[800]),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _selectTime,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Jam Berapa?',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[800],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _reminderTime?.format(context) ?? 'Pilih Jam',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            PrimaryButton(
              text: 'Gas Simpen!',
              isLoading: _isLoading,
              onPressed: _saveHabit,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
