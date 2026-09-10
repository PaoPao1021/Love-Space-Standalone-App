import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/account_cache.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/core_loop/core_loop.dart';
import 'package:lovespace_app/features/core_loop/core_loop_repository.dart';
import 'package:lovespace_app/features/daily_question/daily_question_page.dart';
import 'package:lovespace_app/theme/lovespace_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('question keeps privacy hint usable at 375px and large text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'lovespace.account.user-a.daily.answer.draft': '离线草稿',
    });
    final cache = AccountCache()..scopeTo('user-a');
    await tester.binding.setSurfaceSize(const Size(375, 667));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 667),
          textScaler: TextScaler.linear(1.6),
        ),
        child: MaterialApp(
          theme: LoveSpaceTheme.dark,
          home: DailyQuestionPage(
            repository: _QuestionRepository(cache),
            cache: cache,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我的回答'), findsOneWidget);
    expect(find.text('离线草稿'), findsOneWidget);
    expect(find.textContaining('先独立作答'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _QuestionRepository extends CoreLoopRepository {
  _QuestionRepository(AccountCache cache)
    : super(
        apiClient: ApiClient(tokenStore: TokenStore()),
        cache: cache,
      );
  @override
  Future<DailyQuestion> getDailyQuestion() async => const DailyQuestion(
    question: '今天最想和 TA 一起完成什么？',
    category: '连接',
    myAnswer: null,
    partnerAnswer: null,
    partnerAnswered: false,
    bothAnswered: false,
  );
}
