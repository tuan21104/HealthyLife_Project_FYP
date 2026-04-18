import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class DiaryService {
  static String formatDate(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static String _localDiaryKey(DateTime date) => 'diary_${formatDate(date)}';

  static List<dynamic> _asList(dynamic value) {
    return value is List ? value : <dynamic>[];
  }

  static Map<String, dynamic> normalizeDiaryPayload(
    Map<String, dynamic> source,
  ) {
    return <String, dynamic>{
      'targetCalo': source['targetCalo'] ?? 1200,
      'targetCarb': source['targetCarb'] ?? 150,
      'targetProtein': source['targetProtein'] ?? 60,
      'targetFat': source['targetFat'] ?? 40,
      'waterIntake': source['waterIntake'] ?? 0,
      'breakfast': _asList(source['breakfast']),
      'lunch': _asList(source['lunch']),
      'snack': _asList(source['snack']),
      'dinner': _asList(source['dinner']),
      'exercise': _asList(source['exercise']),
    };
  }

  static Future<Map<String, dynamic>?> loadLocalDiary(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localDiaryKey(date));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> saveLocalDiary(
    DateTime date,
    Map<String, dynamic> diaryData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _localDiaryKey(date),
      jsonEncode(normalizeDiaryPayload(diaryData)),
    );
  }

  static Future<void> updateLocalWaterIntake({
    required DateTime date,
    required double waterIntake,
  }) async {
    final existing = await loadLocalDiary(date) ?? <String, dynamic>{};
    final merged = normalizeDiaryPayload(existing)
      ..['waterIntake'] = waterIntake.isFinite && waterIntake >= 0
          ? waterIntake
          : 0.0;
    await saveLocalDiary(date, merged);
  }

  static Future<Map<String, dynamic>?> loadLatestDiary({
    required String userId,
    required DateTime date,
    bool preferCloudForToday = true,
  }) async {
    final localData = await loadLocalDiary(date);
    final formattedDate = formatDate(date);
    final shouldHitCloudFirst = preferCloudForToday && isToday(date);

    if (shouldHitCloudFirst) {
      final cloudData = await AuthService.getDiaryFromCloud(
        userId,
        formattedDate,
      );
      if (cloudData != null) {
        await saveLocalDiary(date, cloudData);
        return cloudData;
      }
      return localData;
    }

    if (localData != null) return localData;

    final cloudData = await AuthService.getDiaryFromCloud(
      userId,
      formattedDate,
    );
    if (cloudData != null) {
      await saveLocalDiary(date, cloudData);
    }
    return cloudData;
  }

  static Future<bool> syncDiaryPayload({
    required String userId,
    required DateTime date,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final normalized = normalizeDiaryPayload(payload);
      final requestBody = <String, dynamic>{
        'userId': userId,
        'date': formatDate(date),
        ...normalized,
      };

      final response = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/api/diary/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await saveLocalDiary(date, normalized);
        return true;
      }
    } catch (_) {}
    return false;
  }
}
