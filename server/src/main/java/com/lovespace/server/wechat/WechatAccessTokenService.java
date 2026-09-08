package com.lovespace.server.wechat;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.config.LoveSpaceProperties;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.UriComponentsBuilder;

import java.time.Instant;

@Service
public class WechatAccessTokenService {
  private final RestClient restClient;
  private final LoveSpaceProperties properties;
  private volatile CachedToken cached;

  public WechatAccessTokenService(RestClient.Builder builder, LoveSpaceProperties properties) {
    this.restClient = builder.build();
    this.properties = properties;
  }

  public synchronized String get() {
    if (!properties.wechat().integrationsEnabled()) return "";
    if (cached != null && cached.expiresAt().isAfter(Instant.now().plusSeconds(120))) return cached.value();
    if (properties.wechat().appId().isBlank() || properties.wechat().appSecret().isBlank()) {
      throw new BusinessException("微信服务端能力尚未配置");
    }
    String uri = UriComponentsBuilder.fromUriString("https://api.weixin.qq.com/cgi-bin/token")
        .queryParam("grant_type", "client_credential")
        .queryParam("appid", properties.wechat().appId())
        .queryParam("secret", properties.wechat().appSecret())
        .build(true).toUriString();
    TokenResponse result = restClient.get().uri(uri).retrieve().body(TokenResponse.class);
    if (result == null || result.accessToken() == null || result.accessToken().isBlank()) {
      throw new BusinessException(result != null && result.errmsg() != null ? result.errmsg() : "获取微信接口凭证失败");
    }
    cached = new CachedToken(result.accessToken(), Instant.now().plusSeconds(Math.max(300, result.expiresIn())));
    return cached.value();
  }

  private record TokenResponse(
      @JsonProperty("access_token") String accessToken,
      @JsonProperty("expires_in") long expiresIn,
      Integer errcode,
      String errmsg
  ) {}
  private record CachedToken(String value, Instant expiresAt) {}
}
