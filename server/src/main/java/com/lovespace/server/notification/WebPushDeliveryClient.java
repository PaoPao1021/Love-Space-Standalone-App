package com.lovespace.server.notification;

import com.fasterxml.jackson.databind.ObjectMapper;
import nl.martijndwars.webpush.Notification;
import nl.martijndwars.webpush.PushService;
import org.apache.http.HttpResponse;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.util.Map;

@Component
public class WebPushDeliveryClient implements PushDeliveryClient {
  private final ObjectMapper mapper;
  private final String publicKey;
  private final String privateKey;
  private final String subject;

  public WebPushDeliveryClient(
      ObjectMapper mapper,
      @Value("${lovespace.push.web.vapid-public-key:}") String publicKey,
      @Value("${lovespace.push.web.vapid-private-key:}") String privateKey,
      @Value("${lovespace.push.web.subject:mailto:admin@localhost}") String subject
  ) {
    this.mapper = mapper;
    this.publicKey = publicKey;
    this.privateKey = privateKey;
    this.subject = subject;
  }

  @Override public boolean supports(String provider) { return "webpush".equals(provider); }

  @Override
  public DeliveryResult send(Subscription subscription, Message message) throws Exception {
    if (publicKey.isBlank() || privateKey.isBlank()) return DeliveryResult.retry("VAPID 未配置");
    PushService service = new PushService(publicKey, privateKey, subject);
    String payload = mapper.writeValueAsString(Map.of(
        "title", message.title(), "body", message.body(), "path", message.path()));
    Notification notification = new Notification(
        subscription.endpoint(), subscription.publicKey(), subscription.authSecret(),
        payload.getBytes(StandardCharsets.UTF_8));
    HttpResponse response = service.send(notification);
    int status = response.getStatusLine().getStatusCode();
    if (status >= 200 && status < 300) return DeliveryResult.sent();
    if (status == 404 || status == 410) return DeliveryResult.invalid("Web Push HTTP " + status);
    return DeliveryResult.retry("Web Push HTTP " + status);
  }
}
