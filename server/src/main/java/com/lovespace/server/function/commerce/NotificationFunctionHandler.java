package com.lovespace.server.function.commerce;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import com.lovespace.server.notification.NotificationOutboxService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import java.time.Instant;
import java.time.LocalDate;
import java.time.MonthDay;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

@Component
public class NotificationFunctionHandler extends FunctionSupport {
  private static final ZoneId CHINA = ZoneId.of("Asia/Shanghai");
  private final CoupleAccessService couples;
  private final NotificationOutboxService outbox;

  public NotificationFunctionHandler(JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
                                     NotificationOutboxService outbox) {
    super(jdbc, mapper);
    this.couples = couples;
    this.outbox = outbox;
  }

  @Override public String functionName() { return "notification"; }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    return switch (action(event)) {
      case "orderNotify" -> orderNotify(openid, data(event));
      case "list" -> list(openid);
      case "unreadCount" -> unreadCount(openid);
      case "read" -> read(openid, data(event));
      case "readAll" -> readAll(openid);
      case "checkReminders" -> throw new BusinessException("仅允许定时任务调用");
      default -> throw new BusinessException("未知操作");
    };
  }

  private Map<String, Object> orderNotify(String openid, JsonNode data) {
    String orderId = requiredText(data, "orderId", "缺少订单ID");
    var couple = couples.require(openid);
    Map<String, Object> order = one("SELECT * FROM orders WHERE id=:id AND couple_id=:couple AND ordered_by=:user",
        Map.of("id", orderId, "couple", couple.coupleId(), "user", openid), "订单不存在或无权通知");
    List<Map<String, Object>> items = order.get("items") instanceof List<?> list
        ? mapper.convertValue(list, new TypeReference<>() {}) : List.of();
    if (items.isEmpty() || items.size() > 30) throw new BusinessException("通知内容无效");
    if (couple.otherId() == null || couple.otherId().isBlank()) return ok();
    String sender = couples.nickname(openid);
    String names = items.stream().map(item -> String.valueOf(item.getOrDefault("name", "")))
        .filter(value -> !value.isBlank()).reduce((a, b) -> a + "、" + b).orElse("");
    String id = PointsFunctionHandler.hash("order-notification:" + orderId + ":" + couple.otherId());
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO notifications
              (id,couple_id,to_user,from_user,from_name,type,title,content,related_id,is_read,created_at)
            VALUES (:id,:couple,:to,:from,:name,'order','TA想点菜',:content,:related,0,:now)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("to", couple.otherId())
        .param("from", openid).param("name", sender)
        .param("content", truncate(sender + "想和你一起吃：" + names, 500))
        .param("related", orderId).param("now", Instant.now()).update();
    if (inserted == 0) return Map.of("code", 0, "duplicated", true);
    outbox.enqueue(id, couple.otherId());
    return ok();
  }

  private Map<String, Object> list(String openid) {
    String coupleId;
    try {
      coupleId = couples.require(openid).coupleId();
    } catch (BusinessException ignored) {
      return ok("list", List.of());
    }
    List<Map<String, Object>> notifications = rows("""
        SELECT * FROM notifications
        WHERE couple_id=:couple AND to_user=:user
        ORDER BY created_at DESC LIMIT 50
        """, Map.of("couple", coupleId, "user", openid));
    long unread = jdbc.sql("SELECT COUNT(*) FROM notifications WHERE to_user=:user AND is_read=0")
        .param("user", openid).query(Long.class).single();
    return Map.of("code", 0, "list", notifications, "unreadCount", unread);
  }

  private Map<String, Object> unreadCount(String openid) {
    long unread = jdbc.sql("SELECT COUNT(*) FROM notifications WHERE to_user=:user AND is_read=0")
        .param("user", openid).query(Long.class).single();
    return Map.of("code", 0, "unreadCount", unread);
  }

  private Map<String, Object> read(String openid, JsonNode data) {
    int changed = jdbc.sql("UPDATE notifications SET is_read=1 WHERE id=:id AND to_user=:user")
        .param("id", requiredText(data, "id", "缺少通知ID")).param("user", openid).update();
    if (changed == 0) throw new BusinessException("无权操作该通知");
    return ok();
  }

  private Map<String, Object> readAll(String openid) {
    int changed = jdbc.sql("UPDATE notifications SET is_read=1 WHERE to_user=:user AND is_read=0")
        .param("user", openid).update();
    return Map.of("code", 0, "changed", changed, "unreadCount", 0);
  }

  @Scheduled(cron = "0 0 1 * * *", zone = "Asia/Shanghai")
  public void scheduledAnniversaryReminders() {
    checkAnniversaryReminders(LocalDate.now(CHINA));
  }

  int checkAnniversaryReminders(LocalDate today) {
    List<Map<String, Object>> anniversaries = rows("""
        SELECT a.*, c.creator_id, c.partner_id
        FROM anniversaries a JOIN couples c ON c.id=a.couple_id
        WHERE c.status='active'
        """, Map.of());
    int created = 0;
    for (Map<String, Object> anniversary : anniversaries) {
      LocalDate original = toDate(anniversary.get("date"));
      boolean repeat = truthy(anniversary.get("isRepeat"));
      LocalDate target = original;
      if (repeat) {
        MonthDay day = MonthDay.from(original);
        target = day.atYear(today.getYear());
        if (target.isBefore(today)) target = day.atYear(today.getYear() + 1);
      }
      long days = ChronoUnit.DAYS.between(today, target);
      int before = Math.min(365, Math.max(0, ((Number) anniversary.getOrDefault("remindDaysBefore", 0)).intValue()));
      if (days < 0 || days > before || (days != 0 && days != 3)) continue;
      for (String user : List.of(String.valueOf(anniversary.get("creatorId")), String.valueOf(anniversary.get("partnerId")))) {
        if (user.isBlank() || "null".equals(user)) continue;
        if (sendReminder(user, anniversary, (int) days, today)) created++;
      }
    }
    return created;
  }

  private boolean sendReminder(String openid, Map<String, Object> anniversary, int days, LocalDate today) {
    String anniversaryId = String.valueOf(anniversary.get("_id"));
    String id = PointsFunctionHandler.hash("anniversary:" + anniversaryId + ":" + openid + ":" + today);
    String name = String.valueOf(anniversary.getOrDefault("name", "纪念日"));
    String timing = days == 0 ? "就是今天" : "还有 " + days + " 天";
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO notifications
              (id,couple_id,to_user,from_user,from_name,type,title,content,related_id,is_read,created_at)
            VALUES (:id,:couple,:to,NULL,'LoveSpace','anniversary','纪念日提醒',:content,:related,0,:now)
            """)
        .param("id", id).param("couple", anniversary.get("coupleId")).param("to", openid)
        .param("content", truncate(name + timing, 500)).param("related", anniversaryId)
        .param("now", Instant.now()).update();
    if (inserted == 0) return false;
    outbox.enqueue(id, openid);
    return true;
  }

  private static LocalDate toDate(Object value) {
    if (value instanceof LocalDate date) return date;
    if (value instanceof java.sql.Date date) return date.toLocalDate();
    return LocalDate.parse(String.valueOf(value));
  }

  private static boolean truthy(Object value) {
    return Boolean.TRUE.equals(value) || value instanceof Number number && number.intValue() != 0;
  }

  private static String truncate(String value, int max) { return value.substring(0, Math.min(max, value.length())); }
}
