import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/wellness/wellness_repository.dart';

void main() {
  test('dashboard preserves workout detail and server-provided nutrition', () {
    final model = FitnessDashboard.fromJson({
      'todayCheckin': {
        'workouts': [
          {
            'id': 'w1',
            'type': 'walk',
            'startTime': '08:30',
            'minutes': 30,
            'calories': 120,
          },
        ],
      },
      'partnerToday': {
        'workouts': [
          {
            'id': 'p1',
            'type': 'run',
            'startTime': '19:00',
            'minutes': 20,
            'calories': 180,
          },
        ],
        'minutes': 20,
      },
      'nutritionPlan': {
        'ready': true,
        'calories': 2100,
        'bmr': {'ready': true, 'value': 1500, 'formula': 'Mifflin-St Jeor'},
        'workoutCalories': 120,
        'trainingRecovery': 80,
        'macros': [
          {'name': '蛋白质', 'grams': 110, 'ratio': 25, 'color': '#5f8f76'},
        ],
        'foodGroups': [
          {'name': '优质蛋白', 'foods': '鸡蛋、豆腐', 'note': '均匀分到三餐'},
        ],
      },
    });
    expect(model.todayCheckin!.workouts.single.startTime, '08:30');
    expect(model.partnerToday!.workouts.single.calories, 180);
    expect(model.partnerToday!.weight, isNull);
    expect(model.nutritionPlan.bmr, 1500);
    expect(model.nutritionPlan.foodGroups.single.foods, '鸡蛋、豆腐');
    expect(model.nutritionPlan.macros.single.percent, 25);
  });

  test(
    'weekly trend distinguishes withheld data from insufficient recordings',
    () {
      expect(FitnessStats.fromJson({}).weightTrendVisible, isFalse);
      final pending = FitnessStats.fromJson({'weightChange': null});
      expect(pending.weightTrendVisible, isTrue);
      expect(pending.weightChange, isNull);
      expect(FitnessStats.fromJson({'weightChange': -.4}).weightChange, -.4);
    },
  );

  test(
    'multi-workout save sends the server array contract without invented weight',
    () async {
      final api = _RecordingApi();
      await WellnessRepository(apiClient: api).checkInWorkouts(
        workouts: const [
          WorkoutEntry(
            id: 'w1',
            type: 'walk',
            startTime: '08:30',
            minutes: 30,
            calories: 120,
          ),
          WorkoutEntry(
            id: 'w2',
            type: 'strength',
            startTime: '18:00',
            minutes: 45,
            calories: 200,
          ),
        ],
        steps: 8000,
        water: 1500,
        sleep: 8,
        healthyMeal: true,
      );
      expect(api.path, '/api/v1/functions/fitness');
      final body = api.body! as Map<String, dynamic>;
      expect(body['action'], 'checkIn');
      final data = body['data'] as Map<String, Object?>;
      expect((data['workouts'] as List).length, 2);
      expect((data['workouts'] as List).last['type'], 'strength');
      expect(data.containsKey('weight'), isFalse);
    },
  );
}

class _RecordingApi extends ApiClient {
  _RecordingApi() : super(tokenStore: TokenStore());
  String? path;
  Object? body;
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    this.path = path;
    this.body = body;
    return {'code': 0};
  }
}
