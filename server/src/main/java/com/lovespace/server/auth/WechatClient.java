package com.lovespace.server.auth;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.config.LoveSpaceProperties;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

@Component
public class WechatClient {
  private final RestClient restClient;
  private final LoveSpaceProperties properties;

  public WechatClient(RestClient.Builder builder, LoveSpaceProperties properties) {
    this.restClient = builder.build();
    this.properties = properties;
  }

  public Session exchangeCode(String code) {
    if (properties.wechat().appId().isBlank() || properties.wechat().appSecret().isBlank()) {
      throw new BusinessException("尚未配置微信 AppID 和 AppSecret");
    }
    String uri = UriComponentsBuilder
        .fromUriString("https://api.weixin.qq.com/sns/jscode2session")
        .queryParam("appid", properties.wechat().appId())
        .queryParam("secret", properties.wechat().appSecret())
        .queryParam("js_code", code)
        .queryParam("grant_type", "authorization_code")
        .build(true)
        .toUriString();
    Session session = restClient.get().uri(uri).retrieve().body(Session.class);
    if (session == null || session.openid() == null || session.openid().isBlank()) {
      throw new BusinessException(session != null && session.errmsg() != null ? session.errmsg() : "微信登录失败");
    }
    return session;
  }

  public record Session(
      String openid,
      @JsonProperty("session_key") String sessionKey,
      String unionid,
      Integer errcode,
      String errmsg
  ) {}
}
