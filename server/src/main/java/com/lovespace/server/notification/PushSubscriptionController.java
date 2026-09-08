package com.lovespace.server.notification;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/push/subscriptions")
public class PushSubscriptionController {
  private final PushSubscriptionService subscriptions;

  public PushSubscriptionController(PushSubscriptionService subscriptions) {
    this.subscriptions = subscriptions;
  }

  @PutMapping("/{deviceId}")
  public Map<String, Object> upsert(
      @PathVariable String deviceId,
      @RequestBody PushSubscriptionRequest request,
      Authentication authentication
  ) {
    subscriptions.upsert(authentication.getName(), deviceId, new PushSubscriptionService.SubscriptionInput(
        request.platform(), request.provider(), request.endpoint(), request.publicKey(), request.authSecret()));
    return Map.of("code", 0);
  }

  @DeleteMapping("/{deviceId}")
  public Map<String, Object> disable(@PathVariable String deviceId, Authentication authentication) {
    subscriptions.disable(authentication.getName(), deviceId);
    return Map.of("code", 0);
  }

  public record PushSubscriptionRequest(
      String platform,
      String provider,
      String endpoint,
      String publicKey,
      String authSecret
  ) {}
}
