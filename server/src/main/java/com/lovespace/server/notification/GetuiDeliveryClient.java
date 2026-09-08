package com.lovespace.server.notification;

import com.fasterxml.jackson.databind.JsonNode;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatusCode;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;

@Component
public class GetuiDeliveryClient implements PushDeliveryClient {
  private final RestClient rest = RestClient.create("https://restapi.getui.com");
  private final String appId;
  private final String appKey;
  private final String masterSecret;

  public GetuiDeliveryClient(
      @Value("${lovespace.push.getui.app-id:}") String appId,
      @Value("${lovespace.push.getui.app-key:}") String appKey,
      @Value("${lovespace.push.getui.master-secret:}") String masterSecret
  ) {
    this.appId = appId;
    this.appKey = appKey;
    this.masterSecret = masterSecret;
  }

  @Override public boolean supports(String provider) { return "getui".equals(provider); }

  @Override
  public DeliveryResult send(Subscription subscription, Message message) {
    if (appId.isBlank() || appKey.isBlank() || masterSecret.isBlank()) return DeliveryResult.retry("个推密钥未配置");
    String token = authToken();
    JsonNode response = rest.post().uri("/v2/{appId}/push/single/cid", appId)
        .header("token", token)
        .body(Map.of(
            "request_id", java.util.UUID.randomUUID().toString().replace("-", ""),
            "settings", Map.of("ttl", 3600000),
            "audience", Map.of("cid", java.util.List.of(subscription.endpoint())),
            "push_message", Map.of("notification", Map.of(
                "title", message.title(), "body", message.body(), "click_type", "payload",
                "payload", message.path()))))
        .retrieve().onStatus(HttpStatusCode::isError, (request, error) -> {})
        .body(JsonNode.class);
    int code = response == null ? -1 : response.path("code").asInt(-1);
    if (code == 0) return DeliveryResult.sent();
    if (code == 10001 || code == 10005) return DeliveryResult.invalid("个推订阅已失效: " + code);
    return DeliveryResult.retry("个推返回: " + code);
  }

  private String authToken() {
    long timestamp = Instant.now().toEpochMilli();
    String sign = sha256(appKey + timestamp + masterSecret);
    JsonNode response = rest.post().uri("/v2/{appId}/auth", appId)
        .body(Map.of("sign", sign, "timestamp", timestamp, "appkey", appKey))
        .retrieve().body(JsonNode.class);
    String token = response == null ? "" : response.path("data").path("token").asText("");
    if (token.isBlank()) throw new IllegalStateException("无法获取个推鉴权令牌");
    return token;
  }

  private static String sha256(String value) {
    try {
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
          .digest(value.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception exception) {
      throw new IllegalStateException(exception);
    }
  }
}
