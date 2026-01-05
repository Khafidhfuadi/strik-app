import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';
import 'package:alarm/alarm.dart';
import 'package:intl/intl.dart';

class AlarmManagementScreen extends StatefulWidget {
  const AlarmManagementScreen({super.key});

  @override
  State<AlarmManagementScreen> createState() => _AlarmManagementScreenState();
}

class _AlarmManagementScreenState extends State<AlarmManagementScreen> {
  List<AlarmSettings> _activeAlarms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() => _isLoading = true);
    try {
      final alarms = await Alarm.getAlarms();
      // Sort by time
      alarms.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      setState(() {
        _activeAlarms = alarms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat alarm: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Alarm Mendatang',
          style: TextStyle(fontFamily: 'Space Grotesk', color: Colors.white),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeAlarms.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadAlarms,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _activeAlarms.length,
                itemBuilder: (context, index) {
                  final alarm = _activeAlarms[index];
                  return _buildAlarmCard(alarm);
                },
              ),
            ),
    );
  }

  Widget _buildAlarmCard(AlarmSettings alarm) {
    final now = DateTime.now();
    final isToday =
        alarm.dateTime.year == now.year &&
        alarm.dateTime.month == now.month &&
        alarm.dateTime.day == now.day;

    final dateStr = isToday
        ? 'Hari Ini'
        : DateFormat('EEEE, d MMM', 'id_ID').format(alarm.dateTime);
    final timeStr = DateFormat('HH:mm').format(alarm.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Optional: Show details or edit
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.alarm, color: AppTheme.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.notificationSettings.title,
                        style: const TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$dateStr • $timeStr',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm_on, size: 48, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tidak Ada Alarm Aktif',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Buat habit dengan reminder untuk\nmelihat jadwal disini',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
