import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamily = 'Roboto';
  static const Color titleColor = Color(0xFF111827);
  static const Color bodyColor = Color(0xFF374151);
  static const Color mutedColor = Color(0xFF6B7280);

  static const TextStyle pageTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: titleColor,
    height: 1.15,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: titleColor,
    height: 1.15,
  );

  static const TextStyle subtitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: mutedColor,
    height: 1.35,
  );

  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: bodyColor,
    height: 1.35,
  );

  static const TextStyle small = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: mutedColor,
    height: 1.25,
  );
}

class AppTheme {
  static ThemeData light() {
    final base = Typography.material2021(
      platform: defaultTargetPlatform,
    ).black.apply(fontFamily: AppTypography.fontFamily);

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF4CAF50),
        brightness: Brightness.light,
      ),
      textTheme: base,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTypography.titleColor),
        titleTextStyle: AppTypography.pageTitle,
      ),
    );
  }
}
