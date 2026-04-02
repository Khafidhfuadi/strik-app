import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:strik_app/controllers/habit_detail_controller.dart';
import 'package:strik_app/controllers/habit_journal_controller.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/widgets/ai_response_loading_state.dart';

class CoachStrikAiScreen extends StatelessWidget {
  const CoachStrikAiScreen({
    super.key,
    required this.habit,
    required this.detailController,
    required this.journalController,
  });

  final Habit habit;
  final HabitDetailController detailController;
  final HabitJournalController journalController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Coach Strik AI',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              habit.title,
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Obx(() {
          final focusedMonth = journalController.focusedMonth.value;
          final monthStats = _buildMonthlyStats(focusedMonth);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(focusedMonth),
                const SizedBox(height: 16),
                _buildMonthSwitcher(focusedMonth),
                const SizedBox(height: 16),
                _buildOverviewGrid(monthStats),
                const SizedBox(height: 16),
                _buildInsightSection(context, focusedMonth, monthStats),
              ],
            ),
          );
        }),
      ),
    );
  }

  Map<String, dynamic> _buildMonthlyStats(DateTime focusedMonth) {
    final monthLogs = detailController.logs.where((log) {
      final rawDate = log['target_date'] as String?;
      if (rawDate == null || rawDate.isEmpty) return false;

      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate == null) return false;

      return parsedDate.year == focusedMonth.year &&
          parsedDate.month == focusedMonth.month;
    }).toList();

    final completed = monthLogs.where((log) => log['status'] == 'completed');
    final skipped = monthLogs.where((log) => log['status'] == 'skipped');
    final totalLogs = monthLogs.length;

    return {
      'total_logs': totalLogs,
      'completed': completed.length,
      'skipped': skipped.length,
      'rate': totalLogs > 0
          ? (completed.length / totalLogs * 100).toStringAsFixed(1)
          : '0',
    };
  }

  Widget _buildHeroCard(DateTime focusedMonth) {
    final hasInsight = journalController.aiInsightHistory.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.92),
            const Color(0xFFE9FF7A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Insight Bulanan',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.black,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasInsight
                ? 'Insight ${DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth)} sudah siap dibaca.'
                : 'Coach siap baca pola habit kamu untuk ${DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth)}.',
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.15,
            ),
          ),
          // const SizedBox(height: 10),
          // Text(
          //   hasInsight
          //       ? 'Semua analisis, kuota, dan tombol regenerate sekarang dikumpulin di satu tempat biar lebih fokus dan enak dibaca.'
          //       : 'Begitu jurnal bulan ini cukup, Coach Strik bakal bantu nangkap pola, hambatan, dan saran paling relevan buat habit ini.',
          //   style: TextStyle(
          //     fontFamily: 'Plus Jakarta Sans',
          //     fontSize: 13,
          //     height: 1.5,
          //     color: Colors.black.withValues(alpha: 0.72),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _buildMonthSwitcher(DateTime focusedMonth) {
    final now = DateTime.now();
    final isCurrentMonth =
        focusedMonth.year == now.year && focusedMonth.month == now.month;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _buildMonthButton(
            icon: Icons.arrow_back_rounded,
            onTap: () {
              detailController.changeMonth(-1);
              journalController.updateFocusMonth(
                detailController.focusedMonth.value,
              );
            },
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth),
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih bulan yang mau kamu review bareng Coach.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          _buildMonthButton(
            icon: Icons.arrow_forward_rounded,
            isDisabled: isCurrentMonth,
            onTap: isCurrentMonth
                ? null
                : () {
                    detailController.changeMonth(1);
                    journalController.updateFocusMonth(
                      detailController.focusedMonth.value,
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(
          icon,
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.22)
              : AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildOverviewGrid(Map<String, dynamic> monthStats) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Jurnal',
                value: '${journalController.monthlyJournalCount.value}/10',
                helper: journalController.isEligibleForAI.value
                    ? 'Siap dianalisis'
                    : 'Butuh ${10 - journalController.monthlyJournalCount.value} lagi',
                accent: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: 'Kuota',
                value:
                    '${(3 - journalController.aiQuotaUsed.value).clamp(0, 3)}x',
                helper: 'Sisa bulan ini',
                accent: const Color(0xFF6EE7B7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Completion',
                value: '${monthStats['completed']}x',
                helper: 'Dari ${monthStats['total_logs']} log',
                accent: const Color(0xFF60A5FA),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                label: 'Success Rate',
                value: '${monthStats['rate']}%',
                helper: 'Bulan aktif ini',
                accent: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String helper,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightSection(
    BuildContext context,
    DateTime focusedMonth,
    Map<String, dynamic> monthStats,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ruang Insight',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Coach bakal ngerangkum jurnal dan progres ${DateFormat('MMMM yyyy', 'id_ID').format(focusedMonth)} jadi insight yang lebih personal.',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (journalController.isGeneratingAI.value)
            AiResponseLoadingState(
              title: 'Coach lagi baca jurnal kamu',
              headline:
                  'Insight bulanan lagi dirangkai dari catatan dan progres kamu.',
              helperText:
                  'Aku lagi nyari pola yang sering muncul, momen kamu lagi kuat, dan titik yang paling sering bikin pace kamu turun.',
              phases: [
                'Nyusun recap jurnal bulan ini',
                'Nemuin pola yang paling berulang',
                'Ngerapihin insight biar enak dibaca',
              ],
            )
          else if (journalController.aiInsight.value.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInsightVersionHeader(),
                  const SizedBox(height: 16),
                  _buildStyledText(journalController.aiInsight.value),
                ],
              ),
            )
          else if (!journalController.isEligibleForAI.value)
            _buildLockedState()
          else
            _buildReadyState(),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: journalController.isGeneratingAI.value
                  ? null
                  : journalController.isEligibleForAI.value
                  ? () => _confirmGenerateAi(context, monthStats)
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: journalController.isEligibleForAI.value
                    ? AppTheme.primary
                    : Colors.white.withValues(alpha: 0.08),
                foregroundColor: journalController.isEligibleForAI.value
                    ? Colors.black
                    : Colors.white.withValues(alpha: 0.4),
                disabledBackgroundColor: journalController.isEligibleForAI.value
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.08),
                disabledForegroundColor: journalController.isEligibleForAI.value
                    ? AppTheme.textPrimary
                    : Colors.white.withValues(alpha: 0.4),
              ),
              child: Text(
                journalController.aiInsightHistory.isEmpty
                    ? 'Generate Insight'
                    : 'Regenerate Insight',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            journalController.isGeneratingAI.value
                ? 'Coach lagi kerja. Begitu selesai, insight langsung nongol di halaman ini.'
                : journalController.isEligibleForAI.value
                ? 'Generate akan memakai 1 kuota untuk bulan ini.'
                : 'Buka akses insight dengan minimal 10 jurnal di bulan aktif.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: AppTheme.textSecondary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Insight belum kebuka',
                style: TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tulis minimal 10 jurnal di bulan aktif supaya Coach Strik punya konteks yang cukup buat ngasih analisis yang personal dan kepake.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Semua syarat buat analisis bulan ini udah siap.',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tekan generate kalau kamu mau Coach Strik ngerangkum pola paling kuat, hambatan yang sering muncul, dan langkah next move yang paling relevan.',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 13,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmGenerateAi(
    BuildContext context,
    Map<String, dynamic> monthStats,
  ) {
    if (journalController.aiQuotaUsed.value >= 3) {
      Get.snackbar(
        'Limit Habis',
        'Jatah coach bulan ini udah kepake semua. Tunggu bulan depan ya! 🌚',
        backgroundColor: Colors.red.withValues(alpha: 0.1),
        colorText: Colors.redAccent,
      );
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Minta Saran Coach Strik AI?',
          style: TextStyle(
            fontFamily: 'Space Grotesk',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tindakan ini bakal pake 1 kuota generate kamu.',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sisa Kuota: ${(3 - journalController.aiQuotaUsed.value).clamp(0, 3)}x lagi (Bulan ini)',
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                color: Colors.white60,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              journalController.generateAiInsight(habit.title, monthStats);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Lanjut Gas!',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyledText(String text) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }

    final spans = <TextSpan>[];
    final exp = RegExp(r'(\*{1,2})(.*?)(\1)', dotAll: true);
    final matches = exp.allMatches(text);

    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 14,
              height: 1.65,
            ),
          ),
        );
      }

      spans.add(
        TextSpan(
          text: match.group(2),
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.65,
          ),
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex),
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 14,
            height: 1.65,
          ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildInsightVersionHeader() {
    final currentVersion = journalController.currentAiInsightVersion;
    final totalVersions = journalController.aiInsightHistory.length;
    final currentIndex = journalController.selectedAiInsightIndex.value;
    final displayOrder = totalVersions - currentIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                currentIndex == 0
                    ? 'Versi Terbaru'
                    : 'Versi $displayOrder dari $totalVersions',
                style: const TextStyle(
                  fontFamily: 'Space Grotesk',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            if (totalVersions > 1)
              Text(
                '$totalVersions hasil generate',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
        if (currentVersion != null) ...[
          const SizedBox(height: 10),
          Text(
            'Dibuat ${DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(currentVersion.createdAt)}',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.58),
            ),
          ),
        ],
        if (totalVersions > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildVersionArrow(
                icon: Icons.arrow_back_rounded,
                onTap: journalController.hasOlderAiInsight
                    ? journalController.showOlderAiInsight
                    : null,
              ),
              const SizedBox(width: 8),
              _buildVersionArrow(
                icon: Icons.arrow_forward_rounded,
                onTap: journalController.hasNewerAiInsight
                    ? journalController.showNewerAiInsight
                    : null,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildVersionArrow({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Icon(
          icon,
          size: 20,
          color: isDisabled
              ? Colors.white.withValues(alpha: 0.22)
              : AppTheme.textPrimary,
        ),
      ),
    );
  }
}
