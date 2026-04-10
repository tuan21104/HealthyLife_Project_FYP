import 'package:flutter/material.dart';

class ModalEffects {
  static Future<T?> showScaleFadeDialog<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color barrierColor = const Color(0x8A000000),
    Duration transitionDuration = const Duration(milliseconds: 300),
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: transitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(child: Builder(builder: builder));
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final CurvedAnimation curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
          reverseCurve: Curves.easeInOut,
        );

        final Animation<double> scale = Tween<double>(
          begin: 0.9,
          end: 1.0,
        ).animate(curved);

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: scale, child: child),
        );
      },
    );
  }

  static Future<T?> showAppBottomSheet<T>({
    required BuildContext context,
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool useSafeArea = true,
    Color backgroundColor = Colors.white,
    double topRadius = 28,
    ShapeBorder? shape,
    AnimationController? transitionAnimationController,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      useSafeArea: useSafeArea,
      backgroundColor: backgroundColor,
      transitionAnimationController: transitionAnimationController,
      shape:
          shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(topRadius),
            ),
          ),
      builder: builder,
    );
  }
}
