package com.lovespace.server.auth;

import com.lovespace.server.api.BusinessException;
import org.springframework.context.annotation.Profile;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

@Profile("dev & !prod")
@RestController
@RequestMapping("/api/v1/auth")
public class DevAuthController {
  private final AuthService authService;
  private final byte[] devSecret;

  public DevAuthController(
      AuthService authService,
      @Value("${lovespace.auth.dev-secret}") String devSecret
  ) {
    this.authService = authService;
    if (devSecret == null || devSecret.isBlank()) {
      throw new IllegalStateException("lovespace.auth.dev-secret 不能为空");
    }
    this.devSecret = devSecret.getBytes(StandardCharsets.UTF_8);
  }

  @PostMapping("/dev")
  public Map<String, Object> dev(
      @RequestHeader(name = "X-Dev-Auth-Secret", required = false) String suppliedSecret,
      @RequestBody(required = false) Map<String, Object> request
  ) {
    byte[] supplied = suppliedSecret == null
        ? new byte[0] : suppliedSecret.getBytes(StandardCharsets.UTF_8);
    if (!MessageDigest.isEqual(devSecret, supplied)) {
      throw new BusinessException("开发登录密钥无效");
    }
    String requested = request == null ? "" : String.valueOf(
        request.getOrDefault("devUser", request.getOrDefault("username", "")));
    String openid = switch (requested) {
      case "partnerA", "dev-partner-a" -> "dev-partner-a";
      case "partnerB", "dev-partner-b" -> "dev-partner-b";
      default -> throw new BusinessException("开发账号只能是 partnerA 或 partnerB");
    };
    return authService.login(openid);
  }
}
