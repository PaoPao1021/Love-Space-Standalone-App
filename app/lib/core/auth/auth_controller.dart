import 'package:flutter/foundation.dart';

import '../network/api_client.dart';
import 'auth_models.dart';
import 'auth_repository.dart';

enum AuthStatus { booting, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({required this.repository});

  final AuthRepository repository;
  AuthStatus _status = AuthStatus.booting;
  LoveSpaceUser? _user;
  bool _submitting = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  LoveSpaceUser? get user => _user;
  bool get submitting => _submitting;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    try {
      final accessToken = await repository.tokenStore.readAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        _user = await repository.me();
      } else {
        _user = (await repository.refresh()).user;
      }
      _status = AuthStatus.authenticated;
    } catch (_) {
      await repository.tokenStore.clear();
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    if (_submitting) return false;
    _submitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final session = await repository.login(username, password);
      _user = session.user;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '暂时无法连接服务器，请稍后重试';
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await repository.logout();
    } finally {
      _user = null;
      _errorMessage = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> logoutAll() async {
    try {
      await repository.logoutAll();
    } finally {
      _user = null;
      _errorMessage = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> passwordChanged() async {
    _user = null;
    _errorMessage = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    _user = await repository.me();
    notifyListeners();
  }
}
