package com.lovespace.server.auth;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpHeaders;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AuthControllerTest {
  private final WechatClient wechatClient = mock(WechatClient.class);
  private final AuthService authService = mock(AuthService.class);
  private final AuthController controller = new AuthController(wechatClient, authService);

  @Test
  void androidLoginReturnsRefreshTokenInBody() {
    when(authService.passwordLogin("partner.a", "strong-password", "android", "OnePlus 12"))
        .thenReturn(session());

    var response = controller.login(new AuthController.PasswordLoginRequest(
        "partner.a", "strong-password", "android", "OnePlus 12"));

    assertEquals("refresh-secret", response.getBody().get("refreshToken"));
    assertFalse(response.getHeaders().containsKey(HttpHeaders.SET_COOKIE));
  }

  @Test
  void webLoginKeepsRefreshTokenInSecureHttpOnlyCookie() {
    when(authService.passwordLogin("partner.a", "strong-password", "web", "iPhone PWA"))
        .thenReturn(session());

    var response = controller.login(new AuthController.PasswordLoginRequest(
        "partner.a", "strong-password", "web", "iPhone PWA"));

    assertFalse(response.getBody().containsKey("refreshToken"));
    String cookie = response.getHeaders().getFirst(HttpHeaders.SET_COOKIE);
    assertNotNull(cookie);
    assertTrue(cookie.contains("lovespace_refresh=refresh-secret"));
    assertTrue(cookie.contains("HttpOnly"));
    assertTrue(cookie.contains("Secure"));
    assertTrue(cookie.contains("SameSite=Strict"));
  }

  @Test
  void webRefreshRotatesTheCookieToken() {
    when(authService.refresh("old-cookie-token")).thenReturn(session());

    var response = controller.refresh(null, "old-cookie-token");

    verify(authService).refresh("old-cookie-token");
    assertFalse(response.getBody().containsKey("refreshToken"));
    assertTrue(response.getHeaders().getFirst(HttpHeaders.SET_COOKIE)
        .contains("lovespace_refresh=refresh-secret"));
  }

  @Test
  void passwordChangeRevokesEverySessionAndClearsWebCookie() {
    var authentication = mock(org.springframework.security.core.Authentication.class);
    when(authentication.getName()).thenReturn("user-a");

    var response = controller.changePassword(authentication,
        new AuthController.ChangePasswordRequest("old-password", "new-password-123"));

    verify(authService).changePassword("user-a", "old-password", "new-password-123");
    assertEquals(true, response.getBody().get("requiresLogin"));
    assertTrue(response.getHeaders().getFirst(HttpHeaders.SET_COOKIE).contains("Max-Age=0"));
  }

  private static Map<String, Object> session() {
    Map<String, Object> response = new LinkedHashMap<>();
    response.put("code", 0);
    response.put("accessToken", "access-token");
    response.put("refreshToken", "refresh-secret");
    return response;
  }
}
