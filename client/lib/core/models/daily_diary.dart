class DailyDiary {
  DailyDiary({
    required this.userId,
    required this.date,
    required this.targetCalo,
    required this.targetCarb,
    required this.targetProtein,
    required this.targetFat,
    required this.waterIntake,
    required this.breakfast,
    required this.lunch,
    required this.snack,
    required this.dinner,
    required this.exercise,
  });

  final String userId;
  final String date;
  final double targetCalo;
  final double targetCarb;
  final double targetProtein;
  final double targetFat;
  final double waterIntake;
  final List<dynamic> breakfast;
  final List<dynamic> lunch;
  final List<dynamic> snack;
  final List<dynamic> dinner;
  final List<dynamic> exercise;

  factory DailyDiary.fromJson(Map<String, dynamic> json) {
    return DailyDiary(
      userId: (json['userId'] ?? '').toString(),
      date: (json['date'] ?? '').toString(),
      targetCalo: (json['targetCalo'] as num?)?.toDouble() ?? 1200,
      targetCarb: (json['targetCarb'] as num?)?.toDouble() ?? 150,
      targetProtein: (json['targetProtein'] as num?)?.toDouble() ?? 60,
      targetFat: (json['targetFat'] as num?)?.toDouble() ?? 40,
      waterIntake: (json['waterIntake'] as num?)?.toDouble() ?? 0,
      breakfast: (json['breakfast'] as List?) ?? const [],
      lunch: (json['lunch'] as List?) ?? const [],
      snack: (json['snack'] as List?) ?? const [],
      dinner: (json['dinner'] as List?) ?? const [],
      exercise: (json['exercise'] as List?) ?? const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'date': date,
      'targetCalo': targetCalo,
      'targetCarb': targetCarb,
      'targetProtein': targetProtein,
      'targetFat': targetFat,
      'waterIntake': waterIntake,
      'breakfast': breakfast,
      'lunch': lunch,
      'snack': snack,
      'dinner': dinner,
      'exercise': exercise,
    };
  }
}
