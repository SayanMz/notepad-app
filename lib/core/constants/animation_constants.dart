class AnimationConstants {
  AnimationConstants._();

  // Core motion timings
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration extraSlow = Duration(milliseconds: 500);
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration tiny = Duration(milliseconds: 100);
  static const Duration appBarQuick = Duration(milliseconds: 150);
  static const Duration snappy = Duration(milliseconds: 250);
  static const Duration morph = Duration(milliseconds: 350);
  static const Duration long = Duration(milliseconds: 600);
  static const Duration extraLong = Duration(milliseconds: 800);
  static const Duration verySlow = Duration(milliseconds: 1200);

  // Shared delays and timeouts
  static const Duration debounceStandard = Duration(milliseconds: 300);
  static const Duration saveIndicator = Duration(seconds: 3);
  static const Duration snackbarShort = Duration(seconds: 2);
  static const Duration snackbarLong = Duration(seconds: 4);
  static const Duration colorWheelSpin = Duration(seconds: 10);
  static const Duration voiceRequestTimeout = Duration(seconds: 20);
}
