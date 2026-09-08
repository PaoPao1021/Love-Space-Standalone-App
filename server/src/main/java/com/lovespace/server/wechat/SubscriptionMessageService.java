package com.lovespace.server.wechat;

import com.fasterxml.jackson.databind.JsonNode;
import com.lovespace.server.config.LoveSpaceProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class SubscriptionMessageService {
  private static final Logger log = LoggerFactory.getLogger(SubscriptionMessageService.class);
  private final RestClient restClient;
  private final WechatAccessTokenService tokens;
  private final LoveSpaceProperties properties;

  public SubscriptionMessageService(RestClient.Builder builder, WechatAccessTokenService tokens, LoveSpaceProperties properties) {
    this.restClient = builder.build();
    this.tokens = tokens;
    this.properties = properties;
  }

  public void sendOrderOrTask(String openid, String thing1, String thing2, String amount3) {
    send(properties.wechat().orderTemplateId(), openid, Map.of(
        "thing1", Map.of("value", truncate(thing1, 20)),
        "thing2", Map.of("value", truncate(thing2, 20)),
        "amount3", Map.of("value", truncate(amount3, 20))));
  }

  public void sendAnniversary(String openid, String name, int days) {
    send(properties.wechat().anniversaryTemplateId(), openid, Map.of(
        "thing1", Map.of("value", truncate(name, 20)),
        "number2", Map.of("value", days)));
  }

  private void send(String templateId, String openid, Map<String, Object> data) {
    if (!properties.wechat().integrationsEnabled() || templateId == null || templateId.isBlank() || openid == null || openid.isBlank()) return;
    try {
      Map<String, Object> body = new LinkedHashMap<>();
      body.put("touser", openid);
      body.put("template_id", templateId);
      body.put("page", "pages/index/index");
      body.put("data", data);
      JsonNode response = restClient.post()
          .uri("https://api.weixin.qq.com/cgi-bin/message/subscribe/send?access_token={token}", tokens.get())
          .body(body).retrieve().body(JsonNode.class);
      if (response != null && response.path("errcode").asInt(0) != 0) {
        log.info("Subscription message skipped: {}", response.path("errmsg").asText());
      }
    } catch (Exception exception) {
      log.info("Subscription message skipped: {}", exception.getMessage());
    }
  }

  private static String truncate(String value, int max) {
    String text = value == null ? "" : value;
    return text.substring(0, Math.min(max, text.length()));
  }
}
