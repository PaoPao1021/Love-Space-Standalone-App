package com.lovespace.server.notification;

import com.lovespace.server.domain.CoupleAccessService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
public class PartnerNotificationService {
  private final JdbcClient jdbc;
  private final CoupleAccessService couples;
  private final NotificationOutboxService outbox;

  public PartnerNotificationService(JdbcClient jdbc, CoupleAccessService couples, NotificationOutboxService outbox) {
    this.jdbc = jdbc;
    this.couples = couples;
    this.outbox = outbox;
  }

  public boolean notifyPartner(
      String fromUser, String type, String title, String content, String relatedId, String deduplicationKey
  ) {
    var couple = couples.require(fromUser);
    if (couple.otherId() == null || couple.otherId().isBlank()) return false;
    String id = com.lovespace.server.function.commerce.PointsFunctionHandler.hash(
        "notification:" + deduplicationKey + ":" + couple.otherId());
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO notifications
              (id,couple_id,to_user,from_user,from_name,type,title,content,related_id,is_read,created_at)
            VALUES (:id,:couple,:to,:from,:name,:type,:title,:content,:related,0,:now)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("to", couple.otherId())
        .param("from", fromUser).param("name", couples.nickname(fromUser)).param("type", truncate(type, 32))
        .param("title", truncate(title, 50)).param("content", truncate(content, 500))
        .param("related", relatedId == null || relatedId.isBlank() ? null : relatedId)
        .param("now", Instant.now()).update();
    if (inserted == 1) outbox.enqueue(id, couple.otherId());
    return inserted == 1;
  }

  private static String truncate(String value, int max) {
    String text = value == null ? "" : value;
    return text.substring(0, Math.min(text.length(), max));
  }
}
