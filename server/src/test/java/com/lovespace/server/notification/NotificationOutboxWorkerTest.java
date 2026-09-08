package com.lovespace.server.notification;

import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;

class NotificationOutboxWorkerTest {
  @Test
  void retryDelayUsesBoundedExponentialBackoff() {
    assertEquals(Duration.ofSeconds(15), NotificationOutboxWorker.backoff(1));
    assertEquals(Duration.ofSeconds(30), NotificationOutboxWorker.backoff(2));
    assertEquals(Duration.ofSeconds(60), NotificationOutboxWorker.backoff(3));
    assertEquals(Duration.ofMinutes(256), NotificationOutboxWorker.backoff(20));
  }

  @Test
  void secondStageNotificationsOpenTheirRealDestination() {
    assertEquals("/tasks/task-1", NotificationOutboxWorker.deepLink("task", "task-1"));
    assertEquals("/tasks/task-1", NotificationOutboxWorker.deepLink("task_complete", "task-1"));
    assertEquals("/menu", NotificationOutboxWorker.deepLink("menu_order", "order-1"));
    assertEquals("/points", NotificationOutboxWorker.deepLink("points", "point-1"));
    assertEquals("/wishes/wish-1", NotificationOutboxWorker.deepLink("wish", "wish-1"));
    assertEquals("/capsules/capsule-1", NotificationOutboxWorker.deepLink("capsule", "capsule-1"));
    assertEquals("/fitness", NotificationOutboxWorker.deepLink("fitness", "challenge-1"));
    assertEquals("/quiz", NotificationOutboxWorker.deepLink("quiz", "quiz-1"));
  }
}
