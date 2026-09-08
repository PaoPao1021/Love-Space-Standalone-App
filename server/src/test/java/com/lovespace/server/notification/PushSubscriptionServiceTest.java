package com.lovespace.server.notification;

import com.lovespace.server.api.BusinessException;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class PushSubscriptionServiceTest {
  @Test
  void acceptsGetuiForAndroid() {
    var result = PushSubscriptionService.validate("android-device-01",
        new PushSubscriptionService.SubscriptionInput("android", "getui", "getui-client-id", null, null));

    assertEquals("android", result.platform());
    assertEquals("getui", result.provider());
    assertEquals("getui-client-id", result.endpoint());
  }

  @Test
  void acceptsHttpsWebPushSubscription() {
    var result = PushSubscriptionService.validate("iphone-pwa-01",
        new PushSubscriptionService.SubscriptionInput(
            "web", "webpush", "https://push.example.test/subscription", "public-key", "auth-secret"));

    assertEquals("webpush", result.provider());
    assertEquals("public-key", result.publicKey());
  }

  @Test
  void rejectsCrossPlatformOrInsecureSubscriptions() {
    assertThrows(BusinessException.class, () -> PushSubscriptionService.validate("short",
        new PushSubscriptionService.SubscriptionInput("android", "getui", "client-id", null, null)));
    assertThrows(BusinessException.class, () -> PushSubscriptionService.validate("iphone-pwa-01",
        new PushSubscriptionService.SubscriptionInput(
            "web", "webpush", "http://push.example.test/subscription", "public-key", "auth-secret")));
    assertThrows(BusinessException.class, () -> PushSubscriptionService.validate("android-device-01",
        new PushSubscriptionService.SubscriptionInput("web", "getui", "getui-client-id", null, null)));
  }
}
