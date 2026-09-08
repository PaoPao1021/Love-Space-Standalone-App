package com.lovespace.server.notification;

public interface PushDeliveryClient {
  boolean supports(String provider);

  DeliveryResult send(Subscription subscription, Message message) throws Exception;

  record Subscription(String id, String endpoint, String publicKey, String authSecret) {}

  record Message(String title, String body, String path) {}

  record DeliveryResult(boolean delivered, boolean subscriptionInvalid, String detail) {
    public static DeliveryResult sent() { return new DeliveryResult(true, false, ""); }
    public static DeliveryResult invalid(String detail) { return new DeliveryResult(false, true, detail); }
    public static DeliveryResult retry(String detail) { return new DeliveryResult(false, false, detail); }
  }
}
