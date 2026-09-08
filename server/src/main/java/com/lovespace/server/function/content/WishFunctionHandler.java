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

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class WishFunctionHandler extends ContentFunctionSupport {
  private final PartnerNotificationService notifications;

  public WishFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "wish";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, input);
      case "update" -> updateWish(openid, input);
      case "delete" -> delete(openid, input);
      case "list" -> list(openid);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode input) {
    String coupleId = requireCoupleId(openid);
    String title = trimmed(input, "title");
    if (title.isEmpty() || title.length() > 80) return fail("愿望标题需要 1-80 个字");
    String description = slice(text(input, "description"), 1000);
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 1200, title, description);
    String requestId = requestId(input);
    String id = requestId.isBlank() ? newId() : hash32("wish:" + openid + ":" + requestId);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO wishes
              (id, couple_id, title, description, image_url, created_by, client_request_id,
               status, completed_at, created_at)
            VALUES (:id, :couple, :title, :description, :image, :creator, :requestId, 'todo', NULL, :now)
            """)
        .param("id", id).param("couple", coupleId).param("title", title)
        .param("description", description).param("image", mediaForStorage(openid, text(input, "imageUrl")))
        .param("creator", openid).param("requestId", requestId.isBlank() ? null : requestId)
        .param("now", now()).update();
    if (inserted == 1) {
      notifications.notifyPartner(openid, "wish", "TA 写下了一个新愿望",
          title, id, "wish:" + id);
    }
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("id", id); result.put("duplicated", inserted == 0);
    return result;
  }

  private Map<String, Object> updateWish(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    Map<String, Object> current = owned(openid, id);
    Map<String, Object> params = new LinkedHashMap<>();
    StringBuilder set = new StringBuilder();
    if (input.has("title")) {
      String title = trimmed(input, "title");
      if (title.isEmpty() || title.length() > 80) return fail("愿望标题需要 1-80 个字");
      append(set, "title = :title"); params.put("title", title);
    }
    if (input.has("description")) {
      append(set, "description = :description"); params.put("description", slice(text(input, "description"), 1000));
    }
    if (input.has("imageUrl")) {
      append(set, "image_url = :image"); params.put("image", mediaForStorage(openid, text(input, "imageUrl")));
    }
    if (input.has("status")) {
      String status = text(input, "status");
      if (!"todo".equals(status) && !"doing".equals(status) && !"done".equals(status)) {
        return fail("愿望状态无效");
      }
      append(set, "status = :status"); params.put("status", status);
      append(set, "completed_at = " + ("done".equals(status) ? ":completed" : "NULL"));
      if ("done".equals(status)) params.put("completed", Instant.now());
    }
    if (set.isEmpty()) return fail("没有可更新的内容");
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 1200,
        params.getOrDefault("title", ""), params.getOrDefault("description", ""));
    params.put("id", id);
    update("UPDATE wishes SET " + set + " WHERE id = :id", params);
    String nextStatus = input.has("status") ? text(input, "status") : "";
    if (!nextStatus.isBlank() && !nextStatus.equals(String.valueOf(current.get("status")))) {
      String title = params.containsKey("title") ? String.valueOf(params.get("title"))
          : String.valueOf(current.get("title"));
      String content = switch (nextStatus) {
        case "doing" -> "这个愿望开始行动了：" + title;
        case "done" -> "你们实现了一个愿望：" + title;
        default -> "这个愿望回到了愿望单：" + title;
      };
      notifications.notifyPartner(openid, "wish", "愿望有了新进展", content, id,
          "wish-status:" + id + ":" + nextStatus + ":" + now().toEpochMilli());
    }
    return ok();
  }

  private Map<String, Object> delete(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    owned(openid, id);
    jdbc.sql("DELETE FROM wishes WHERE id = :id").param("id", id).update();
    return ok();
  }

  private Map<String, Object> list(String openid) {
    String coupleId = requireCoupleId(openid);
    List<Map<String, Object>> list = rows("""
        SELECT * FROM wishes WHERE couple_id = :couple
        ORDER BY status ASC, created_at DESC
        """, Map.of("couple", coupleId));
    list.replaceAll(item -> present(openid, item));
    return ok("list", list);
  }

  private Map<String, Object> owned(String openid, String id) {
    if (id.isBlank()) throw error("缺少记录 ID");
    return one("SELECT * FROM wishes WHERE id = :id AND couple_id = :couple",
        Map.of("id", id, "couple", requireCoupleId(openid)), "无权操作该愿望");
  }

  private Map<String, Object> present(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    if (result.get("completedAt") == null) result.put("completedAt", "");
    displayMedia(openid, result, "imageUrl", "imageAssetId");
    return result;
  }

  private static void append(StringBuilder set, String assignment) {
    if (!set.isEmpty()) set.append(", ");
    set.append(assignment);
  }

  private static String requestId(JsonNode input) {
    String value = text(input, "requestId").trim();
    if (!value.isBlank() && !value.matches("^[A-Za-z0-9._:-]{8,64}$")) throw error("请求 ID 无效");
    return value;
  }
}
