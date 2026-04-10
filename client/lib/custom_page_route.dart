import 'package:flutter/material.dart';

class CustomPageRoute<T> extends PageRouteBuilder<T> {
  CustomPageRoute({required Widget page})
    : super(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final Animation<Offset> slideAnimation =
              Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              );

          final Animation<double> fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          );

          return SlideTransition(
            position: slideAnimation,
            child: FadeTransition(opacity: fadeAnimation, child: child),
          );
        },
      );
}
