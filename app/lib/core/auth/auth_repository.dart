import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import '../storage/token_store.dart';
import 'auth_models.dart';

class AuthRepository {
  AuthRepository({required this.apiClient, required this.tokenStore}) {
    apiClient.onUnauthorized = _refreshAfterUnauthorized;
  }

  final ApiClient apiClient;
  final TokenStore tokenStore;
  Future<bool>? _refreshInFlight;

  Future<AuthSession> login(String username, String password) async {
    final payload = await apiClient.post(
      '/api/v1/auth/login',
      authenticated: false,
      body: {
        'username': username,
        'password': password,
        'clientType': kIsWeb ? 'web' : 'android',
        'deviceName': kIsWeb ? 'LoveSpace Web' : 'LoveSpace Android',
      },
    );
    return _storeSession(payload);
  }

  Future<AuthSession> refresh() async {
    final refreshToken = await tokenStore.readRefreshToken();
    final body = <String, Object?>{'clientType': kIsWeb ? 'web' : 'android'};
    if (refreshToken != null) body['refreshToken'] = refreshToken;
    final payload = await apiClient.post(
      '/api/v1/auth/refresh',
      authenticated: false,
      body: body,
    );
    return _storeSession(payload);
  }

  Future<LoveSpaceUser> me() async {
    final payload = await apiClient.get('/api/v1/auth/me');
    return LoveSpaceUser.fromJson(payload['userInfo'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final refreshToken = await tokenStore.readRefreshToken();
    final body = <String, Object?>{'clientType': kIsWeb ? 'web' : 'android'};
    if (refreshToken != null) body['refreshToken'] = refreshToken;
    try {
      await apiClient.post('/api/v1/auth/logout', body: body);
    } finally {
      await tokenStore.clear();
    }
  }

  Future<void> logoutAll() async {
    try {
      await apiClient.post('/api/v1/auth/logout-all');
    } finally {
      await tokenStore.clear();
    }
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await apiClient.post(
      '/api/v1/auth/change-password',
      body: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
    await tokenStore.clear();
  }

  Future<AuthSession> _storeSession(Map<String, dynamic> payload) async {
    final session = AuthSession.fromJson(payload);
    if (session.accessToken.isEmpty) {
      throw const ApiException('登录响应缺少访问令牌');
    }
    await tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    return session;
  }

  Future<bool> _refreshAfterUnauthorized() async {
    final current = _refreshInFlight;
    if (current != null) return current;
    final refresh = _performRefreshAfterUnauthorized();
    _refreshInFlight = refresh;
    try {
      return await refresh;
    } finally {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    }
  }

  Future<bool> _performRefreshAfterUnauthorized() async {
    try {
      await refresh();
      return true;
    } catch (_) {
      await tokenStore.clear();
      return false;
    }
  }
}
