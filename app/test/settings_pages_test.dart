import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/auth/auth_controller.dart';
import 'package:lovespace_app/core/auth/auth_repository.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/account_cache.dart';
import 'package:lovespace_app/core/storage/token_store.dart';
import 'package:lovespace_app/features/auth/connect_page.dart';
import 'package:lovespace_app/features/core_loop/core_loop_repository.dart';
import 'package:lovespace_app/features/settings/settings_page.dart';
import 'package:lovespace_app/theme/background_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('connect validates a six-character invite before calling API', (tester) async {
    final api = _Api();
    final auth = await _auth(api);
    await _phone(tester, ConnectPage(auth: auth, repository: _Repository(api)));

    expect(find.text('创建空间'), findsOneWidget);
    await tester.tap(find.text('加入空间'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加入我们的空间'));
    await tester.pump();

    expect(find.text('请输入六位邀请码'), findsOneWidget);
    expect(api.coupleWrites, isEmpty);
  });

  testWidgets('settings renders relationship, invite, privacy and background controls', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = _Api();
    final auth = await _auth(api);
    final cache = AccountCache()..scopeTo('account-a');
    final background = BackgroundPreferences();
    await background.scopeTo('account-a', cache);
    await _phone(tester, SettingsPage(auth: auth, repository: _Repository(api), background: background));

    expect(find.text('我的昵称'), findsOneWidget);
    expect(find.text('在一起日期'), findsOneWidget);
    expect(find.text('邀请码'), findsOneWidget);
    expect(find.text('自定义背景'), findsOneWidget);
    await tester.tap(find.text('双人空间保护'));
    await tester.pumpAndSettle();
    expect(find.textContaining('情侣关系校验'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('background preference image and opacity are isolated by account cache', () async {
    SharedPreferences.setMockInitialValues({});
    final cache = AccountCache()..scopeTo('account-a');
    final background = BackgroundPreferences();
    await background.scopeTo('account-a', cache);
    await background.save(bytes: Uint8List.fromList([1, 2, 3]), value: .3);

    cache.scopeTo('account-b');
    await background.scopeTo('account-b', cache);
    expect(background.image, isNull);
    expect(background.opacity, .8);

    cache.scopeTo('account-a');
    await background.scopeTo('account-a', cache);
    expect(background.image, Uint8List.fromList([1, 2, 3]));
    expect(background.opacity, .3);
  });
}

Future<void> _phone(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(home: page));
  await tester.pumpAndSettle();
}

Future<AuthController> _auth(_Api api) async {
  final auth = AuthController(repository: AuthRepository(apiClient: api, tokenStore: _Tokens()));
  await auth.initialize();
  return auth;
}

class _Tokens extends TokenStore {
  @override Future<String?> readAccessToken() async => 'token';
}

class _Api extends ApiClient {
  _Api() : super(tokenStore: _Tokens());
  final coupleWrites = <Map<String, dynamic>>[];
  @override Future<Map<String, dynamic>> get(String path, {bool authenticated = true}) async => {
    'code': 0,
    'userInfo': {'_id': 'account-a', 'username': 'a', 'nickName': '阿月', 'avatarUrl': '', 'coupleId': '', 'role': 'creator'},
  };
  @override Future<Map<String, dynamic>> post(String path, {Object? body, bool authenticated = true}) async {
    final map = body! as Map<String, dynamic>;
    if (map['action'] == 'getInfo') {
      return {
      'code': 0,
      'couple': {'startDate': '2024-02-14', 'inviteCode': 'ABC234'},
      'user': {'nickName': '阿月'},
      'partner': null,
    };
    }
    coupleWrites.add(map);
    return const {'code': 0};
  }
}

class _Repository extends CoreLoopRepository {
  _Repository(_Api api) : super(apiClient: api, cache: AccountCache()..scopeTo('account-a'));
}
