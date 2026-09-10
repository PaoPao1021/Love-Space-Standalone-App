import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/account_cache.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/core_loop/core_loop.dart';
import 'package:lovespace_app/features/core_loop/core_loop_repository.dart';
import 'package:lovespace_app/features/mood/mood_page.dart';
import 'package:lovespace_app/features/quiz/quiz_page.dart';
import 'package:lovespace_app/features/thanks/thanks_page.dart';
import 'package:lovespace_app/features/timeline/timeline_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('quiz keeps partner answer hidden until both have answered', (
    tester,
  ) async {
    await _phone(tester, QuizPage(repository: _ConnectionRepository()));

    expect(find.text('我已回答，等待 TA'), findsOneWidget);
    expect(find.textContaining('TA：'), findsNothing);
    expect(find.textContaining('双方都回答后'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thanks wall restores a readable memory list on a small phone', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final cache = AccountCache()..scopeTo('user-a');
    await _phone(
      tester,
      ThanksPage(repository: _ConnectionRepository(cache), cache: cache),
    );

    expect(find.text('谢谢你在我加班时留了晚饭'), findsOneWidget);
    expect(find.byTooltip('记录感谢'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('timeline groups memories by month with large text', (
    tester,
  ) async {
    await _phone(
      tester,
      TimelinePage(repository: _ConnectionRepository()),
      textScale: 1.35,
    );

    expect(find.text('2026 年 9 月'), findsOneWidget);
    expect(find.text('海边散步'), findsOneWidget);
    expect(find.byTooltip('记录此刻'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mood page shows the source partner-mood panel and all ten choices',
    (tester) async {
      await _phone(tester, MoodPage(repository: _ConnectionRepository()));

      expect(find.text('😊'), findsOneWidget);
      expect(find.text('😤'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('TA今天的心情'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('TA今天的心情'), findsOneWidget);
      expect(find.text('甜蜜'), findsAtLeastNWidgets(1));
      await tester.scrollUntilVisible(
        find.text('心情日历'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('心情日历'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _phone(
  WidgetTester tester,
  Widget home, {
  double textScale = 1.2,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

class _ConnectionRepository extends CoreLoopRepository {
  _ConnectionRepository([AccountCache? cache])
    : super(
        apiClient: ApiClient(tokenStore: TokenStore()),
        cache: cache ?? (AccountCache()..scopeTo('user-a')),
      );

  static final _moment = MomentEntry(
    id: 'moment-1',
    authorId: 'user-a',
    title: '海边散步',
    content: '谢谢你在我加班时留了晚饭',
    images: const [],
    tags: const ['感动'],
    eventDate: DateTime(2026, 9, 1),
    createdAt: DateTime(2026, 9, 1),
  );

  @override
  Future<List<QuizQuestion>> quizQuestions() async => const [
    QuizQuestion(question: '周末最想怎么过？', options: ['散步', '看电影']),
  ];

  @override
  Future<List<QuizEntry>> quizzes() async => const [
    QuizEntry(
      id: 'quiz-1',
      question: '周末最想怎么过？',
      myAnswer: '散步',
      partnerAnswer: '',
      partnerAnswered: false,
      bothAnswered: false,
      matched: false,
    ),
  ];

  @override
  Future<MomentPageResult> moments({int page = 1, String tag = ''}) async =>
      MomentPageResult(items: [_moment], hasMore: false);

  @override
  Future<MomentEntry?> randomMoment() async => _moment;

  @override
  Future<MoodEntry?> getMyMood() async => null;

  @override
  Future<MoodEntry?> getPartnerMood() async => MoodEntry(
    id: 'partner-mood',
    type: 'love',
    content: '今天也很想你',
    visibility: 'both',
    date: DateTime(2026, 9, 10),
    isMine: false,
  );

  @override
  Future<List<MoodEntry>> moodCalendar(DateTime month) async => const [];
}
