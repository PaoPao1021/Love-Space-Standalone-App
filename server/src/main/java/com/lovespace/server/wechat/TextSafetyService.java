package com.lovespace.server.wechat;

import com.fasterxml.jackson.databind.JsonNode;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.config.LoveSpaceProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class TextSafetyService {
  private static final Logger log = LoggerFactory.getLogger(TextSafetyService.class);
  private final RestClient restClient;
  private final WechatAccessTokenService tokens;
  private final LoveSpaceProperties properties;

  public TextSafetyService(RestClient.Builder builder, WechatAccessTokenService tokens, LoveSpaceProperties properties) {
    this.restClient = builder.build();
    this.tokens = tokens;
    this.properties = properties;
  }

  public void check(String openid, int maxLength, Object... values) {
    String content = Arrays.stream(values)
        .map(value -> value == null ? "" : String.valueOf(value).trim())
        .filter(value -> !value.isBlank())
        .collect(Collectors.joining("\n"));
    if (content.isBlank()) return;
    content = content.substring(0, Math.min(maxLength, content.length()));
    if (!properties.wechat().integrationsEnabled()) {
      log.debug("Text safety skipped in local profile for {}", openid);
      return;
    }
    try {
      Map<String, Object> request = new LinkedHashMap<>();
      request.put("content", content);
      request.put("version", 2);
      request.put("scene", 2);
      request.put("openid", openid);
      JsonNode response = restClient.post()
          .uri("https://api.weixin.qq.com/wxa/msg_sec_check?access_token={token}", tokens.get())
          .body(request)
          .retrieve().body(JsonNode.class);
      int errcode = response == null ? -1 : response.path("errcode").asInt(0);
      String suggest = response == null ? "" : response.path("result").path("suggest").asText("");
      if (errcode == 87014 || (!suggest.isBlank() && !"pass".equals(suggest))) {
        throw new BusinessException("内容包含不适合发布的信息，请修改后重试");
      }
      if (errcode != 0) throw new BusinessException("内容安全检查暂时不可用，请稍后重试");
    } catch (BusinessException exception) {
      throw exception;
    } catch (Exception exception) {
      log.error("Wechat text safety request failed", exception);
      throw new BusinessException("内容安全检查暂时不可用，请稍后重试");
    }
  }
}
