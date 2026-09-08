package com.lovespace.server.notification;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

@Service
public class NotificationOutboxService {
  private final JdbcClient jdbc;

  public NotificationOutboxService(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public void enqueue(String notificationId, String userId) {
    jdbc.sql("""
            INSERT IGNORE INTO notification_outbox
              (id, notification_id, user_id, status, attempt_count, next_attempt_at, created_at)
            VALUES (:id, :notification, :user, 'pending', 0, :now, :now)
            """)
        .param("id", UUID.randomUUID().toString())
        .param("notification", notificationId)
        .param("user", userId)
        .param("now", Instant.now())
        .update();
  }
}
