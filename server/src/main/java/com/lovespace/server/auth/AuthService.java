package com.lovespace.server.auth;

import com.lovespace.server.api.BusinessException;
import com.lovespace.server.config.LoveSpaceProperties;
import com.lovespace.server.jdbc.JdbcTime;
import com.lovespace.server.security.JwtService;
import com.lovespace.server.storage.MediaService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class AuthService {
  private static final SecureRandom RANDOM = new SecureRandom();

  private final JdbcClient jdbc;
  private final JwtService jwtService;
  private final MediaService mediaService;
  private final PasswordEncoder passwordEncoder;
  private final LoveSpaceProperties properties;

  public AuthService(
      JdbcClient jdbc,
      JwtService jwtService,
      MediaService mediaService,
      PasswordEncoder passwordEncoder,
      LoveSpaceProperties properties
  ) {
    this.jdbc = jdbc;
    this.jwtService = jwtService;
    this.mediaService = mediaService;
    this.passwordEncoder = passwordEncoder;
    this.properties = properties;
  }

  /** Keeps development and optional legacy WeChat login working during the client migration. */
  @Transactional
  public Map<String, Object> login(String externalId) {
    Instant now = Instant.now();
    jdbc.sql("""
            INSERT INTO users (id, nick_name, avatar_url, couple_id, role, created_at, updated_at)
            VALUES (:id, '', '', NULL, '', :now, :now)
            ON DUPLICATE KEY UPDATE updated_at = updated_at
            """)
        .param("id", externalId)
        .param("now", now)
        .update();
    return issueSession(externalId, "legacy", "legacy-client", now);
  }

  @Transactional
  public Map<String, Object> passwordLogin(String username, String password, String clientType, String deviceName) {
    String normalizedUsername = normalizeUsername(username);
    Credentials credentials = jdbc.sql("""
            SELECT id, password_hash, enabled
            FROM users WHERE username = :username
            """)
        .param("username", normalizedUsername)
        .query((rs, rowNum) -> new Credentials(
            rs.getString("id"), rs.getString("password_hash"), rs.getBoolean("enabled")))
        .optional()
        .orElse(null);

    if (credentials == null || !credentials.enabled()
        || credentials.passwordHash() == null
        || !passwordEncoder.matches(password == null ? "" : password, credentials.passwordHash())) {
      throw new BusinessException("用户名或密码错误");
    }

    Instant now = Instant.now();
    jdbc.sql("UPDATE users SET last_login_at = :now WHERE id = :id")
        .param("now", now)
        .param("id", credentials.userId())
        .update();
    return issueSession(credentials.userId(), clientType, deviceName, now);
  }

  @Transactional
  public Map<String, Object> refresh(String rawRefreshToken) {
    if (rawRefreshToken == null || rawRefreshToken.isBlank()) {
      throw new BusinessException("刷新令牌无效或已过期");
    }
    Instant now = Instant.now();
    RefreshSession existing = jdbc.sql("""
            SELECT s.id, s.user_id, s.client_type, s.device_name, u.auth_version
            FROM refresh_sessions s
            JOIN users u ON u.id = s.user_id
            WHERE s.token_hash = :hash
              AND s.revoked_at IS NULL
              AND s.expires_at > :now
              AND u.enabled = 1
            """)
        .param("hash", hash(rawRefreshToken))
        .param("now", now)
        .query((rs, rowNum) -> new RefreshSession(
            rs.getString("id"), rs.getString("user_id"), rs.getString("client_type"),
            rs.getString("device_name"), rs.getInt("auth_version")))
        .optional()
        .orElseThrow(() -> new BusinessException("刷新令牌无效或已过期"));

    NewRefresh replacement = newRefresh(existing.userId(), existing.clientType(), existing.deviceName(), now);
    insertRefresh(replacement);
    int changed = jdbc.sql("""
            UPDATE refresh_sessions
            SET revoked_at = :now, replaced_by = :replacement
            WHERE id = :id AND revoked_at IS NULL
            """)
        .param("now", now)
        .param("replacement", replacement.id())
        .param("id", existing.id())
        .update();
    if (changed != 1) throw new BusinessException("刷新令牌已被使用");
    return sessionResponse(existing.userId(), existing.authVersion(), replacement.rawToken());
  }

  @Transactional
  public void logout(String rawRefreshToken) {
    if (rawRefreshToken == null || rawRefreshToken.isBlank()) return;
    jdbc.sql("""
            UPDATE refresh_sessions SET revoked_at = :now
            WHERE token_hash = :hash AND revoked_at IS NULL
            """)
        .param("now", Instant.now())
        .param("hash", hash(rawRefreshToken))
        .update();
  }

  @Transactional
  public void logoutAll(String userId) {
    Instant now = Instant.now();
    jdbc.sql("UPDATE users SET auth_version = auth_version + 1 WHERE id = :id")
        .param("id", userId)
        .update();
    jdbc.sql("""
            UPDATE refresh_sessions SET revoked_at = :now
            WHERE user_id = :id AND revoked_at IS NULL
            """)
        .param("now", now)
        .param("id", userId)
        .update();
  }

  @Transactional
  public void changePassword(String userId, String oldPassword, String newPassword) {
    String currentHash = jdbc.sql("SELECT password_hash FROM users WHERE id = :id AND enabled = 1 FOR UPDATE")
        .param("id", userId)
        .query(String.class)
        .optional()
        .orElseThrow(() -> new BusinessException("账号不可用"));
    if (currentHash == null || !passwordEncoder.matches(oldPassword == null ? "" : oldPassword, currentHash)) {
      throw new BusinessException("旧密码不正确");
    }
    if (newPassword == null || newPassword.length() < 8 || newPassword.length() > 128) {
      throw new BusinessException("新密码需要 8-128 个字符");
    }
    if (passwordEncoder.matches(newPassword, currentHash)) {
      throw new BusinessException("新密码不能与旧密码相同");
    }
    Instant now = Instant.now();
    jdbc.sql("UPDATE users SET password_hash = :hash, auth_version = auth_version + 1, updated_at = :now WHERE id = :id")
        .param("hash", passwordEncoder.encode(newPassword))
        .param("now", now)
        .param("id", userId)
        .update();
    jdbc.sql("UPDATE refresh_sessions SET revoked_at = :now WHERE user_id = :id AND revoked_at IS NULL")
        .param("now", now)
        .param("id", userId)
        .update();
  }

  public Map<String, Object> currentUser(String userId) {
    return Map.of("code", 0, "userInfo", userInfo(userId));
  }

  private Map<String, Object> issueSession(String userId, String clientType, String deviceName, Instant now) {
    int authVersion = jdbc.sql("SELECT auth_version FROM users WHERE id = :id")
        .param("id", userId)
        .query(Integer.class)
        .single();
    NewRefresh refresh = newRefresh(userId, clientType, deviceName, now);
    insertRefresh(refresh);
    return sessionResponse(userId, authVersion, refresh.rawToken());
  }

  private Map<String, Object> sessionResponse(String userId, int authVersion, String refreshToken) {
    Map<String, Object> response = new LinkedHashMap<>();
    String accessToken = jwtService.issue(userId, authVersion);
    response.put("code", 0);
    response.put("token", accessToken);
    response.put("accessToken", accessToken);
    response.put("expiresIn", jwtService.ttlSeconds());
    response.put("refreshToken", refreshToken);
    response.put("openid", userId);
    response.put("userInfo", userInfo(userId));
    return response;
  }

  private Map<String, Object> userInfo(String userId) {
    Map<String, Object> user = jdbc.sql("""
            SELECT id, username, nick_name, avatar_url, couple_id, role, created_at, updated_at
            FROM users WHERE id = :id AND enabled = 1
            """)
        .param("id", userId)
        .query((rs, rowNum) -> {
          Map<String, Object> result = new LinkedHashMap<>();
          result.put("_id", rs.getString("id"));
          result.put("username", rs.getString("username") == null ? "" : rs.getString("username"));
          result.put("nickName", rs.getString("nick_name"));
          result.put("avatarUrl", rs.getString("avatar_url"));
          result.put("coupleId", rs.getString("couple_id") == null ? "" : rs.getString("couple_id"));
          result.put("role", rs.getString("role") == null ? "" : rs.getString("role"));
          result.put("createdAt", JdbcTime.instant(rs, "created_at"));
          result.put("updatedAt", JdbcTime.instant(rs, "updated_at"));
          return result;
        })
        .optional()
        .orElseThrow(() -> new BusinessException("账号不可用"));
    String avatarAssetId = String.valueOf(user.getOrDefault("avatarUrl", ""));
    user.put("avatarAssetId", avatarAssetId);
    user.put("avatarUrl", mediaService.resolveForDisplay(userId, avatarAssetId));
    return user;
  }

  private NewRefresh newRefresh(String userId, String clientType, String deviceName, Instant now) {
    byte[] bytes = new byte[32];
    RANDOM.nextBytes(bytes);
    String rawToken = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    return new NewRefresh(
        UUID.randomUUID().toString(), userId, hash(rawToken), rawToken,
        normalizeClientType(clientType), truncate(deviceName, 80), now,
        now.plus(properties.auth().refreshTokenTtl()));
  }

  private void insertRefresh(NewRefresh refresh) {
    jdbc.sql("""
            INSERT INTO refresh_sessions
              (id, user_id, token_hash, client_type, device_name, created_at, expires_at)
            VALUES (:id, :user, :hash, :client, :device, :created, :expires)
            """)
        .param("id", refresh.id())
        .param("user", refresh.userId())
        .param("hash", refresh.hash())
        .param("client", refresh.clientType())
        .param("device", refresh.deviceName())
        .param("created", refresh.createdAt())
        .param("expires", refresh.expiresAt())
        .update();
  }

  private static String normalizeUsername(String username) {
    String value = username == null ? "" : username.trim().toLowerCase();
    if (!value.matches("[a-z0-9._-]{3,64}")) throw new BusinessException("用户名或密码错误");
    return value;
  }

  private static String normalizeClientType(String clientType) {
    return switch (clientType == null ? "" : clientType.trim().toLowerCase()) {
      case "android" -> "android";
      case "web" -> "web";
      default -> "legacy";
    };
  }

  private static String truncate(String value, int maxLength) {
    String text = value == null ? "" : value.trim();
    return text.substring(0, Math.min(text.length(), maxLength));
  }

  private static String hash(String token) {
    try {
      return HexFormat.of().formatHex(
          MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException("无法处理刷新令牌", exception);
    }
  }

  private record Credentials(String userId, String passwordHash, boolean enabled) {}

  private record RefreshSession(String id, String userId, String clientType, String deviceName, int authVersion) {}

  private record NewRefresh(
      String id,
      String userId,
      String hash,
      String rawToken,
      String clientType,
      String deviceName,
      Instant createdAt,
      Instant expiresAt
  ) {}
}
