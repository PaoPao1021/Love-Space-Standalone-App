import '../../core/network/api_client.dart';

class WellnessRepository {
  const WellnessRepository({required this.apiClient});
  final ApiClient apiClient;

  Future<FitnessDashboard> dashboard() async =>
      FitnessDashboard.fromJson(await _fitness('dashboard'));

  Future<void> saveGoal({
    required String goalType,
    required int weeklyWorkouts,
    required int dailySteps,
    required String privacy,
    double? currentWeight,
    double? targetWeight,
    double? height,
    int? age,
    String biologicalSex = '',
  }) => _fitness('saveGoal', {
    'goalType': goalType,
    'weeklyWorkouts': weeklyWorkouts,
    'dailySteps': dailySteps,
    'privacy': privacy,
    'currentWeight': ?currentWeight,
    'targetWeight': ?targetWeight,
    'height': ?height,
    'age': ?age,
    if (biologicalSex.isNotEmpty) 'biologicalSex': biologicalSex,
  });

  Future<void> checkIn({
    required String workoutType,
    required int minutes,
    required int calories,
    required int steps,
    required int water,
    required double sleep,
    required bool healthyMeal,
    double? weight,
  }) => _fitness('checkIn', {
    'workoutType': workoutType,
    'minutes': minutes,
    'calories': calories,
    'steps': steps,
    'water': water,
    'sleep': sleep,
    'healthyMeal': healthyMeal,
    'weight': ?weight,
  });

  Future<void> createChallenge(String presetId) =>
      _fitness('createChallenge', {'presetId': presetId});

  Future<WeeklyFitnessReport> weeklyReport(int offset) async =>
      WeeklyFitnessReport.fromJson(
        await _fitness('weeklyReport', {'offset': offset}),
      );

  Future<MonthlyReport> monthlyReport(int year, int month) async =>
      MonthlyReport.fromJson(
        await apiClient.post(
          '/api/v1/functions/monthly-report',
          body: {'year': year, 'month': month},
        ),
      );

  Future<Map<String, dynamic>> _fitness(
    String action, [
    Map<String, Object?> data = const {},
  ]) => apiClient.post(
    '/api/v1/functions/fitness',
    body: {'action': action, 'data': data},
  );
}

class FitnessDashboard {
  const FitnessDashboard({
    required this.teamProgress,
    required this.myStats,
    required this.partnerStats,
    required this.goalConfigured,
    required this.goalType,
    required this.weeklyWorkouts,
    required this.dailySteps,
    required this.privacy,
    required this.todayCheckin,
    required this.partnerCheckedIn,
    required this.challenges,
    required this.challengePresets,
    this.currentWeight,
    this.targetWeight,
    this.height,
    this.age,
    this.biologicalSex = '',
    this.nutritionPlan = const NutritionPlan(),
  });

  factory FitnessDashboard.fromJson(Map<String, dynamic> json) {
    final goal = _map(json['myGoal']);
    return FitnessDashboard(
      teamProgress: _integer(json['teamProgress']),
      myStats: FitnessStats.fromJson(_map(json['myStats'])),
      partnerStats: json['partnerStats'] == null
          ? null
          : FitnessStats.fromJson(_map(json['partnerStats'])),
      goalConfigured: goal['configured'] as bool? ?? false,
      goalType: _text(goal['goalType'], 'fat-loss'),
      weeklyWorkouts: _integer(goal['weeklyWorkouts'], 3),
      dailySteps: _integer(goal['dailySteps'], 8000),
      privacy: _text(goal['privacy'], 'trend'),
      currentWeight: _nullableNumber(goal['currentWeight']),
      targetWeight: _nullableNumber(goal['targetWeight']),
      height: _nullableNumber(goal['height']),
      age: _nullableInteger(goal['age']),
      biologicalSex: _text(goal['biologicalSex']),
      nutritionPlan: NutritionPlan.fromJson(_map(json['nutritionPlan'])),
      todayCheckin: json['todayCheckin'] == null
          ? null
          : DailyCheckin.fromJson(_map(json['todayCheckin'])),
      partnerCheckedIn: json['partnerCheckedIn'] as bool? ?? false,
      challenges: _maps(
        json['challenges'],
      ).map(FitnessChallenge.fromJson).toList(growable: false),
      challengePresets: _maps(
        json['challengePresets'],
      ).map(FitnessChallengePreset.fromJson).toList(growable: false),
    );
  }

