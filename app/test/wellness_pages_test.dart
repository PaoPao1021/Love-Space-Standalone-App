import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/wellness/fitness_page.dart';
import 'package:lovespace_app/features/wellness/monthly_report_page.dart';
import 'package:lovespace_app/features/wellness/weekly_report_page.dart';
import 'package:lovespace_app/features/wellness/wellness_repository.dart';

void main() {
  testWidgets('fitness dashboard fits a small phone with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(colorSchemeSeed: const Color(0xFFBE185D)),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: FitnessPage(repository: _FakeWellnessRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本周双人进度'), findsOneWidget);
    expect(find.text('更新今天的记录'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('monthly report fits phone landscape in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(812, 375);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MonthlyReportPage(repository: _FakeWellnessRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月默契值 / 100'), findsOneWidget);
    expect(find.text('一起回答'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weekly report keeps both partners readable at 375px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: WeeklyReportPage(repository: _FakeWellnessRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本周状态不错，继续一起动一动'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(find.text('我'), findsOneWidget);
    expect(find.text('TA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeWellnessRepository extends WellnessRepository {
  _FakeWellnessRepository()
    : super(apiClient: ApiClient(tokenStore: TokenStore()));

  @override
  Future<FitnessDashboard> dashboard() async => const FitnessDashboard(
    teamProgress: 68,
    myStats: FitnessStats(
      progress: 72,
      checkinDays: 4,
      workouts: 3,
      minutes: 120,
      totalSteps: 36000,
    ),
    partnerStats: FitnessStats(
      progress: 64,
      checkinDays: 3,
      workouts: 2,
      minutes: 90,
      totalSteps: 30000,
    ),
    goalConfigured: true,
    goalType: 'shape',
    weeklyWorkouts: 3,
    dailySteps: 8000,
    privacy: 'trend',
    todayCheckin: DailyCheckin(
      workoutType: 'walk',
      minutes: 30,
      steps: 7000,
      water: 6,
      sleep: 7.5,
      healthyMeal: true,
    ),
    partnerCheckedIn: true,
    challenges: [],
    challengePresets: [],
  );

  @override
  Future<MonthlyReport> monthlyReport(int year, int month) async =>
      MonthlyReport(
        year: year,
        month: month,
        connectionScore: 82,
        moodDays: 12,
        questionDays: 15,
        moments: 6,
        photos: 18,
        points: 45,
      );

  @override
  Future<WeeklyFitnessReport> weeklyReport(int weekOffset) async =>
      WeeklyFitnessReport(
        start: DateTime(2026, 8, 31),
        end: DateTime(2026, 9, 6),
        teamScore: 76,
        headline: '本周状态不错，继续一起动一动',
        insight: '你们都在稳定记录步数。',
        bestHabit: '每天散步',
        workouts: 5,
        totalMinutes: 210,
        totalCalories: 860,
        totalSteps: 66000,
        activeDays: 5,
        members: const [
          WeeklyFitnessMember(
            name: '我',
            stats: FitnessStats(
              progress: 80,
              checkinDays: 4,
              workouts: 3,
              minutes: 120,
              totalSteps: 36000,
            ),
          ),
          WeeklyFitnessMember(
            name: 'TA',
            stats: FitnessStats(
              progress: 72,
              checkinDays: 3,
              workouts: 2,
              minutes: 90,
              totalSteps: 30000,
            ),
          ),
        ],
      );
}
