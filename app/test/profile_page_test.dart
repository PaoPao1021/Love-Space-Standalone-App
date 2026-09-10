import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/auth/auth_controller.dart';
import 'package:lovespace_app/core/auth/auth_repository.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/push/push_client.dart';
import 'package:lovespace_app/core/storage/account_cache.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/core_loop/core_loop_repository.dart';
import 'package:lovespace_app/features/profile/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [320.0, 375.0]) {
    testWidgets('profile header and featured cards fit ${width.toInt()}px at large text', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 720);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final api = _ProfileApi();
      final auth = AuthController(repository: AuthRepository(apiClient: api, tokenStore: _TokenStore()));
      await auth.initialize();
      final user = auth.user!;
      final cache = AccountCache()..scopeTo(user.id);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
        home: ProfilePage(user: user, authController: auth, repository: _ProfileRepository(api), cache: cache, pushClient: _Push()),
      ));
      await tester.pumpAndSettle();

      expect(find.text('OUR SPACE'), findsOneWidget);
      expect(find.text('阿月  &  小星'), findsOneWidget);
      expect(find.text('共同走过 939 天'), findsOneWidget);
      expect(find.text('今日问答'), findsOneWidget);
      expect(find.text('关系月报'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

class _TokenStore extends TokenStore {
  @override Future<String?> readAccessToken() async => 'token';
}

class _ProfileApi extends ApiClient {
  _ProfileApi() : super(tokenStore: _TokenStore());
  static const _user = {'_id': 'me', 'username': 'moon', 'nickName': '阿月', 'avatarUrl': '', 'coupleId': 'couple-1', 'role': 'creator'};
  @override Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) async => {'code': 0, 'userInfo': _user};
  @override Future<Map<String, dynamic>> post(String path, {Object? body, bool authenticated = true}) async {
    if (path == '/api/v1/functions/couple') {
      return {
        'code': 0,
        'couple': {'startDate': '2024-02-14'},
        'user': _user,
        'partner': {'nickName': '小星', 'avatarUrl': ''},
      };
    }
    return const {'code': 0};
  }
}

class _ProfileRepository extends CoreLoopRepository {
  _ProfileRepository(_ProfileApi api) : super(apiClient: api, cache: AccountCache()..scopeTo('me'));
}

class _Push implements PushClient {
  @override Stream<String> get deepLinks => const Stream.empty();
  @override Future<void> startIfConsented() async {}
  @override Future<PushStatus> status() async => const PushStatus(supported: false, enabled: false, installed: true, message: '此设备暂不支持通知');
  @override Future<PushRegistration> enable() async => const PushRegistration(deviceId: '', platform: '', provider: '', endpoint: '');
}
