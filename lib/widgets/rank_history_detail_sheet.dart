import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

class RankHistoryDetailSheet extends StatelessWidget {
  final Map<String, dynamic> log;

  const RankHistoryDetailSheet({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final amount = (log['amount'] as num).toDouble();
    final isPositive = amount > 0;
    final date = DateTime.parse(log['created_at']).toLocal();
    final reason = log['reason'] ?? 'XP Adjustment';
    final referenceId = log['reference_id'] as String?;
    final transactionId = log['id'] as String;
    final habitTitle = log['habit_title'] as String?;

    // Use habit title as primary display if reason is habit-related
    String displayTitle = reason;
    if (habitTitle != null) {
      if (reason == 'Completed Habit') displayTitle = 'Completed: $habitTitle';
      if (reason == 'Skipped Habit') displayTitle = 'Skipped: $habitTitle';
      if (reason == 'New Habit') displayTitle = 'New Habit: $habitTitle';
    }

    String formatXP(double val) {
      if (val == val.roundToDouble()) {
        return val.toInt().toString();
      }
      return val.toStringAsFixed(1);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF1B3A2B)
                      : const Color(0xFF3A1B1B),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isPositive ? Colors.greenAccent : Colors.redAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, dd MMM yyyy • HH:mm').format(date),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailItem(
            'Amount',
            '${isPositive ? '+' : ''}${formatXP(amount)} XP',
            isPositive,
          ),
          const Divider(color: Colors.white10, height: 32),
          if (referenceId != null) ...[
            _buildDetailItem('Reference ID', referenceId, null),
            const SizedBox(height: 16),
          ],
          _buildDetailItem('Transaction ID', transactionId, null),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, bool? isPositive) {
    Color valueColor = Colors.white;
    if (isPositive != null) {
      valueColor = isPositive ? const Color(0xFFFFD700) : Colors.redAccent;
    } else {
      valueColor = Colors.white70;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontFamily: isPositive != null ? 'Space Grotesk' : null,
              fontWeight: isPositive != null
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: isPositive != null ? 18 : 14,
              color: valueColor,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
