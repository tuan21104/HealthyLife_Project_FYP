import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

String trSafe(
  BuildContext context,
  String key, {
  required String vi,
  required String en,
  Map<String, String>? namedArgs,
}) {
  final translated = namedArgs == null
      ? key.tr()
      : key.tr(namedArgs: namedArgs);
  if (translated != key) return translated;

  var fallback = context.locale.languageCode == 'vi' ? vi : en;
  if (namedArgs != null) {
    namedArgs.forEach((k, v) {
      fallback = fallback.replaceAll('{$k}', v);
    });
  }
  return fallback;
}
