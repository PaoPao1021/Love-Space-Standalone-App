import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/auth/auth_repository.dart';
import 'package:lovespace_app/core/network/api_client.dart';
import 'package:lovespace_app/core/storage/token_store.dart';

void main() {
  test('concurrent 401 responses share one refresh rotation', () async {
    final tokens = _FakeTokenStore();
    final api = _FakeApiClient(tokens);
    AuthRepository(apiClient: api, tokenStore: tokens);

    final first = api.onUnauthorized!();
    final second = api.onUnauthorized!();
    await Future<void>.delayed(Duration.zero);

    expect(api.refreshCalls, 1);
    api.refreshResponse.complete({
      'code': 0,
      'accessToken': 'next-access',
      'refreshToken': 'next-refresh',
      'userInfo': {
        '_id': 'user-a',
        'username': 'partner.a',
        'nickName': 'A',
        'avatarUrl': '',
        'coupleId': 'couple',
        'role': 'creator',
      },
    });

    expect(await Future.wait([first, second]), [true, true]);
    expect(tokens.accessToken, 'next-access');
  });

  test('failed password change keeps the current session', () async {
    final tokens = _FakeTokenStore();
    final api = _FakeApiClient(tokens)
      ..changePasswordError = const ApiException('旧密码不正确');
    final repository = AuthRepository(apiClient: api, tokenStore: tokens);

    await expectLater(
      repository.changePassword('wrong-password', 'new-password-123'),
      throwsA(isA<ApiException>()),
    );

    expect(tokens.accessToken, 'expired');
    expect(tokens.refreshToken, 'refresh');
  });
}

class _FakeTokenStore extends TokenStore {
  String? accessToken = 'expired';
  String? refreshToken = 'refresh';
  @override
  Future<String?> readAccessToken() async => accessToken;
  @override
  Future<String?> readRefreshToken() async => refreshToken;
  @override
  Future<void> save({required String accessToken, String? refreshToken}) async {
    this.accessToken = accessToken;
    if (refreshToken != null) this.refreshToken = refreshToken;
  }

  @override
  Future<void> clear() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient(TokenStore tokenStore) : super(tokenStore: tokenStore);
  final refreshResponse = Completer<Map<String, dynamic>>();
  int refreshCalls = 0;
  ApiException? changePasswordError;
  @override
  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    if (path == '/api/v1/auth/refresh') {
      refreshCalls++;
      return refreshResponse.future;
    }
    if (path == '/api/v1/auth/change-password') {
      final error = changePasswordError;
      if (error != null) return Future.error(error);
      return Future.value(const {'code': 0});
    }
    throw UnsupportedError(path);
  }
}
