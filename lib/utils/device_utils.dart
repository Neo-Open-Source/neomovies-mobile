import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DeviceUtils {
  /// Returns true if the device should be considered a tablet based on screen size.
  /// Uses 600dp shortestSide threshold which is a common heuristic.
  static bool isTablet(BuildContext context) {
    final shortestSide = MediaQuery.of(context).size.shortestSide;
    return shortestSide >= 600;
  }

  /// Very naive Android TV detection. Treats a device as TV if it runs Android
  /// and has extremely large width (>= 950dp) and is in landscape.
  static bool isAndroidTv(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final size = MediaQuery.of(context).size;
    return size.shortestSide >= 950 && size.aspectRatio > 1.4;
  }

  static bool isLargeScreen(BuildContext context) {
    return isTablet(context) || isAndroidTv(context);
  }

  /// Calculates responsive grid column count depending on screen width.
  static int calculateGridCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 6;
    if (width >= 1200) return 5;
    if (width >= 900) return 4;
    if (width >= 600) return 3;
    return 2;
  }
}
