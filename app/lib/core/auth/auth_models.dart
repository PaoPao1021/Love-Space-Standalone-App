class LoveSpaceUser {
  const LoveSpaceUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.coupleId,
    required this.role,
  });

  factory LoveSpaceUser.fromJson(Map<String, dynamic> json) {
    return LoveSpaceUser(
      id: json['_id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      nickname: json['nickName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String? ?? '',
      coupleId: json['coupleId'] as String? ?? '',
      role: json['role'] as String? ?? '',
    );
  }

  final String id;
  final String username;
  final String nickname;
  final String avatarUrl;
  final String coupleId;
  final String role;

  String get displayName => nickname.trim().isNotEmpty ? nickname : username;
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken:
          json['accessToken'] as String? ?? json['token'] as String? ?? '',
      refreshToken: json['refreshToken'] as String?,
      user: LoveSpaceUser.fromJson(json['userInfo'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final LoveSpaceUser user;
}
