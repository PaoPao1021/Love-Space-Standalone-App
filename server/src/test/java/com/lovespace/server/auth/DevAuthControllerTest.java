package com.lovespace.server.auth;

import com.lovespace.server.api.BusinessException;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class DevAuthControllerTest {
  private final AuthService authService = mock(AuthService.class);
  private final DevAuthController controller = new DevAuthController(authService, "local-secret");

  @Test
  void acceptsConfiguredSecretAndMapsPartnerIdentity() {
    when(authService.login("dev-partner-a")).thenReturn(Map.of("code", 0));

    Map<String, Object> response = controller.dev(
        "local-secret", Map.of("devUser", "partnerA"));

    assertEquals(0, response.get("code"));
    verify(authService).login("dev-partner-a");
  }

  @Test
  void rejectsMissingOrIncorrectSecret() {
    BusinessException missing = assertThrows(
        BusinessException.class, () -> controller.dev(null, Map.of("devUser", "partnerA")));
    BusinessException incorrect = assertThrows(
        BusinessException.class, () -> controller.dev("wrong", Map.of("devUser", "partnerA")));

    assertEquals("开发登录密钥无效", missing.getMessage());
    assertEquals("开发登录密钥无效", incorrect.getMessage());
  }

  @Test
  void refusesToStartWithBlankSecret() {
    IllegalStateException exception = assertThrows(
        IllegalStateException.class, () -> new DevAuthController(authService, " "));

    assertEquals("lovespace.auth.dev-secret 不能为空", exception.getMessage());
  }
}
