import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStore {
  static const _accessKey = 'lovespace_access_token';
  static const _refreshKey = 'lovespace_refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );
  String? _webAccessToken;

  Future<String?> readAccessToken() async {
    if (kIsWeb) return _webAccessToken;
    return _storage.read(key: _accessKey);
  }

  Future<String?> readRefreshToken() async {
    if (kIsWeb) return null;
    return _storage.read(key: _refreshKey);
  }

  Future<void> save({required String accessToken, String? refreshToken}) async {
    if (kIsWeb) {
      _webAccessToken = accessToken;
      return;
    }
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<void> clear() async {
    _webAccessToken = null;
    if (!kIsWeb) {
      await _storage.delete(key: _accessKey);
      await _storage.delete(key: _refreshKey);
    }
  }
}
