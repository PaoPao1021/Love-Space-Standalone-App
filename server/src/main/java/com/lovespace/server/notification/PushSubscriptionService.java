package com.lovespace.server.notification;

import com.lovespace.server.api.BusinessException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.net.URI;
import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

@Service
public class PushSubscriptionService {
  private final JdbcClient jdbc;

  public PushSubscriptionService(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  @Transactional
  public void upsert(String userId, String deviceId, SubscriptionInput input) {
    ValidatedSubscription subscription = validate(deviceId, input);
    Instant now = Instant.now();
    jdbc.sql("""
            UPDATE push_subscriptions SET status = 'disabled', updated_at = :now
            WHERE user_id = :user AND platform = :platform AND device_id <> :device AND status = 'active'
            """)
        .param("now", now).param("user", userId).param("platform", subscription.platform())
        .param("device", subscription.deviceId()).update();
    jdbc.sql("""
            INSERT INTO push_subscriptions
              (id, user_id, device_id, platform, provider, endpoint, public_key, auth_secret,
               status, created_at, updated_at)
            VALUES
              (:id, :user, :device, :platform, :provider, :endpoint, :publicKey, :authSecret,
               'active', :now, :now)
            ON DUPLICATE KEY UPDATE
              platform = VALUES(platform), provider = VALUES(provider), endpoint = VALUES(endpoint),
              public_key = VALUES(public_key), auth_secret = VALUES(auth_secret),
              status = 'active', updated_at = VALUES(updated_at)
            """)
        .param("id", UUID.randomUUID().toString())
        .param("user", userId)
        .param("device", subscription.deviceId())
        .param("platform", subscription.platform())
        .param("provider", subscription.provider())
        .param("endpoint", subscription.endpoint())
        .param("publicKey", blankToNull(subscription.publicKey()))
        .param("authSecret", blankToNull(subscription.authSecret()))
        .param("now", now)
        .update();
  }

  public void disable(String userId, String deviceId) {
    int changed = jdbc.sql("""
            UPDATE push_subscriptions SET status = 'disabled', updated_at = :now
            WHERE user_id = :user AND device_id = :device AND status = 'active'
            """)
        .param("now", Instant.now())
        .param("user", userId)
        .param("device", normalizeDeviceId(deviceId))
        .update();
    if (changed == 0) throw new BusinessException("推送设备不存在");
  }

  static ValidatedSubscription validate(String deviceId, SubscriptionInput input) {
    if (input == null) throw new BusinessException("缺少推送订阅");
    String platform = lower(input.platform());
    String provider = lower(input.provider());
    String endpoint = trim(input.endpoint(), 2048);
    String publicKey = trim(input.publicKey(), 256);
    String authSecret = trim(input.authSecret(), 128);

    if (provider.equals("getui")) {
      if (!platform.equals("android") || endpoint.length() < 8) {
        throw new BusinessException("个推订阅参数无效");
      }
      publicKey = "";
      authSecret = "";
    } else if (provider.equals("webpush")) {
      if (!platform.equals("web") || !isHttps(endpoint) || publicKey.isBlank() || authSecret.isBlank()) {
        throw new BusinessException("Web Push订阅参数无效");
      }
    } else {
      throw new BusinessException("不支持的推送服务");
    }
    return new ValidatedSubscription(
        normalizeDeviceId(deviceId), platform, provider, endpoint, publicKey, authSecret);
  }

  private static String normalizeDeviceId(String value) {
    String deviceId = value == null ? "" : value.trim();
    if (!deviceId.matches("[A-Za-z0-9._:-]{8,64}")) throw new BusinessException("设备ID无效");
    return deviceId;
  }

  private static boolean isHttps(String value) {
    try {
      URI uri = URI.create(value);
      return "https".equalsIgnoreCase(uri.getScheme()) && uri.getHost() != null;
    } catch (RuntimeException ignored) {
      return false;
    }
  }

  private static String lower(String value) {
    return value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
  }

  private static String trim(String value, int maxLength) {
    String text = value == null ? "" : value.trim();
    if (text.length() > maxLength) throw new BusinessException("推送订阅参数过长");
    return text;
  }

  private static String blankToNull(String value) {
    return value == null || value.isBlank() ? null : value;
  }

  public record SubscriptionInput(
      String platform,
      String provider,
      String endpoint,
      String publicKey,
      String authSecret
  ) {}

  record ValidatedSubscription(
      String deviceId,
      String platform,
      String provider,
      String endpoint,
      String publicKey,
      String authSecret
  ) {}
}
