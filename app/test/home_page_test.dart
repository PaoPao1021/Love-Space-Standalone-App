import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lovespace_app/core/auth/auth_models.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/account_cache.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/anniversary/anniversary_repository.dart';
import 'package:lovespace_app/features/core_loop/core_loop_repository.dart';
import 'package:lovespace_app/features/home/home_page.dart';
import 'package:lovespace_app/features/shell/app_shell.dart';
import 'package:lovespace_app/theme/lovespace_theme.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0]) {
    testWidgets(
      'reference home uses live summary data and four tabs at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = _HomeApi();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => AppShell(
                currentIndex: 0,
                child: HomePage(
                  user: const LoveSpaceUser(
                    id: 'a',
                    username: 'a',
                    nickname: '小鹿',
                    avatarUrl: '',
                    coupleId: 'c',
                    role: 'creator',
                  ),
                  anniversaryRepository: AnniversaryRepository(apiClient: api),
                  coreLoopRepository: CoreLoopRepository(
                    apiClient: api,
                    cache: AccountCache(),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/daily-question',
              builder: (_, _) => const Scaffold(body: Text('问答详情')),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          MaterialApp.router(theme: LoveSpaceTheme.light, routerConfig: router),
        );
        await tester.pumpAndSettle();
        expect(find.text('小鹿 & 小熊'), findsOneWidget);
        expect(find.text('从 2024.05.20 开始，认真相爱'), findsOneWidget);
        expect(find.text('今天，靠近一点'), findsOneWidget);
        expect(find.text('相册'), findsOneWidget);
        expect(find.text('一起'), findsNothing);
        expect(find.text('本周共同完成 60%'), findsOneWidget);
        expect(find.text('60%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('进入问答'));
        await tester.pumpAndSettle();
        expect(find.text('问答详情'), findsOneWidget);
      },
    );
  }
}

class _HomeApi extends ApiClient {
  _HomeApi() : super(tokenStore: TokenStore());
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final action = (body as Map?)?['action'];
    if (path.endsWith('/couple')) {
      return {
        'couple': {'startDate': '2024-05-20'},
        'partner': {'nickName': '小熊', 'avatarUrl': ''},
      };
    }
    if (path.endsWith('/anniversary')) return {'list': <Object>[]};
    if (path.endsWith('/daily-question')) {
      return {
        'question': '今天哪一个瞬间让你想到我？',
        'category': '日常连接',
        'partnerAnswered': true,
      };
    }
    if (path.endsWith('/mood')) {
      return {
        'data': {'moodType': action == 'getToday' ? 'happy' : 'love'},
      };
    }
    if (path.endsWith('/moments')) {
      return {'list': <Object>[], 'hasMore': false};
    }
    if (path.endsWith('/notification')) {
      return {'list': <Object>[], 'unreadCount': 0};
    }
    if (path.endsWith('/fitness')) {
      return {
        'teamProgress': 60,
        'myStats': {'workouts': 3},
        'partnerCheckedIn': true,
      };
    }
    if (path.endsWith('/points')) return {'myScore': 600, 'partnerScore': 600};
    throw StateError('Unexpected request $path $body');
  }
}
