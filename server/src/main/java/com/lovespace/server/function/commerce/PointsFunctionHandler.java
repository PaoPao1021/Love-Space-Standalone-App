package com.lovespace.server.function.commerce;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import com.lovespace.server.wechat.TextSafetyService;
import com.lovespace.server.notification.PartnerNotificationService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Instant;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Component
public class PointsFunctionHandler extends FunctionSupport {
  private static final Map<String, Integer> BUILT_IN = Map.of(
      "一次按摩", 30, "一杯奶茶", 20, "电影选择权", 50, "免做家务一次", 40,
      "小惊喜", 60, "约会策划权", 80, "赖床特权", 25, "专属大餐", 100);
  private final CoupleAccessService couples;
  private final TextSafetyService safety;
  private final TransactionTemplate transactions;
  private final PartnerNotificationService notifications;

  public PointsFunctionHandler(
      JdbcClient jdbc,
      ObjectMapper mapper,
      CoupleAccessService couples,
      TextSafetyService safety,
      TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper);
    this.couples = couples;
    this.safety = safety;
    this.transactions = transactions;
    this.notifications = notifications;
  }

  @Override public String functionName() { return "points"; }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode data = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, data);
      case "getScore" -> score(openid);
      case "list" -> list(openid, data);
      case "exchange" -> exchange(openid, data);
      case "getLevel" -> level(openid);
      case "addExchange" -> addExchange(openid, data);
      case "listExchanges" -> listExchanges(openid);
      case "listExchangeOptions" -> listExchangeOptions(openid);
      case "deleteExchange" -> deleteExchange(openid, data);
      case "listExchangeHistory" -> exchangeHistory(openid);
      default -> throw new BusinessException("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode data) {
    var couple = couples.require(openid);
    if (couple.otherId() == null || couple.otherId().isBlank()) throw new BusinessException("等待对方加入后再使用积分");
    int amount = data.path("amount").asInt(0);
    String reason = data.path("reason").asText("").trim();
    String note = truncate(data.path("note").asText(""), 200);
    if (amount == 0 || Math.abs(amount) > 1000) throw new BusinessException("积分需要是 -1000 到 1000 之间的非零整数");
    if (reason.isEmpty() || reason.length() > 30) throw new BusinessException("原因需要 1-30 个字");
    safety.check(openid, 1000, reason, note);
    String id = requestId("point", openid, data.path("requestId").asText(""));
    Boolean duplicated = transactions.execute(status -> {
      ensureBalance(couple.coupleId(), couple.otherId());
      int inserted = jdbc.sql("""
              INSERT IGNORE INTO points
                (id, couple_id, from_user, to_user, amount, reason, note, created_at)
              VALUES (:id, :couple, :from, :to, :amount, :reason, :note, :now)
              """)
          .param("id", id).param("couple", couple.coupleId()).param("from", openid)
          .param("to", couple.otherId()).param("amount", amount).param("reason", reason)
          .param("note", note).param("now", Instant.now()).update();
      if (inserted == 0) return true;
      jdbc.sql("""
              UPDATE point_balances SET score = score + :amount, updated_at = :now
              WHERE couple_id = :couple AND user_id = :user
              """)
          .param("amount", amount).param("now", Instant.now())
          .param("couple", couple.coupleId()).param("user", couple.otherId()).update();
      return false;
    });
    if (!Boolean.TRUE.equals(duplicated)) {
      notifications.notifyPartner(openid, "points", "TA 更新了你的积分",
          (amount > 0 ? "+" : "") + amount + " · " + reason,
          id, "points:" + id);
    }
    return mutable("id", id, "duplicated", Boolean.TRUE.equals(duplicated));
  }

  private Map<String, Object> score(String openid) {
    var couple = couples.require(openid);
    ensureBalance(couple.coupleId(), openid);
    if (couple.otherId() != null && !couple.otherId().isBlank()) ensureBalance(couple.coupleId(), couple.otherId());
    long mine = balance(couple.coupleId(), openid);
    long partner = couple.otherId() == null || couple.otherId().isBlank() ? 0L : balance(couple.coupleId(), couple.otherId());
    return mutable("myScore", mine, "partnerScore", partner, "myId", openid, "partnerId", couple.otherId() == null ? "" : couple.otherId());
  }

  private Map<String, Object> list(String openid, JsonNode data) {
    var couple = couples.require(openid);
    int page = Math.max(1, data.path("page").asInt(1));
    int pageSize = Math.min(50, Math.max(1, data.path("pageSize").asInt(20)));
    long total = jdbc.sql("SELECT COUNT(*) FROM points WHERE couple_id = :couple")
        .param("couple", couple.coupleId()).query(Long.class).single();
    List<Map<String, Object>> list = rows("""
        SELECT * FROM points WHERE couple_id = :couple
        ORDER BY created_at DESC LIMIT :limit OFFSET :offset
        """, Map.of("couple", couple.coupleId(), "limit", pageSize, "offset", (page - 1) * pageSize));
    return mutable("list", list, "total", total);
  }

  private Map<String, Object> exchange(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String item = data.path("item").asText("").trim();
    int amount = data.path("amount").asInt(0);
    String exchangeId = data.path("exchangeId").asText("");
    if (!exchangeId.isBlank()) {
      Map<String, Object> exchange = one(
          "SELECT * FROM point_exchanges WHERE id = :id AND couple_id = :couple",
          Map.of("id", exchangeId, "couple", couple.coupleId()), "兑换项目不存在");
      item = String.valueOf(exchange.get("name"));
      amount = ((Number) exchange.get("cost")).intValue();
    } else if (!BUILT_IN.containsKey(item) || BUILT_IN.get(item) != amount) {
      throw new BusinessException("兑换项目参数无效");
    }
    if (amount <= 0 || amount > 10000) throw new BusinessException("兑换积分无效");
    String note = truncate(data.path("note").asText(""), 200);
    safety.check(openid, 1000, item, note);
    ensureBalance(couple.coupleId(), openid);
    String recordId = requestId("exchange", openid, data.path("requestId").asText(""));
    String pointId = hash("exchange-point:" + recordId);
    final String finalItem = item;
    final int finalAmount = amount;
    final String finalExchangeId = exchangeId;
    Boolean duplicated = transactions.execute(status -> {
      Long current = jdbc.sql("""
              SELECT score FROM point_balances
              WHERE couple_id = :couple AND user_id = :user FOR UPDATE
              """)
          .param("couple", couple.coupleId()).param("user", openid).query(Long.class).single();
      int inserted = jdbc.sql("""
              INSERT IGNORE INTO point_exchange_records
                (id, couple_id, user_id, exchange_id, item_name, cost, created_at)
              VALUES (:id, :couple, :user, :exchange, :item, :cost, :now)
              """)
          .param("id", recordId).param("couple", couple.coupleId()).param("user", openid)
          .param("exchange", finalExchangeId).param("item", finalItem).param("cost", finalAmount)
          .param("now", Instant.now()).update();
      if (inserted == 0) return true;
      if (current < finalAmount) {
        status.setRollbackOnly();
        throw new BusinessException("积分不足，还差 " + (finalAmount - current));
      }
      jdbc.sql("""
              INSERT INTO points (id, couple_id, from_user, to_user, amount, reason, note, created_at)
              VALUES (:id, :couple, :user, :user, :amount, :reason, :note, :now)
              """)
          .param("id", pointId).param("couple", couple.coupleId()).param("user", openid)
          .param("amount", -finalAmount).param("reason", "兑换: " + finalItem).param("note", note)
          .param("now", Instant.now()).update();
      jdbc.sql("UPDATE point_balances SET score = score - :amount, updated_at = :now WHERE couple_id = :couple AND user_id = :user")
          .param("amount", finalAmount).param("now", Instant.now())
          .param("couple", couple.coupleId()).param("user", openid).update();
      return false;
    });
    return mutable("id", pointId, "duplicated", Boolean.TRUE.equals(duplicated));
  }

  private Map<String, Object> level(String openid) {
    long score = ((Number) score(openid).get("myScore")).longValue();
    List<Map<String, Object>> levels = List.of(
        Map.of("name", "新手情侣", "min", 0, "icon", "🌱"),
        Map.of("name", "甜蜜搭子", "min", 100, "icon", "🍬"),
        Map.of("name", "默契满分", "min", 500, "icon", "💯"),
        Map.of("name", "神仙伴侣", "min", 1000, "icon", "👼"),
        Map.of("name", "灵魂伴侣", "min", 2000, "icon", "💖"),
        Map.of("name", "天作之合", "min", 5000, "icon", "👑"));
    Map<String, Object> current = levels.getFirst();
    Map<String, Object> next = levels.get(1);
    for (int index = 0; index < levels.size(); index++) {
      if (score >= ((Number) levels.get(index).get("min")).longValue()) {
        current = levels.get(index);
        next = index + 1 < levels.size() ? levels.get(index + 1) : null;
      }
    }
    return mutable("current", current, "next", next, "score", score);
  }

  private Map<String, Object> addExchange(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String name = data.path("name").asText("").trim();
    int cost = data.path("cost").asInt(0);
    if (name.isEmpty() || name.length() > 30 || cost <= 0 || cost > 10000) {
      throw new BusinessException("请输入 1-30 字名称和有效积分数");
    }
    safety.check(openid, 1000, name);
    String id = newId();
    jdbc.sql("""
            INSERT INTO point_exchanges (id, couple_id, name, cost, icon, created_by, created_at)
            VALUES (:id, :couple, :name, :cost, :icon, :user, :now)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("name", name).param("cost", cost)
        .param("icon", truncate(data.path("icon").asText("🎁"), 8)).param("user", openid)
        .param("now", Instant.now()).update();
    return ok("id", id);
  }

  private Map<String, Object> listExchanges(String openid) {
    var couple = couples.require(openid);
    return ok("list", rows("SELECT * FROM point_exchanges WHERE couple_id = :couple ORDER BY created_at DESC",
        Map.of("couple", couple.coupleId())));
  }

  private Map<String, Object> listExchangeOptions(String openid) {
    var couple = couples.require(openid);
    List<Map<String, Object>> result = new java.util.ArrayList<>();
    BUILT_IN.entrySet().stream().sorted(Map.Entry.comparingByValue()).forEach(entry ->
        result.add(Map.of("_id", "", "name", entry.getKey(), "cost", entry.getValue(),
            "builtIn", true, "createdBy", "")));
    List<Map<String, Object>> custom = rows(
        "SELECT * FROM point_exchanges WHERE couple_id = :couple ORDER BY created_at DESC",
        Map.of("couple", couple.coupleId()));
    custom.forEach(item -> {
      item.put("builtIn", false);
      result.add(item);
    });
    return ok("list", result);
  }

  private Map<String, Object> deleteExchange(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String id = requiredText(data, "id", "缺少ID");
    int changed = jdbc.sql("DELETE FROM point_exchanges WHERE id = :id AND couple_id = :couple")
        .param("id", id).param("couple", couple.coupleId()).update();
    if (changed == 0) throw new BusinessException("无权删除该项目");
    return ok();
  }

  private Map<String, Object> exchangeHistory(String openid) {
    var couple = couples.require(openid);
    return ok("list", rows("""
        SELECT * FROM point_exchange_records WHERE couple_id = :couple
        ORDER BY created_at DESC LIMIT 20
        """, Map.of("couple", couple.coupleId())));
  }

  private void ensureBalance(String coupleId, String userId) {
    if (userId == null || userId.isBlank()) return;
    jdbc.sql("""
            INSERT IGNORE INTO point_balances (id, couple_id, user_id, score, updated_at)
            SELECT :id, :couple, :user, COALESCE(SUM(amount), 0), :now
            FROM points WHERE couple_id = :couple AND to_user = :user
            """)
        .param("id", hash("balance:" + coupleId + ":" + userId))
        .param("couple", coupleId).param("user", userId).param("now", Instant.now()).update();
  }

  private long balance(String coupleId, String userId) {
    return jdbc.sql("SELECT score FROM point_balances WHERE couple_id = :couple AND user_id = :user")
        .param("couple", coupleId).param("user", userId).query(Long.class).single();
  }

  private static String requestId(String prefix, String openid, String requestId) {
    String normalized = requestId == null ? "" : requestId.trim();
    if (!normalized.isEmpty() && !normalized.matches("^[A-Za-z0-9_-]{8,80}$")) throw new BusinessException("请求标识无效");
    String token = normalized.isEmpty() ? UUID.randomUUID().toString() : normalized;
    return hash(prefix + ":" + openid + ":" + token);
  }

  public static String hash(String value) {
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
      return HexFormat.of().formatHex(digest).substring(0, 32);
    } catch (Exception exception) {
      throw new IllegalStateException(exception);
    }
  }

  private static String truncate(String value, int max) {
    return value.substring(0, Math.min(value.length(), max));
  }

  private static Map<String, Object> mutable(Object... entries) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    for (int i = 0; i < entries.length; i += 2) result.put((String) entries[i], entries[i + 1]);
    return result;
  }
}
