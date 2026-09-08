package com.lovespace.server.notification;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Component
public class NotificationOutboxWorker {
  private static final int MAX_ATTEMPTS = 12;
  private final JdbcClient jdbc;
  private final TransactionTemplate transactions;
  private final List<PushDeliveryClient> clients;
  private final boolean enabled;
  private final String workerId = UUID.randomUUID().toString();

  public NotificationOutboxWorker(
      JdbcClient jdbc,
      TransactionTemplate transactions,
      List<PushDeliveryClient> clients,
      @Value("${lovespace.push.delivery-enabled:false}") boolean enabled
  ) {
    this.jdbc = jdbc;
    this.transactions = transactions;
    this.clients = clients;
    this.enabled = enabled;
  }

  @Scheduled(fixedDelayString = "${lovespace.push.worker-delay:15s}")
  public void deliverDue() {
    if (!enabled) return;
    for (int index = 0; index < 20; index++) {
      OutboxItem item = claim();
      if (item == null) return;
      deliver(item);
    }
  }

  private OutboxItem claim() {
    return transactions.execute(status -> {
      Instant now = Instant.now();
      OutboxItem item = jdbc.sql("""
              SELECT o.id, o.notification_id, o.user_id, o.attempt_count,
                     n.title, n.content, n.type, n.related_id
              FROM notification_outbox o
              JOIN notifications n ON n.id = o.notification_id
              WHERE o.status IN ('pending','failed') AND o.next_attempt_at <= :now
                AND (o.lease_until IS NULL OR o.lease_until < :now)
              ORDER BY o.next_attempt_at, o.created_at
              LIMIT 1 FOR UPDATE SKIP LOCKED
              """)
          .param("now", now)
          .query((rs, rowNum) -> new OutboxItem(
              rs.getString("id"), rs.getString("notification_id"), rs.getString("user_id"),
              rs.getInt("attempt_count"), rs.getString("title"), rs.getString("content"),
              rs.getString("type"), rs.getString("related_id")))
          .optional().orElse(null);
      if (item == null) return null;
      jdbc.sql("UPDATE notification_outbox SET lease_owner=:owner, lease_until=:until WHERE id=:id")
          .param("owner", workerId).param("until", now.plusSeconds(60)).param("id", item.id()).update();
      return item;
    });
  }

  private void deliver(OutboxItem item) {
    List<SubscriptionRow> subscriptions = jdbc.sql("""
            SELECT id, provider, endpoint, public_key, auth_secret
            FROM push_subscriptions WHERE user_id=:user AND status='active'
            """)
        .param("user", item.userId())
        .query((rs, rowNum) -> new SubscriptionRow(
            rs.getString("id"), rs.getString("provider"), rs.getString("endpoint"),
            rs.getString("public_key"), rs.getString("auth_secret")))
        .list();
    boolean retry = false;
    String lastError = "";
    for (SubscriptionRow subscription : subscriptions) {
      PushDeliveryClient client = clients.stream().filter(value -> value.supports(subscription.provider()))
          .findFirst().orElse(null);
      if (client == null) {
        retry = true;
        lastError = "缺少推送提供方: " + subscription.provider();
        continue;
      }
      try {
        var result = client.send(
            new PushDeliveryClient.Subscription(subscription.id(), subscription.endpoint(),
                subscription.publicKey(), subscription.authSecret()),
            new PushDeliveryClient.Message(item.title(), item.content(), deepLink(item.type(), item.relatedId())));
        if (result.subscriptionInvalid()) disable(subscription.id(), result.detail());
        else if (!result.delivered()) {
          retry = true;
          lastError = result.detail();
        }
      } catch (Exception exception) {
        retry = true;
        lastError = exception.getMessage() == null ? exception.getClass().getSimpleName() : exception.getMessage();
      }
    }
    if (!retry) markSent(item.id()); else markFailed(item, lastError);
  }

  private void disable(String id, String error) {
    jdbc.sql("""
            UPDATE push_subscriptions SET status='disabled', last_failure_at=:now, updated_at=:now
            WHERE id=:id
            """).param("now", Instant.now()).param("id", id).update();
  }

  private void markSent(String id) {
    jdbc.sql("""
            UPDATE notification_outbox SET status='sent', sent_at=:now, lease_owner=NULL, lease_until=NULL,
              last_error='' WHERE id=:id AND lease_owner=:owner
            """).param("now", Instant.now()).param("id", id).param("owner", workerId).update();
  }

  private void markFailed(OutboxItem item, String error) {
    int attempts = item.attempts() + 1;
    String status = attempts >= MAX_ATTEMPTS ? "dead" : "failed";
    jdbc.sql("""
            UPDATE notification_outbox SET status=:status, attempt_count=:attempts,
              next_attempt_at=:next, last_error=:error, lease_owner=NULL, lease_until=NULL
            WHERE id=:id AND lease_owner=:owner
            """)
        .param("status", status).param("attempts", attempts)
        .param("next", Instant.now().plus(backoff(attempts)))
        .param("error", truncate(error, 500)).param("id", item.id()).param("owner", workerId).update();
  }

  static Duration backoff(int attempts) {
    long seconds = Math.min(6 * 60 * 60, 15L * (1L << Math.min(10, Math.max(0, attempts - 1))));
    return Duration.ofSeconds(seconds);
  }

  static String deepLink(String type, String relatedId) {
    String id = relatedId == null ? "" : relatedId;
    return switch (type == null ? "" : type) {
      case "daily-question" -> "/daily-question";
      case "moment" -> id.isBlank() ? "/moments" : "/moments/" + id;
      case "mood" -> "/mood";
      case "photo" -> id.isBlank() ? "/album" : "/album/" + id;
      case "anniversary" -> "/anniversaries";
      case "task", "task_complete" -> id.isBlank() ? "/tasks" : "/tasks/" + id;
      case "menu_order" -> "/menu";
      case "points" -> "/points";
      case "wish" -> id.isBlank() ? "/wishes" : "/wishes/" + id;
      case "capsule", "capsule_unlocked" -> id.isBlank() ? "/capsules" : "/capsules/" + id;
      case "fitness" -> "/fitness";
      case "quiz" -> "/quiz";
      default -> "/notifications";
    };
  }

  private static String truncate(String value, int max) {
    String text = value == null ? "" : value;
    return text.substring(0, Math.min(text.length(), max));
  }

  private record OutboxItem(
      String id, String notificationId, String userId, int attempts,
      String title, String content, String type, String relatedId
  ) {}

  private record SubscriptionRow(String id, String provider, String endpoint, String publicKey, String authSecret) {}
}
