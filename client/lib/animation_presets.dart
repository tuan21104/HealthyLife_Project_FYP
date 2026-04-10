import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppListMotion {
  static const Duration itemDuration = Duration(milliseconds: 320);
  static const int staggerMs = 100;
  static const Curve curve = Curves.easeInOut;
  static const double defaultBeginY = 0.18;

  static Duration delayFor(int index) {
    return Duration(milliseconds: index * staggerMs);
  }
}

extension StaggerListAnimation on Widget {
  Widget withStagger(int index, {double beginY = AppListMotion.defaultBeginY}) {
    return animate(delay: AppListMotion.delayFor(index))
        .fade(duration: AppListMotion.itemDuration, curve: AppListMotion.curve)
        .slideY(
          begin: beginY,
          end: 0,
          duration: AppListMotion.itemDuration,
          curve: AppListMotion.curve,
        );
  }
}
