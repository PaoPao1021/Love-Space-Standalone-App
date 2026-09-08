package com.lovespace.server.function.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.storage.MediaService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class AnniversaryFunctionHandler extends ContentFunctionSupport {
  private static final Set<String> TYPES = Set.of("together", "birthday", "valentine", "meet", "first", "custom");

  public AnniversaryFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
  }

  @Override
  public String functionName() {
    return "anniversary";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, input);
      case "update" -> updateAnniversary(openid, input);
      case "delete" -> delete(openid, input);
      case "list" -> list(openid);
      case "get" -> Map.of("code", 0, "data", present(openid, owned(openid, trimmed(input, "id"))));
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return fail("未绑定");
    String name = trimmed(input, "name");
    String rawDate = text(input, "date");
    LocalDate anniversaryDate = date(rawDate);
    if (name.isEmpty() || name.length() > 30) return fail("纪念日名称需要 1-30 个字");
    if (anniversaryDate == null) return fail("日期格式不正确");
    String note = slice(text(input, "note"), 500);
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 1000, name, note);
    String type = text(input, "type");
    if (!TYPES.contains(type)) type = "custom";
    String cover = mediaForStorage(openid, text(input, "coverUrl"));
    int reminder = Math.min(30, Math.max(0, integer(input, "remindDaysBefore", 0)));
    String id = newId();
    Instant now = now();
    jdbc.sql("""
            INSERT INTO anniversaries
              (id, couple_id, name, date, type, cover_url, note, is_repeat,
               remind_days_before, is_top, created_at, updated_at)
            VALUES (:id, :couple, :name, :date, :type, :cover, :note, :repeat,
                    :reminder, :top, :now, :now)
            """)
        .param("id", id).param("couple", coupleId).param("name", name).param("date", anniversaryDate)
        .param("type", type).param("cover", cover).param("note", note)
        .param("repeat", bool(input, "isRepeat", true)).param("reminder", reminder)
        .param("top", bool(input, "isTop", false)).param("now", now).update();
    return ok("id", id);
  }

  private Map<String, Object> updateAnniversary(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    owned(openid, id);
    Map<String, Object> values = new LinkedHashMap<>();
    StringBuilder set = new StringBuilder();
    if (input.has("name")) {
      String value = trimmed(input, "name");
      if (value.isEmpty() || value.length() > 30) return fail("纪念日名称需要 1-30 个字");
      append(set, "name = :name"); values.put("name", value);
    }
    if (input.has("date")) {
      LocalDate value = date(text(input, "date"));
      if (value == null) return fail("日期格式不正确");
      append(set, "date = :date"); values.put("date", value);
    }
    if (input.has("type")) {
      String value = text(input, "type");
      append(set, "type = :type"); values.put("type", TYPES.contains(value) ? value : "custom");
    }
    if (input.has("coverUrl")) {
      append(set, "cover_url = :cover"); values.put("cover", mediaForStorage(openid, text(input, "coverUrl")));
    }
    if (input.has("note")) {
      append(set, "note = :note"); values.put("note", slice(text(input, "note"), 500));
    }
    if (input.has("isRepeat")) {
      append(set, "is_repeat = :repeat"); values.put("repeat", bool(input, "isRepeat", false));
    }
    if (input.has("remindDaysBefore")) {
      append(set, "remind_days_before = :reminder");
      values.put("reminder", Math.min(30, Math.max(0, integer(input, "remindDaysBefore", 0))));
    }
    if (input.has("isTop")) {
      append(set, "is_top = :top"); values.put("top", bool(input, "isTop", false));
    }
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 1000,
        values.getOrDefault("name", ""), values.getOrDefault("note", ""));
    values.put("now", now());
    values.put("id", id);
    String assignments = set.isEmpty() ? "updated_at = :now" : set + ", updated_at = :now";
    update("UPDATE anniversaries SET " + assignments + " WHERE id = :id", values);
    return ok();
  }

  private Map<String, Object> delete(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    owned(openid, id);
    jdbc.sql("DELETE FROM anniversaries WHERE id = :id").param("id", id).update();
    return ok();
  }

  private Map<String, Object> list(String openid) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return ok("list", List.of());
    List<Map<String, Object>> list = rows("""
        SELECT * FROM anniversaries WHERE couple_id = :couple
        ORDER BY is_top DESC, date ASC
        """, Map.of("couple", coupleId));
    list.replaceAll(item -> present(openid, item));
    return ok("list", list);
  }

  private Map<String, Object> owned(String openid, String id) {
    if (id.isBlank()) throw error("缺少记录 ID");
    String coupleId = requireCoupleId(openid);
    return one("SELECT * FROM anniversaries WHERE id = :id AND couple_id = :couple",
        Map.of("id", id, "couple", coupleId), "无权操作该纪念日");
  }

  private Map<String, Object> present(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    booleanFields(result, "isRepeat", "isTop");
    dateFields(result, "date");
    displayMedia(openid, result, "coverUrl", "coverAssetId");
    return result;
  }

  private static void append(StringBuilder set, String assignment) {
    if (!set.isEmpty()) set.append(", ");
    set.append(assignment);
  }
}