  final int teamProgress;
  final FitnessStats myStats;
  final FitnessStats? partnerStats;
  final bool goalConfigured;
  final String goalType;
  final int weeklyWorkouts;
  final int dailySteps;
  final String privacy;
  final DailyCheckin? todayCheckin;
  final bool partnerCheckedIn;
  final List<FitnessChallenge> challenges;
  final List<FitnessChallengePreset> challengePresets;
  final double? currentWeight;
  final double? targetWeight;
  final double? height;
  final int? age;
  final String biologicalSex;
  final NutritionPlan nutritionPlan;
}

class NutritionPlan {
  const NutritionPlan({
    this.ready = false,
    this.message = '',
    this.calories = 0,
    this.summary = '',
    this.macros = const [],
    this.disclaimer = '',
  });
  factory NutritionPlan.fromJson(Map<String, dynamic> json) => NutritionPlan(
    ready: json['ready'] as bool? ?? false,
    message: _text(json['message']),
    calories: _integer(json['calories']),
    summary: _text(json['summary']),
    macros: _maps(json['macros']).map(NutritionMacro.fromJson).toList(),
    disclaimer: _text(json['disclaimer']),
  );
  final bool ready;
  final String message;
  final int calories;
  final String summary;
  final List<NutritionMacro> macros;
  final String disclaimer;
}

class NutritionMacro {
  const NutritionMacro({required this.name, required this.grams});
  factory NutritionMacro.fromJson(Map<String, dynamic> json) => NutritionMacro(
    name: _text(json['label'], _text(json['name'])),
    grams: _integer(json['grams'], _integer(json['value'])),
  );
  final String name;
  final int grams;
}

class FitnessChallenge {
  const FitnessChallenge({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.unit,
    required this.percent,
    required this.status,
  });
  factory FitnessChallenge.fromJson(Map<String, dynamic> json) =>
      FitnessChallenge(
        id: _text(json['_id']).isNotEmpty
            ? _text(json['_id'])
            : _text(json['id']),
        title: _text(json['title']),
        current: _integer(json['current']),
        target: _integer(json['target'], 1),
        unit: _text(json['unit']),
        percent: _integer(json['percent']),
        status: _text(json['status']),
      );
  final String id;
  final String title;
  final int current;
  final int target;
  final String unit;
  final int percent;
  final String status;
}

class FitnessChallengePreset {
  const FitnessChallengePreset({required this.id, required this.title});
  factory FitnessChallengePreset.fromJson(Map<String, dynamic> json) =>
      FitnessChallengePreset(
        id: _text(json['id']),
        title: _text(json['title']),
      );
  final String id;
  final String title;
}

class FitnessStats {
  const FitnessStats({
    required this.progress,
    required this.checkinDays,
    required this.workouts,
    required this.minutes,
    required this.totalSteps,
  });
  factory FitnessStats.fromJson(Map<String, dynamic> json) => FitnessStats(
    progress: _integer(json['progress']),
    checkinDays: _integer(json['checkinDays']),
    workouts: _integer(json['workouts']),
    minutes: _integer(json['minutes']),
    totalSteps: _integer(json['totalSteps']),
  );
  final int progress;
  final int checkinDays;
  final int workouts;
  final int minutes;
  final int totalSteps;
}

