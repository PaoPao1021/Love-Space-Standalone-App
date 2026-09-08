package com.lovespace.server.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.time.Duration;

@ConfigurationProperties(prefix = "lovespace")
public record LoveSpaceProperties(
    Auth auth,
    Wechat wechat,
    Storage storage
) {
  public LoveSpaceProperties {
    auth = auth == null
        ? new Auth("change-this-local-jwt-secret-with-at-least-32-bytes", Duration.ofMinutes(15), Duration.ofDays(30), "")
        : auth;
    wechat = wechat == null ? new Wechat("", "", "", "", false) : wechat;
    storage = storage == null
        ? new Storage(
            "http://localhost:9090",
            "http://localhost:9090",
            "us-east-1",
            "lovespace",
            "local",
            "local",
            Duration.ofMinutes(30),
            true,
            true)
        : storage;
  }

  public record Auth(String jwtSecret, Duration tokenTtl, Duration refreshTokenTtl, String devSecret) {
    public Auth {
      requireText(jwtSecret, "lovespace.auth.jwt-secret");
      if (tokenTtl == null || tokenTtl.isNegative()) {
        throw new IllegalArgumentException("lovespace.auth.token-ttl 不能为负数");
      }
      if (refreshTokenTtl == null || refreshTokenTtl.isZero() || refreshTokenTtl.isNegative()) {
        throw new IllegalArgumentException("lovespace.auth.refresh-token-ttl 必须大于 0");
      }
    }

    public Auth(String jwtSecret, Duration tokenTtl, String devSecret) {
      this(jwtSecret, tokenTtl, Duration.ofDays(30), devSecret);
    }
  }

  public record Wechat(
      String appId,
      String appSecret,
      String orderTemplateId,
      String anniversaryTemplateId,
      boolean integrationsEnabled
  ) {
    public Wechat {
      if (integrationsEnabled) {
        requireText(appId, "lovespace.wechat.app-id");
        requireText(appSecret, "lovespace.wechat.app-secret");
        requireText(orderTemplateId, "lovespace.wechat.order-template-id");
        requireText(anniversaryTemplateId, "lovespace.wechat.anniversary-template-id");
      }
    }
  }

  public record Storage(
      String internalEndpoint,
      String publicEndpoint,
      String region,
      String bucket,
      String accessKey,
      String secretKey,
      Duration signedUrlTtl,
      boolean pathStyleAccessEnabled,
      boolean chunkedEncodingEnabled
  ) {
    public Storage {
      requireText(internalEndpoint, "lovespace.storage.internal-endpoint");
      requireText(publicEndpoint, "lovespace.storage.public-endpoint");
      requireText(region, "lovespace.storage.region");
      requireText(bucket, "lovespace.storage.bucket");
      requireText(accessKey, "lovespace.storage.access-key");
      requireText(secretKey, "lovespace.storage.secret-key");
      if (signedUrlTtl == null || signedUrlTtl.isZero() || signedUrlTtl.isNegative()) {
        throw new IllegalArgumentException("lovespace.storage.signed-url-ttl 必须大于 0");
      }
    }

    public Storage(
        String internalEndpoint,
        String publicEndpoint,
        String region,
        String bucket,
        String accessKey,
        String secretKey,
        Duration signedUrlTtl
    ) {
      this(internalEndpoint, publicEndpoint, region, bucket, accessKey, secretKey, signedUrlTtl, true, true);
    }
  }

  private static void requireText(String value, String property) {
    if (value == null || value.isBlank()) throw new IllegalArgumentException(property + " 不能为空");
  }
}
