import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/data/models/habit.dart';
import 'package:strik_app/widgets/custom_text_field.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:strik_app/controllers/create_habit_controller.dart';
import 'package:flutter/services.dart';

class CreateHabitScreen extends StatelessWidget {
  final Habit? habit;
  const CreateHabitScreen({super.key, this.habit});

  @override
  Widget build(BuildContext context) {
    // Put the controller
    final controller = Get.put(CreateHabitController());

    // Initialize if editing
    if (habit != null) {
      controller.initFromHabit(habit!);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            children: [
              TextSpan(text: controller.isEdit ? 'Edit ' : 'Bikin '),
              const TextSpan(
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
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomTextField(
                controller: controller.titleController,
                label: 'Nama Kebiasaan',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller.descriptionController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Detailnya, Coy?',
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
                    GestureDetector(
                      onTap: () {
                        Get.bottomSheet(
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: const BoxDecoration(
                              color: AppTheme.surface,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Pilih Warna',
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 16,
                                  alignment: WrapAlignment.center,
                                  children: List.generate(
                                    controller.colors.length,
                                    (index) {
                                      return GestureDetector(
                                        onTap: () {
                                          controller.selectedColorIndex.value =
                                              index;
                                          Get.back();
                                        },
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: controller.colors[index],
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.2,
                                              ),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Obx(
                                  () => Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color:
                                          controller.colors[controller
                                              .selectedColorIndex
                                              .value],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Warna Kebiasaan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: Colors.white54,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildSectionContainer(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tampilkan di Feed',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Bisa pamerin update habit ini ke temanmu',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                    Obx(
                      () => Switch(
                        value: controller.isPublic.value,
                        onChanged: controller.isChallengeEnabled.value
                            ? null
                            : (value) => controller.isPublic.value = value,
                        activeThumbColor: Colors.white,
                        activeTrackColor: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ===== HABIT CHALLENGE SECTION =====
              _buildSectionContainer(
                child: Obx(
                  () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Habit Challenge',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Tantang dirimu bersama circlemu!',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: controller.isChallengeEnabled.value,
                            onChanged: controller.isEdit
                                ? null
                                : (val) {
                                    controller.isChallengeEnabled.value = val;
                                    if (val) {
                                      controller.isPublic.value = true;
                                      controller.hasEndDate.value = true;
                                    }
                                  },
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                      if (controller.isChallengeEnabled.value) ...[
                        if (controller
                            .generatedInviteCode
                            .value
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFFF59E0B,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.link,
                                  color: Color(0xFFF59E0B),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Kode: ${controller.generatedInviteCode.value}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                        text: controller
                                            .generatedInviteCode
                                            .value,
                                      ),
                                    );
                                    Get.snackbar(
                                      'Tersalin!',
                                      'Kode undangan berhasil disalin',
                                      snackPosition: SnackPosition.BOTTOM,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Salin',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
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
                        Obx(
                          () => Switch(
                            value: controller.isRepeat.value,
                            onChanged: (value) =>
                                controller.isRepeat.value = value,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Obx(() {
                      if (controller.isRepeat.value) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[800],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Row(
                                children: List.generate(
                                  controller.frequencies.length,
                                  (index) {
                                    return Expanded(
                                      child: Obx(() {
                                        final isSelected =
                                            controller
                                                .selectedFrequencyIndex
                                                .value ==
                                            index;
                                        return GestureDetector(
                                          onTap: () =>
                                              controller
                                                      .selectedFrequencyIndex
                                                      .value =
                                                  index,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppTheme.primary
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              controller.frequencies[index],
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
                                        );
                                      }),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Frequency Specific Content
                            if (controller.selectedFrequencyIndex.value ==
                                0) ...[
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(
                                  controller.days.length,
                                  (index) {
                                    return Obx(() {
                                      final isSelected = controller.selectedDays
                                          .contains(index);
                                      return GestureDetector(
                                        onTap: () =>
                                            controller.toggleDay(index),
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
                                            controller.days[index],
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.black
                                                  : Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ),
                            ] else if (controller
                                    .selectedFrequencyIndex
                                    .value ==
                                1) ...[
                              // Weekly
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                            if (controller
                                                    .weeklyFrequency
                                                    .value >
                                                1) {
                                              controller
                                                  .weeklyFrequency
                                                  .value--;
                                            }
                                          },
                                        ),
                                        Obx(
                                          () => Text(
                                            '${controller.weeklyFrequency.value}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.add,
                                            color: Colors.white,
                                          ),
                                          onPressed: () {
                                            if (controller
                                                    .weeklyFrequency
                                                    .value <
                                                7) {
                                              controller
                                                  .weeklyFrequency
                                                  .value++;
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Obx(() {
                                if (controller.weeklyFrequency.value == 7) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      'Tiap hari dong!',
                                      style: TextStyle(
                                        color: AppTheme.primary,
                                        fontSize: 14,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              }),
                            ] else if (controller
                                    .selectedFrequencyIndex
                                    .value ==
                                2) ...[
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
                                  return Obx(() {
                                    final isSelected = controller
                                        .selectedMonthlyDates
                                        .contains(day);
                                    return GestureDetector(
                                      onTap: () =>
                                          controller.toggleMonthlyDate(day),
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
                                  });
                                }),
                              ),
                            ],
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
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
                          'Kapan Berakhir?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Obx(
                          () => Switch(
                            value: controller.hasEndDate.value,
                            onChanged: controller.isChallengeEnabled.value
                                ? null
                                : (val) => controller.hasEndDate.value = val,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Obx(() {
                      if (controller.hasEndDate.value) {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey[800]),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () async {
                                final now = DateTime.now();
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      controller.endDate.value ??
                                      now.add(const Duration(days: 30)),
                                  firstDate: now,
                                  lastDate: now.add(
                                    const Duration(days: 365 * 5),
                                  ),
                                  builder: (context, child) {
                                    return Theme(
                                      data: ThemeData.dark().copyWith(
                                        colorScheme: ColorScheme.dark(
                                          primary: AppTheme.primary,
                                          onPrimary: Colors.black,
                                          surface: AppTheme.surface,
                                          onSurface: Colors.white,
                                        ),
                                        dialogTheme: DialogThemeData(
                                          backgroundColor: AppTheme.surface,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  controller.endDate.value = date;
                                }
                              },
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Pilih Tanggal',
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
                                    child: Obx(
                                      () => Text(
                                        controller.endDate.value != null
                                            ? '${controller.endDate.value!.day}/${controller.endDate.value!.month}/${controller.endDate.value!.year}'
                                            : 'Pilih',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
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
                        Obx(
                          () => Switch(
                            value: controller.isReminder.value,
                            onChanged: controller.setReminder,
                            activeThumbColor: Colors.white,
                            activeTrackColor: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Obx(() {
                      if (controller.isReminder.value) {
                        return Column(
                          children: [
                            const SizedBox(height: 12),
                            Divider(color: Colors.grey[800]),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => controller.pickTime(context),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                    child: Obx(
                                      () => Text(
                                        controller.reminderTime.value?.format(
                                              context,
                                            ) ??
                                            'Pilih Jam',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Obx(
                () => PrimaryButton(
                  text: controller.isEdit ? 'Simpan Perubahan!' : 'Gas Simpen!',
                  isLoading: controller.isLoading.value,
                  onPressed: controller.saveHabit,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
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
