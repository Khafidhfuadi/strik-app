class OnboardingData {
  final String title;
  final String description;
  final String lottieAsset;

  OnboardingData({
    required this.title,
    required this.description,
    required this.lottieAsset,
  });

  static List<OnboardingData> getOnboardingPages() {
    return [
      OnboardingData(
        title: 'Glow Up Bareng Yoks!',
        description:
            'Track kebiasaan lo tiap hari. Konsisten itu kunci buat jadi versi terbaik diri lo!',
        lottieAsset: 'assets/src/example-boarding.json',
      ),
      OnboardingData(
        title: 'Colek Circle',
        description:
            'Gas colek temen lo buat saling ngingetin dan support. Glow up bareng lebih seru kan?',
        lottieAsset: 'assets/src/example-boarding.json',
      ),
      OnboardingData(
        title: 'Pantau Progress',
        description:
            'Pantau perkembangan kebiasaan lo. Makin konsisten, makin deket sama goals!',
        lottieAsset: 'assets/src/example-boarding.json',
      ),
    ];
  }
}
