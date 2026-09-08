import 'package:flutter_test/flutter_test.dart';
import 'package:lovespace_app/core/auth/auth_models.dart';

void main() {
  test('parses an authentication session returned by the backend', () {
    final session = AuthSession.fromJson({
      'accessToken': 'access-token',
      'refreshToken': 'refresh-token',
      'userInfo': {
        '_id': 'user-a',
        'username': 'lover_a',
        'nickName': '小 A',
        'avatarUrl': '',
        'coupleId': 'couple-1',
        'role': 'partner_a',
      },
    });

    expect(session.accessToken, 'access-token');
    expect(session.refreshToken, 'refresh-token');
    expect(session.user.displayName, '小 A');
    expect(session.user.coupleId, 'couple-1');
  });

  test('falls back to username when nickname is empty', () {
    final user = LoveSpaceUser.fromJson({
      '_id': 'user-a',
      'username': 'lover_a',
      'nickName': '',
      'avatarUrl': '',
      'coupleId': '',
      'role': '',
    });

    expect(user.displayName, 'lover_a');
  });
}
