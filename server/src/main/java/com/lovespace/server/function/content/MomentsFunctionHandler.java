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

import java.sql.Types;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class MomentsFunctionHandler extends ContentFunctionSupport {
  private final PartnerNotificationService notifications;
  public MomentsFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "moments";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, input);
      case "update" -> updateMoment(openid, input);
      case "delete" -> delete(openid, input);
      case "list" -> list(openid, input);
      case "get" -> Map.of("code", 0, "data", present(openid, owned(openid, trimmed(input, "id"))));
      case "random" -> random(openid);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return fail("请先绑定你们的空间");
    String title = slice(trimmed(input, "title"), 50);
    String content = slice(trimmed(input, "content"), 5000);
    List<String> images = mediaListForStorage(openid, imageInput(input), 9);
    String voice = slice(text(input, "voiceFileId"), 300);
    List<String> tags = stringList(input.get("tags"), 20, 10);
    LocalDate eventDate = eventDate(input);
    if (input.has("eventDate") && eventDate == null) return fail("发生日期无效");
    if (content.isBlank() && images.isEmpty() && voice.isBlank()) return fail("写点内容或添加一张照片吧");
    List<Object> safe = new ArrayList<>(tags);
    safe.addFirst(content); safe.addFirst(title);
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 5000, safe.toArray());
    String requestId = requestId(input);
    String id = requestId.isBlank() ? newId() : hash32("moment:" + openid + ":" + requestId);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO moments
              (id, couple_id, author_id, client_request_id, title, content, images, voice_file_id, tags,
               related_id, event_date, created_at, updated_at)
            VALUES (:id, :couple, :author, :requestId, :title, :content, :images, :voice, :tags,
                    :related, :eventDate, :now, :now)
            """)
        .param("id", id).param("couple", coupleId).param("author", openid)
        .param("requestId", requestId.isBlank() ? null : requestId).param("title", title)
        .param("content", content).param("images", json(images)).param("voice", voice)
        .param("tags", json(tags)).param("related", relatedId(input))
        .param("eventDate", eventDate, Types.DATE)
        .param("now", now()).update();
    if (inserted == 1) {
      notifications.notifyPartner(openid, "moment", "TA 发布了新的点滴",
          title.isBlank() ? "打开 LoveSpace 看看新记录。" : title, id, "moment:" + id);
    }
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("id", id); result.put("duplicated", inserted == 0);
    return result;
  }

  private Map<String, Object> updateMoment(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    Map<String, Object> current = owned(openid, id);
    Map<String, Object> params = new LinkedHashMap<>();
    StringBuilder set = new StringBuilder();
    if (input.has("title")) add(set, params, "title = :title", "title", slice(trimmed(input, "title"), 50));
    if (input.has("content")) add(set, params, "content = :content", "content", slice(trimmed(input, "content"), 5000));
    if (input.has("images") || input.has("imageAssetIds")) {
      add(set, params, "images = :images", "images", json(mediaListForStorage(openid, imageInput(input), 9)));
    }
    if (input.has("voiceFileId")) add(set, params, "voice_file_id = :voice", "voice", slice(text(input, "voiceFileId"), 300));
    if (input.has("tags")) add(set, params, "tags = :tags", "tags", json(stringList(input.get("tags"), 20, 10)));
    if (input.has("relatedId")) add(set, params, "related_id = :related", "related", relatedId(input));
    if (input.has("eventDate")) {
      LocalDate eventDate = eventDate(input);
      if (eventDate == null) return fail("发生日期无效");
      add(set, params, "event_date = :eventDate", "eventDate", eventDate);
    }
    if (set.isEmpty()) return fail("没有可更新的内容");

    String nextContent = params.containsKey("content") ? String.valueOf(params.get("content")) : String.valueOf(current.get("content"));
    List<String> nextImages = params.containsKey("images")
        ? readStringArray(String.valueOf(params.get("images"))) : strings(current.get("images"));
    String nextVoice = params.containsKey("voice") ? String.valueOf(params.get("voice"))
        : current.get("voiceFileId") == null ? "" : String.valueOf(current.get("voiceFileId"));
    if (nextContent.isBlank() && nextImages.isEmpty() && nextVoice.isBlank()) return fail("写点内容或添加一张照片吧");

    List<Object> safe = new ArrayList<>();
    safe.add(params.getOrDefault("title", "")); safe.add(params.getOrDefault("content", ""));
    if (params.containsKey("tags")) safe.addAll(readStringArray(String.valueOf(params.get("tags"))));
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 5000, safe.toArray());
    params.put("now", now()); params.put("id", id);
    update("UPDATE moments SET " + set + ", updated_at = :now WHERE id = :id", params);
    return ok();
  }

  private Map<String, Object> delete(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    Map<String, Object> moment = owned(openid, id);
    Set<String> unique = new LinkedHashSet<>(strings(moment.get("images")));
    jdbc.sql("DELETE FROM moments WHERE id = :id").param("id", id).update();
    for (String reference : unique) {
      if (reference.startsWith("asset://")) media.deleteIfUnreferenced(openid, reference);
    }
    return ok();
  }

  private Map<String, Object> list(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return ok("list", List.of());
    int page = Math.max(1, integer(input, "page", 1));
    int pageSize = Math.min(50, Math.max(1, integer(input, "pageSize", 20)));
    String tag = slice(text(input, "tag"), 20);
    String filter = tag.isBlank() ? "couple_id = :couple" : "couple_id = :couple AND JSON_CONTAINS(tags, JSON_QUOTE(:tag))";
    Map<String, Object> params = new LinkedHashMap<>();
    params.put("couple", coupleId);
    if (!tag.isBlank()) params.put("tag", tag);
    long total = count("SELECT COUNT(*) FROM moments WHERE " + filter, params);
    params.put("limit", pageSize); params.put("offset", (page - 1) * pageSize);
    List<Map<String, Object>> list = rows("""
        SELECT id, couple_id, author_id AS author, title, content, images, voice_file_id,
               tags, related_id, event_date, created_at, updated_at
        FROM moments WHERE %s
        ORDER BY COALESCE(event_date, DATE(created_at)) DESC, created_at DESC
        LIMIT :limit OFFSET :offset
        """.formatted(filter), params);
    list.replaceAll(item -> present(openid, item));
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("list", list); result.put("total", total);
    result.put("hasMore", (long) page * pageSize < total);
    return result;
  }

  private Map<String, Object> random(String openid) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return nullableData(null);
    List<Map<String, Object>> found = rows("""
        SELECT id, couple_id, author_id AS author, title, content, images, voice_file_id,
               tags, related_id, event_date, created_at, updated_at
        FROM moments WHERE couple_id = :couple ORDER BY RAND() LIMIT 1
        """, Map.of("couple", coupleId));
    return nullableData(found.isEmpty() ? null : present(openid, found.getFirst()));
  }

  private Map<String, Object> owned(String openid, String id) {
    if (id.isBlank()) throw error("缺少记录 ID");
    return one("""
            SELECT id, couple_id, author_id AS author, title, content, images, voice_file_id,
                   tags, related_id, event_date, created_at, updated_at
            FROM moments WHERE id = :id AND couple_id = :couple
            """, Map.of("id", id, "couple", requireCoupleId(openid)), "无权操作该记录");
  }

  private Map<String, Object> present(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    if (result.get("voiceFileId") == null) result.put("voiceFileId", "");
    if (result.get("relatedId") == null) result.put("relatedId", "");
    if (result.get("eventDate") != null) dateFields(result, "eventDate");
    displayMediaList(openid, result, "images", "imageAssetIds");
    return result;
  }

  private static LocalDate eventDate(JsonNode input) {
    String raw = text(input, "eventDate").trim();
    if (raw.length() < 10) return null;
    return date(raw.substring(0, 10));
  }

  private static String relatedId(JsonNode input) {
    String value = text(input, "relatedId").trim();
    if (!value.matches("^[A-Za-z0-9_-]{0,64}$")) throw error("关联记录 ID 无效");
    return value;
  }

  private static String requestId(JsonNode input) {
    String value = text(input, "requestId").trim();
    if (!value.isBlank() && !value.matches("^[A-Za-z0-9._:-]{8,64}$")) throw error("请求 ID 无效");
    return value;
  }

  private JsonNode imageInput(JsonNode input) {
    JsonNode raw = input.get("imageAssetIds");
    return raw != null && raw.isArray() ? raw : input.get("images");
  }

  private List<String> readStringArray(String value) {
    try {
      JsonNode node = mapper.readTree(value);
      return stringList(node, Integer.MAX_VALUE, Integer.MAX_VALUE);
    } catch (Exception exception) {
      return List.of();
    }
  }

  private long count(String sql, Map<String, ?> params) {
    var spec = jdbc.sql(sql);
    for (Map.Entry<String, ?> entry : params.entrySet()) spec = spec.param(entry.getKey(), entry.getValue());
    return spec.query(Long.class).single();
  }

  private static void add(StringBuilder set, Map<String, Object> params, String assignment, String key, Object value) {
    if (!set.isEmpty()) set.append(", ");
    set.append(assignment); params.put(key, value);
  }

  private static Map<String, Object> nullableData(Object value) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("data", value);
    return result;
  }
}
