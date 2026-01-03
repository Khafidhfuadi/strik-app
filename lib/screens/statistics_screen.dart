import 'package:flutter/material.dart';
import 'package:strik_app/core/theme.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Statistik'),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Statistik Coming Soon!',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