class DailyCheckin {
  const DailyCheckin({
    required this.workoutType,
    required this.minutes,
    required this.steps,
    required this.water,
    required this.sleep,
    required this.healthyMeal,
    this.weight,
  });
  factory DailyCheckin.fromJson(Map<String, dynamic> json) => DailyCheckin(
    workoutType: _text(json['workoutType'], 'rest'),
    minutes: _integer(json['minutes']),
    steps: _integer(json['steps']),
    water: _integer(json['water']),
    sleep: _number(json['sleep']),
    healthyMeal: json['healthyMeal'] as bool? ?? false,
    weight: _nullableNumber(json['weight']),
  );
  final String workoutType;
  final int minutes;
  final int steps;
  final int water;
  final double sleep;
  final bool healthyMeal;
  final double? weight;
}

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.connectionScore,
    required this.moodDays,
    required this.questionDays,
    required this.moments,
    required this.photos,
    required this.points,
  });
  factory MonthlyReport.fromJson(Map<String, dynamic> json) {
    final report = _map(json['report']);
    final mood = _map(report['mood']);
    final questions = _map(report['questions']);
    final moments = _map(report['moments']);
    final points = _map(report['points']);
    return MonthlyReport(
      year: _integer(report['year']),
      month: _integer(report['month']),
      connectionScore: _integer(report['connectionScore']),
      moodDays: _integer(mood['together']),
      questionDays: _integer(questions['together']),
      moments: _integer(moments['count']),
      photos: _integer(moments['photos']),
      points: _integer(points['total']),
    );
  }
  final int year;
  final int month;
  final int connectionScore;
  final int moodDays;
  final int questionDays;
  final int moments;
  final int photos;
  final int points;
}

class WeeklyFitnessReport {
  const WeeklyFitnessReport({
    required this.start,
    required this.end,
    required this.teamScore,
    required this.headline,
    required this.insight,
    required this.bestHabit,
    required this.workouts,
    required this.totalMinutes,
    required this.totalCalories,
    required this.totalSteps,
    required this.activeDays,
    required this.members,
  });
  factory WeeklyFitnessReport.fromJson(Map<String, dynamic> json) {
    final report = _map(json['report']);
    final range = _map(report['range']);
    return WeeklyFitnessReport(
      start: _date(range['start']),
      end: _date(range['end']),
      teamScore: _integer(report['teamScore']),
      headline: _text(report['headline']),
      insight: _text(report['insight']),
      bestHabit: _text(report['bestHabit']),
      workouts: _integer(report['workouts']),
      totalMinutes: _integer(report['totalMinutes']),
      totalCalories: _integer(report['totalCalories']),
      totalSteps: _integer(report['totalSteps']),
      activeDays: _integer(report['activeDays']),
      members: _maps(
        report['members'],
      ).map(WeeklyFitnessMember.fromJson).toList(growable: false),
    );
  }
  final DateTime start;
  final DateTime end;
  final int teamScore;
  final String headline;
  final String insight;
  final String bestHabit;
  final int workouts;
  final int totalMinutes;
  final int totalCalories;
  final int totalSteps;
  final int activeDays;
  final List<WeeklyFitnessMember> members;
}

class WeeklyFitnessMember {
  const WeeklyFitnessMember({required this.name, required this.stats});
  factory WeeklyFitnessMember.fromJson(Map<String, dynamic> json) =>
      WeeklyFitnessMember(
        name: _text(json['name'], 'TA'),
        stats: FitnessStats.fromJson(_map(json['stats'])),
      );
  final String name;
  final FitnessStats stats;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};
List<Map<String, dynamic>> _maps(Object? value) =>
    (value as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
String _text(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();
int _integer(Object? value, [int fallback = 0]) =>
    value is num ? value.toInt() : int.tryParse(_text(value)) ?? fallback;
double _number(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : double.tryParse(_text(value)) ?? fallback;
DateTime _date(Object? value) =>
    DateTime.tryParse(_text(value)) ?? DateTime.now();
int? _nullableInteger(Object? value) => value == null ? null : _integer(value);
double? _nullableNumber(Object? value) => value == null ? null : _number(value);
