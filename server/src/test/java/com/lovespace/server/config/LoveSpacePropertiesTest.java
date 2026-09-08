package com.lovespace.server.config;

import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class LoveSpacePropertiesTest {
  @Test
  void permitsBlankWechatCredentialsWhenIntegrationsAreDisabled() {
    assertDoesNotThrow(() -> new LoveSpaceProperties.Wechat("", "", "", "", false));
  }

  @Test
  void rejectsBlankWechatCredentialsWhenIntegrationsAreEnabled() {
    assertThrows(IllegalArgumentException.class,
        () -> new LoveSpaceProperties.Wechat("", "secret", "order", "anniversary", true));
    assertThrows(IllegalArgumentException.class,
        () -> new LoveSpaceProperties.Wechat("app-id", "", "order", "anniversary", true));
    assertThrows(IllegalArgumentException.class,
        () -> new LoveSpaceProperties.Wechat("app-id", "secret", "", "anniversary", true));
    assertThrows(IllegalArgumentException.class,
        () -> new LoveSpaceProperties.Wechat("app-id", "secret", "order", "", true));
    assertDoesNotThrow(() ->
        new LoveSpaceProperties.Wechat("app-id", "secret", "order", "anniversary", true));
  }

  @Test
  void requiresBothStorageEndpoints() {
    assertThrows(IllegalArgumentException.class,
        () -> storage("", "https://files.example.test"));
    assertThrows(IllegalArgumentException.class,
        () -> storage("http://s3:9000", ""));
    assertDoesNotThrow(() -> storage("http://s3:9000", "https://files.example.test"));
  }

  private static LoveSpaceProperties.Storage storage(String internalEndpoint, String publicEndpoint) {
    return new LoveSpaceProperties.Storage(
        internalEndpoint, publicEndpoint, "us-east-1", "lovespace", "access", "secret", Duration.ofMinutes(30));
  }
}
