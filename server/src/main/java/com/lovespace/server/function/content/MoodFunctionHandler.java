package com.lovespace.server.function.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.storage.MediaService;
import com.lovespace.server.notification.PartnerNotificationService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.LocalDate;
import java.time.YearMonth;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class MoodFunctionHandler extends ContentFunctionSupport {
  private final PartnerNotificationService notifications;
  private static final Set<String> MOODS = Set.of(
      "happy", "love", "calm", "excited", "miss", "grateful", "tired", "anxious", "sad", "angry");

  public MoodFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "mood";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, input);
      case "getToday" -> getToday(openid);
      case "list" -> list(openid, input);
      case "getCalendar" -> calendar(openid, input);
      case "getPartner" -> partner(openid, input);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return fail("请先绑定情侣关系");
    String moodType = text(input, "moodType");
    if (!MOODS.contains(moodType)) return fail("请选择有效心情");
    String requestedVisibility = text(input, "visibility");
    String visibility = "self".equals(requestedVisibility) || "both".equals(requestedVisibility)
        ? requestedVisibility : "both";
    String content = slice(text(input, "content"), 500);
    String emoji = slice(text(input, "moodEmoji"), 8);
    List<String> images = mediaListForStorage(openid, imageInput(input), 9);
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 500, content);
    LocalDate day = today();
    Map<String, Object> result = transactions.execute(status -> {
      jdbc.sql("SELECT id FROM users WHERE id = :id FOR UPDATE").param("id", openid).query(String.class).single();
      String existing = jdbc.sql("SELECT id FROM moods WHERE couple_id = :couple AND user_id = :user AND date = :date FOR UPDATE")
          .param("couple", coupleId).param("user", openid).param("date", day).query(String.class).optional().orElse(null);
      boolean updated = existing != null;
      String id = updated ? existing : hash32("mood:" + coupleId + ":" + openid + ":" + day);
      if (updated) {
        jdbc.sql("""
                UPDATE moods SET mood_type = :type, mood_emoji = :emoji, content = :content,
                    images = :images, visibility = :visibility, updated_at = :now
                WHERE id = :id
                """)
            .param("type", moodType).param("emoji", emoji).param("content", content)
            .param("images", json(images)).param("visibility", visibility).param("now", now()).param("id", id).update();
      } else {
        jdbc.sql("""
                INSERT INTO moods
                  (id, couple_id, user_id, mood_type, mood_emoji, content, images,
                   visibility, date, created_at, updated_at)
                VALUES (:id, :couple, :user, :type, :emoji, :content, :images,
                        :visibility, :date, :now, :now)
                """)
            .param("id", id).param("couple", coupleId).param("user", openid).param("type", moodType)
            .param("emoji", emoji).param("content", content).param("images", json(images))
            .param("visibility", visibility).param("date", day).param("now", now()).update();
      }
      Map<String, Object> response = new LinkedHashMap<>();
      response.put("code", 0); response.put("id", id); response.put("updated", updated);
      return response;
    });
    if ("both".equals(visibility)) {
      notifications.notifyPartner(openid, "mood", "TA 更新了今天的心情",
          "去看看 TA 此刻的心情。", String.valueOf(result.get("id")),
          "mood:" + coupleId + ":" + openid + ":" + day);
    }
    return result;
  }

  private Map<String, Object> getToday(String openid) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return nullableData(null);
    List<Map<String, Object>> list = rows("SELECT * FROM moods WHERE couple_id = :couple AND user_id = :user AND date = :date",
        Map.of("couple", coupleId, "user", openid, "date", today()));
    return nullableData(list.isEmpty() ? null : present(openid, list.getFirst()));
  }

  private Map<String, Object> list(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return ok("list", List.of());
    int page = Math.max(1, integer(input, "page", 1));
    int pageSize = Math.min(60, Math.max(1, integer(input, "pageSize", 30)));
    Map<String, Object> base = Map.of("couple", coupleId, "openid", openid);
    long total = count("""
        SELECT COUNT(*) FROM moods
        WHERE couple_id = :couple AND (user_id = :openid OR visibility = 'both')
        """, base);
    Map<String, Object> params = new LinkedHashMap<>(base);
    params.put("limit", pageSize); params.put("offset", (page - 1) * pageSize);
    List<Map<String, Object>> list = rows("""
        SELECT * FROM moods
        WHERE couple_id = :couple AND (user_id = :openid OR visibility = 'both')
        ORDER BY date DESC LIMIT :limit OFFSET :offset
        """, params);
    list.replaceAll(item -> present(openid, item));
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("list", list); result.put("total", total);
    result.put("hasMore", (long) (page - 1) * pageSize + list.size() < total);
    return result;
  }

  private Map<String, Object> calendar(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return ok("list", List.of());
    int year = integer(input, "year", 0);
    int month = integer(input, "month", 0);
    if (year < 2000 || year > 2100 || month < 1 || month > 12) return fail("月份参数无效");
    YearMonth selected = YearMonth.of(year, month);
    List<Map<String, Object>> list = rows("""
        SELECT * FROM moods
        WHERE couple_id = :couple AND date BETWEEN :start AND :end
          AND (user_id = :openid OR visibility = 'both')
        """, Map.of("couple", coupleId, "start", selected.atDay(1), "end", selected.atEndOfMonth(), "openid", openid));
    list.replaceAll(item -> present(openid, item));
    return ok("list", list);
  }

  private Map<String, Object> partner(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return nullableData(null);
    CoupleAccessService.CoupleContext context = couples.require(openid);
    if (context.otherId() == null || context.otherId().isBlank()) return nullableData(null);
    String rawDate = input.has("date") ? text(input, "date") : today().toString();
    LocalDate selected = date(rawDate);
    if (selected == null) return fail("日期参数无效");
    List<Map<String, Object>> found = rows("""
        SELECT * FROM moods
        WHERE couple_id = :couple AND user_id = :partner AND date = :date AND visibility = 'both'
        """, Map.of("couple", coupleId, "partner", context.otherId(), "date", selected));
    return nullableData(found.isEmpty() ? null : present(openid, found.getFirst()));
  }

  private Map<String, Object> present(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    result.put("isMine", openid.equals(String.valueOf(result.get("userId"))));
    dateFields(result, "date");
    displayMediaList(openid, result, "images", "imageAssetIds");
    return result;
  }

  private JsonNode imageInput(JsonNode input) {
    JsonNode raw = input.get("imageAssetIds");
    return raw != null && raw.isArray() ? raw : input.get("images");
  }

  private long count(String sql, Map<String, ?> params) {
    var spec = jdbc.sql(sql);
    for (Map.Entry<String, ?> entry : params.entrySet()) spec = spec.param(entry.getKey(), entry.getValue());
    return spec.query(Long.class).single();
  }

  private static Map<String, Object> nullableData(Object value) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("data", value);
    return result;
  }
}
