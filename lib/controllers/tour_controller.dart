import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TourController extends GetxController {
  final SharedPreferences _prefs = Get.find<SharedPreferences>();

  // Keys for SharedPreferences
  static const String _keyHomeTour = 'tour_home_shown';
  static const String _keyHabitDetailTour = 'tour_habit_detail_shown';
  static const String _keySocialTour = 'tour_social_shown';
  static const String _keyStatisticsTour = 'tour_statistics_shown';

  // Global Keys for Home Screen
  final GlobalKey keyHomeProfile = GlobalKey();
  final GlobalKey keyHomeGamification = GlobalKey();
  final GlobalKey keyHomeDate = GlobalKey();
  final GlobalKey keyHomeHabitCard = GlobalKey();
  final GlobalKey keyHomeFab = GlobalKey();

  // Global Keys for Habit Detail Screen
  final GlobalKey keyDetailStats = GlobalKey();
  final GlobalKey keyDetailJournal = GlobalKey();
  final GlobalKey keyDetailCalendar = GlobalKey();

  // Global Keys for Social Screen
  final GlobalKey keySocialFeed = GlobalKey();
  final GlobalKey keySocialRank = GlobalKey();
  final GlobalKey keySocialCircle = GlobalKey();
  final GlobalKey keySocialStory = GlobalKey();
  final GlobalKey keySocialSearch =
      GlobalKey(); // Assuming search functionality/button

  // Global Keys for Statistics Screen
  final GlobalKey keyStatsPeriod = GlobalKey();
  final GlobalKey keyStatsSummary =
      GlobalKey(); // Combined/renamed from keyStatsOverall if needed, or just add new
  final GlobalKey keyStatsHeatmap = GlobalKey();
  final GlobalKey keyStatsChart = GlobalKey();

  bool _isTourShown(String key) {
    return _prefs.getBool(key) ?? false;
  }

  // Reactive state for Home Tour to trigger UI updates (e.g. remove dummy card)
  final RxBool isHomeTourShown = false.obs;
  // Reactive state for Social Tour
  final RxBool isSocialTourShown = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Initialize reactive state
    isHomeTourShown.value = _isTourShown(_keyHomeTour);
    isSocialTourShown.value = _isTourShown(_keySocialTour);
  }

  Future<void> _markTourShown(String key) async {
    await _prefs.setBool(key, true);
    if (key == _keyHomeTour) {
      isHomeTourShown.value = true;
    } else if (key == _keySocialTour) {
      isSocialTourShown.value = true;
    }
  }

  Future<void> resetAllTours() async {
    await _prefs.remove(_keyHomeTour);
    await _prefs.remove(_keyHabitDetailTour);
    await _prefs.remove(_keySocialTour);
    await _prefs.remove(_keySocialTour);
    await _prefs.remove(_keyStatisticsTour);
    isHomeTourShown.value = false; // Reset reactive state
    isSocialTourShown.value = false;
    Get.snackbar(
      "Tour Reset",
      "Semua tutorial telah di-reset. Restart aplikasi atau pindah layar untuk melihatnya lagi.",
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  void startHomeTour(BuildContext context) {
    if (_isTourShown(_keyHomeTour)) return;

    List<TargetFocus> targets = [];

    // 1. Welcome / Profile
    if (keyHomeProfile.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_profile",
          keyTarget: keyHomeProfile,
          title: "Selamat datang di Strik!",
          description:
              "Aplikasi ini membantu kamu membangun kebiasaan baik. Cek profilmu di sini.",
          align: ContentAlign.bottom,
          alignSkip: Alignment.bottomRight,
        ),
      );
    }

    // 2. Date Selector
    if (keyHomeDate.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_date",
          keyTarget: keyHomeDate,
          title: "Timeline",
          description:
              "Pilih tanggal di sini untuk melihat atau menargetkan kebiasaan di hari lain.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 3. Habit Card
    // Note: This key needs to be attached to the first item if available
    if (keyHomeHabitCard.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_habit_card",
          keyTarget: keyHomeHabitCard,
          title: "Kartu Kebiasaan",
          description:
              "Tap buat selesein, Tekan agak lama buat liat detailnya.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 4. FAB
    if (keyHomeFab.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_fab",
          keyTarget: keyHomeFab,
          title: "Tambah Kebiasaan",
          description:
              "Mulai perjalananmu dengan membuat kebiasaan baru di sini.",
          align: ContentAlign.top,
        ),
      );
    }

    if (targets.isNotEmpty) {
      _showTutorial(context, targets, _keyHomeTour);
    }
  }

  void startDefaultHomeTour(BuildContext context) {
    if (_isTourShown(_keyHomeTour)) return;

    List<TargetFocus> targets = [];

    // 1. Welcome / Profile
    if (keyHomeProfile.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_profile",
          keyTarget: keyHomeProfile,
          title: "Selamat datang di Strik!",
          description: "Mulai perjalananmu dengan mengatur profilmu di sini.",
          align: ContentAlign.bottom,
          alignSkip: Alignment.bottomRight,
        ),
      );
    }

    // 2. Gamification / XP Card
    if (keyHomeGamification.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_gamification",
          keyTarget: keyHomeGamification,
          title: "Level & XP",
          description:
              "Pantau level dan progress XP kamu di sini. Tap untuk detail reward!",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 3. Tab Selector (Harian/Mingguan)
    if (keyHomeDate.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_tab",
          keyTarget: keyHomeDate,
          title: "Mode Tampilan",
          description:
              "Ganti tampilan antara daftar harian atau ringkasan mingguan di sini.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 4. Habit Card
    if (keyHomeHabitCard.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_habit_card",
          keyTarget: keyHomeHabitCard,
          title: "Kartu Kebiasaan",
          description:
              "Geser kanan (Swipe Right) 👉 buat sikat habit.\nGeser kiri (Swipe Left) 👈 buat skip habit.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 4. Add Button
    if (keyHomeFab.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "home_add",
          keyTarget: keyHomeFab,
          title: "Tambah Kebiasaan",
          description: "Tambahkan kebiasaan barumu di sini.",
          align: ContentAlign.bottom,
        ),
      );
    }

    if (targets.isNotEmpty) {
      _showTutorial(context, targets, _keyHomeTour);
    }
  }

  void startHabitDetailTour(BuildContext context) {
    if (_isTourShown(_keyHabitDetailTour)) return;

    List<TargetFocus> targets = [];

    // 1. Stats
    if (keyDetailStats.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "detail_stats",
          keyTarget: keyDetailStats,
          title: "Statistik",
          description: "Pantau konsistensi dan streak-mu di sini.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 2. Calendar
    if (keyDetailCalendar.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "detail_calendar",
          keyTarget: keyDetailCalendar,
          title: "Kalender",
          description:
              "• Tap tanggal: Tandai selesai/batal\n• Tahan tanggal: Isi jurnal harian",
          align: ContentAlign.top,
        ),
      );
    }

    // 3. Journal
    if (keyDetailJournal.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "detail_journal",
          keyTarget: keyDetailJournal,
          title: "Jurnal Habit",
          description:
              "Catat perasaan atau evaluasi harianmu terkait kebiasaan ini. AI Coach siap bantuin!",
          align: ContentAlign.top,
        ),
      );
    }

    if (targets.isNotEmpty) {
      _showTutorial(context, targets, _keyHabitDetailTour);
    }
  }

  void startSocialTour(BuildContext context) {
    if (_isTourShown(_keySocialTour)) return;

    List<TargetFocus> targets = [];

    // 2. Feed
    if (keySocialFeed.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "social_feed",
          keyTarget: keySocialFeed,
          title: "Feed Teman",
          description:
              "Lihat progres teman-temanmu dan saling memotivasi di sini.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 3. Rank
    if (keySocialRank.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "social_rank",
          keyTarget: keySocialRank,
          title: "Leaderboard",
          description: "Cek siapa yang paling rajin minggu ini!",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 4. Circle
    if (keySocialCircle.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "social_circle",
          keyTarget: keySocialCircle,
          title: "Circle",
          description: "Kelola teman dan circle-mu di sini.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 5. Story
    if (keySocialStory.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "social_story",
          keyTarget: keySocialStory,
          title: "Momentz",
          description: "Bagikan pencapaian harianmu lewat Momentz!",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 3. Search / Add Friend
    if (keySocialSearch.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "social_search",
          keyTarget: keySocialSearch,
          title: "Cari Teman",
          description: "Cari teman untuk berjuang bersama.",
          align: ContentAlign.bottom,
        ),
      );
    }

    if (targets.isNotEmpty) {
      _showTutorial(context, targets, _keySocialTour);
    }
  }

  void startStatisticsTour(BuildContext context) {
    if (_isTourShown(_keyStatisticsTour)) return;

    List<TargetFocus> targets = [];

    // 1. Period Filter
    if (keyStatsPeriod.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "stats_period",
          keyTarget: keyStatsPeriod,
          title: "Filter Periode",
          description:
              "Atur rentang waktu statistikmu: Mingguan, Bulanan, atau Tahunan.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 2. Summary Stats
    if (keyStatsSummary.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "stats_summary",
          keyTarget: keyStatsSummary,
          title: "Ringkasan Performa",
          description:
              "Lihat total kebiasaan yang selesai, persentase keberhasilan, dan insight menarik lainnya.",
          align: ContentAlign.bottom,
        ),
      );
    }

    // 3. Heatmap
    if (keyStatsHeatmap.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "stats_heatmap",
          keyTarget: keyStatsHeatmap,
          title: "Jejak Keaktifan",
          description:
              "Visualisasi konsistensimu. Semakin terang warnanya, semakin rajin kamu!",
          align: ContentAlign.top,
        ),
      );
    }

    // 4. Chart
    if (keyStatsChart.currentContext != null) {
      targets.add(
        _buildTarget(
          identify: "stats_chart",
          keyTarget: keyStatsChart,
          title: "Grafik Batang",
          description: "Analisis tren produktivitasmu dari waktu ke waktu.",
          align: ContentAlign.top,
        ),
      );
    }

    if (targets.isNotEmpty) {
      _showTutorial(context, targets, _keyStatisticsTour);
    }
  }

  TargetFocus _buildTarget({
    required String identify,
    required GlobalKey keyTarget,
    required String title,
    required String description,
    ContentAlign align = ContentAlign.bottom,
    AlignmentGeometry alignSkip = Alignment.topRight,
    VoidCallback? onShow,
  }) {
    return TargetFocus(
      identify: identify,
      keyTarget: keyTarget,
      alignSkip: alignSkip,
      enableOverlayTab: true,
      contents: [
        TargetContent(
          align: align,
          builder: (context, controller) {
            if (onShow != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => onShow());
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    description,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
      shape: ShapeLightFocus.RRect,
      radius: 10,
    );
  }

  void _handleScrollForNextStep(TargetFocus target) {
    // If finishing Stats, scroll to Calendar
    if (target.identify == "detail_stats") {
      if (keyDetailCalendar.currentContext != null) {
        Scrollable.ensureVisible(
          keyDetailCalendar.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }
    // If finishing Calendar, scroll to Journal
    if (target.identify == "detail_calendar") {
      if (keyDetailJournal.currentContext != null) {
        Scrollable.ensureVisible(
          keyDetailJournal.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }
  }

  void _showTutorial(
    BuildContext context,
    List<TargetFocus> targets,
    String tourKey,
  ) {
    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        _markTourShown(tourKey);
      },
      onClickTarget: (target) {
        _handleScrollForNextStep(target);
      },
      onClickTargetWithTapPosition: (target, tapDetails) {
        // print("target: $target");
      },
      onClickOverlay: (target) {
        _handleScrollForNextStep(target);
      },
      onSkip: () {
        _markTourShown(tourKey);
        return true;
      },
    ).show(context: context);
  }
}
