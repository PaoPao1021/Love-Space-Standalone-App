package com.lovespace.server.auth;

import com.lovespace.server.api.BusinessException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.http.ResponseEntity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.CookieValue;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;
import java.util.LinkedHashMap;

@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {
  private static final String REFRESH_COOKIE = "lovespace_refresh";
  private final WechatClient wechatClient;
  private final AuthService authService;
  @Value("${lovespace.auth.refresh-cookie-secure:true}")
  private boolean refreshCookieSecure = true;
  @Value("${lovespace.auth.refresh-cookie-same-site:Strict}")
  private String refreshCookieSameSite = "Strict";
  @Value("${lovespace.auth.refresh-token-ttl:30d}")
  private java.time.Duration refreshCookieTtl = java.time.Duration.ofDays(30);

  public AuthController(WechatClient wechatClient, AuthService authService) {
    this.wechatClient = wechatClient;
    this.authService = authService;
  }

  @PostMapping("/wechat")
  public Map<String, Object> wechat(@Valid @RequestBody WechatLoginRequest request) {
    var session = wechatClient.exchangeCode(request.code());
    return authService.login(session.openid());
  }

  @PostMapping("/login")
  public ResponseEntity<Map<String, Object>> login(@Valid @RequestBody PasswordLoginRequest request) {
    Map<String, Object> session = authService.passwordLogin(
        request.username(), request.password(), request.clientType(), request.deviceName());
    return respond(session, "web".equalsIgnoreCase(request.clientType()));
  }

  @PostMapping("/refresh")
  public ResponseEntity<Map<String, Object>> refresh(
      @RequestBody(required = false) RefreshRequest request,
      @CookieValue(name = REFRESH_COOKIE, required = false) String cookieToken
  ) {
    String bodyToken = request == null ? null : request.refreshToken();
    boolean web = request != null && "web".equalsIgnoreCase(request.clientType());
    String token = bodyToken == null || bodyToken.isBlank() ? cookieToken : bodyToken;
    if (cookieToken != null && (bodyToken == null || bodyToken.isBlank())) web = true;
    return respond(authService.refresh(token), web);
  }

  @PostMapping("/logout")
  public ResponseEntity<Map<String, Object>> logout(
      @RequestBody(required = false) RefreshRequest request,
      @CookieValue(name = REFRESH_COOKIE, required = false) String cookieToken
  ) {
    String bodyToken = request == null ? null : request.refreshToken();
    authService.logout(bodyToken == null || bodyToken.isBlank() ? cookieToken : bodyToken);
    return ResponseEntity.ok()
        .header(HttpHeaders.SET_COOKIE, clearRefreshCookie().toString())
        .body(Map.of("code", 0));
  }

  @PostMapping("/logout-all")
  public ResponseEntity<Map<String, Object>> logoutAll(Authentication authentication) {
    authService.logoutAll(authentication.getName());
    return ResponseEntity.ok()
        .header(HttpHeaders.SET_COOKIE, clearRefreshCookie().toString())
        .body(Map.of("code", 0));
  }

  @PostMapping("/change-password")
  public ResponseEntity<Map<String, Object>> changePassword(
      Authentication authentication,
      @Valid @RequestBody ChangePasswordRequest request
  ) {
    authService.changePassword(authentication.getName(), request.oldPassword(), request.newPassword());
    return ResponseEntity.ok()
        .header(HttpHeaders.SET_COOKIE, clearRefreshCookie().toString())
        .body(Map.of("code", 0, "requiresLogin", true));
  }

  @GetMapping("/me")
  public Map<String, Object> me(Authentication authentication) {
    return authService.currentUser(authentication.getName());
  }

  private ResponseEntity<Map<String, Object>> respond(Map<String, Object> session, boolean web) {
    if (!web) return ResponseEntity.ok(session);
    Map<String, Object> safeBody = new LinkedHashMap<>(session);
    String refreshToken = String.valueOf(safeBody.remove("refreshToken"));
    return ResponseEntity.ok()
        .header(HttpHeaders.SET_COOKIE, refreshCookie(refreshToken).toString())
        .body(safeBody);
  }

  private ResponseCookie refreshCookie(String token) {
    return ResponseCookie.from(REFRESH_COOKIE, token)
        .httpOnly(true)
        .secure(refreshCookieSecure)
        .sameSite(refreshCookieSameSite)
        .path("/api/v1/auth")
        .maxAge(refreshCookieTtl)
        .build();
  }

  private ResponseCookie clearRefreshCookie() {
    return ResponseCookie.from(REFRESH_COOKIE, "")
        .httpOnly(true)
        .secure(refreshCookieSecure)
        .sameSite(refreshCookieSameSite)
        .path("/api/v1/auth")
        .maxAge(java.time.Duration.ZERO)
        .build();
  }

  public record WechatLoginRequest(@NotBlank(message = "缺少微信登录凭证") String code) {}

  public record PasswordLoginRequest(
      @NotBlank(message = "请输入用户名") @Size(max = 64, message = "用户名过长") String username,
      @NotBlank(message = "请输入密码") @Size(max = 128, message = "密码过长") String password,
      String clientType,
      @Size(max = 80, message = "设备名称过长") String deviceName
  ) {}

  public record RefreshRequest(String refreshToken, String clientType) {}

  public record ChangePasswordRequest(
      @NotBlank(message = "请输入旧密码") @Size(max = 128, message = "旧密码过长") String oldPassword,
      @NotBlank(message = "请输入新密码") @Size(min = 8, max = 128, message = "新密码需要 8-128 个字符") String newPassword
  ) {}
}
