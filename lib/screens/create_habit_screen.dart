import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:strik_app/core/theme.dart';
import 'package:strik_app/widgets/custom_text_field.dart';
import 'package:strik_app/widgets/primary_button.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:strik_app/controllers/create_habit_controller.dart';

class CreateHabitScreen extends StatelessWidget {
  const CreateHabitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Put the controller
    final controller = Get.put(CreateHabitController());

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
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
                                style: GoogleFonts.spaceGrotesk(
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
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                          if (controller.selectedFrequencyIndex.value == 0) ...[
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
                              children: List.generate(controller.days.length, (
                                index,
                              ) {
                                return Obx(() {
                                  final isSelected = controller.selectedDays
                                      .contains(index);
                                  return GestureDetector(
                                    onTap: () => controller.toggleDay(index),
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
                              }),
                            ),
                          ] else if (controller.selectedFrequencyIndex.value ==
                              1) ...[
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
                                          if (controller.weeklyFrequency.value >
                                              1) {
                                            controller.weeklyFrequency.value--;
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
                                          if (controller.weeklyFrequency.value <
                                              7) {
                                            controller.weeklyFrequency.value++;
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
                          ] else if (controller.selectedFrequencyIndex.value ==
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
                text: 'Gas Simpen!',
                isLoading: controller.isLoading.value,
                onPressed: controller.saveHabit,
              ),
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
