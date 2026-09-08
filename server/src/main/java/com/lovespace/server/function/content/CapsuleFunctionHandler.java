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
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class CapsuleFunctionHandler extends ContentFunctionSupport {
  private final PartnerNotificationService notifications;

  public CapsuleFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "capsule";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, input);
      case "list" -> list(openid);
      case "get" -> get(openid, input);
      case "checkUnlock" -> checkUnlock(openid);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode input) {
    String coupleId = requireCoupleId(openid);
    String title = trimmed(input, "title");
    String content = trimmed(input, "content");
    LocalDate unlockDate = date(text(input, "unlockDate"));
    if (title.isEmpty() || title.length() > 50) return fail("标题需要 1-50 个字");
    if (content.isEmpty() || content.length() > 5000) return fail("内容需要 1-5000 个字");
    if (unlockDate == null || !unlockDate.isAfter(today())) return fail("开启日期需要晚于今天");
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 5000, title, content);
    List<String> images = mediaListForStorage(openid, imageInput(input), 9);
    String requestId = requestId(input);
    String id = requestId.isBlank() ? newId() : hash32("capsule:" + openid + ":" + requestId);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO capsules
              (id, couple_id, author_id, client_request_id, title, content, images, voice_file_id,
               unlock_date, is_unlocked, created_at)
            VALUES (:id, :couple, :author, :requestId, :title, :content, :images, :voice,
                    :unlockDate, FALSE, :now)
            """)
        .param("id", id).param("couple", coupleId).param("author", openid).param("title", title)
        .param("requestId", requestId.isBlank() ? null : requestId)
        .param("content", content).param("images", json(images))
        .param("voice", slice(text(input, "voiceFileId"), 300)).param("unlockDate", unlockDate)
        .param("now", now()).update();
    if (inserted == 1) {
      notifications.notifyPartner(openid, "capsule", "TA 封存了一封时光胶囊",
          title + " · " + unlockDate + " 开启", id, "capsule:" + id);
    }
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("id", id); result.put("duplicated", inserted == 0);
    return result;
  }

  private Map<String, Object> list(String openid) {
    String coupleId = requireCoupleId(openid);
    jdbc.sql("""
            UPDATE capsules SET is_unlocked = TRUE
            WHERE couple_id = :couple AND is_unlocked = FALSE AND unlock_date <= :today
            """)
        .param("couple", coupleId).param("today", today()).update();
    List<Map<String, Object>> unlocked = rows("""
        SELECT id, couple_id, author_id AS author, title, content, images, voice_file_id,
               unlock_date, is_unlocked, created_at
        FROM capsules WHERE couple_id = :couple AND is_unlocked = TRUE
        ORDER BY unlock_date DESC
        """, Map.of("couple", coupleId));
    unlocked.replaceAll(item -> present(openid, item));
    List<Map<String, Object>> lockedRows = rows("""
        SELECT id, title, unlock_date, author_id AS author, created_at
        FROM capsules WHERE couple_id = :couple AND is_unlocked = FALSE
        ORDER BY unlock_date ASC
        """, Map.of("couple", coupleId));
    lockedRows.forEach(item -> dateFields(item, "unlockDate"));
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("unlocked", unlocked); result.put("locked", lockedRows);
    return result;
  }

  private Map<String, Object> get(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    Map<String, Object> capsule = owned(openid, id);
    boolean unlocked = truth(capsule.get("isUnlocked"));
    LocalDate unlockDate = localDate(capsule.get("unlockDate"));
    if (!unlocked && today().isBefore(unlockDate)) {
      Map<String, Object> hidden = new LinkedHashMap<>();
      hidden.put("_id", capsule.get("_id")); hidden.put("title", capsule.get("title"));
      hidden.put("unlockDate", String.valueOf(capsule.get("unlockDate"))); hidden.put("isUnlocked", false);
      return Map.of("code", 0, "data", hidden);
    }
    if (!unlocked) {
      jdbc.sql("UPDATE capsules SET is_unlocked = TRUE WHERE id = :id AND is_unlocked = FALSE")
          .param("id", id).update();
      capsule.put("isUnlocked", true);
    }
    return Map.of("code", 0, "data", present(openid, capsule));
  }

  private Map<String, Object> checkUnlock(String openid) {
    String coupleId = requireCoupleId(openid);
    List<Map<String, Object>> unlocked = transactions.execute(status -> {
      List<Map<String, Object>> due = rows("""
          SELECT id, couple_id, author_id AS author, title, content, images, voice_file_id,
                 unlock_date, is_unlocked, created_at
          FROM capsules
          WHERE couple_id = :couple AND is_unlocked = FALSE AND unlock_date <= :today
          FOR UPDATE
          """, Map.of("couple", coupleId, "today", today()));
      if (!due.isEmpty()) {
        jdbc.sql("""
                UPDATE capsules SET is_unlocked = TRUE
                WHERE couple_id = :couple AND is_unlocked = FALSE AND unlock_date <= :today
                """)
            .param("couple", coupleId).param("today", today()).update();
      }
      return due;
    });
    List<Map<String, Object>> presented = new ArrayList<>();
    for (Map<String, Object> item : unlocked) presented.add(present(openid, item));
    return ok("unlocked", presented);
  }

  private Map<String, Object> owned(String openid, String id) {
    if (id.isBlank()) throw error("缺少记录 ID");
    return one("""
            SELECT id, couple_id, author_id AS author, title, content, images, voice_file_id,
                   unlock_date, is_unlocked, created_at
            FROM capsules WHERE id = :id AND couple_id = :couple
            """, Map.of("id", id, "couple", requireCoupleId(openid)), "无权查看该胶囊");
  }

  private Map<String, Object> present(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    booleanFields(result, "isUnlocked");
    dateFields(result, "unlockDate");
    if (result.get("voiceFileId") == null) result.put("voiceFileId", "");
    displayMediaList(openid, result, "images", "imageAssetIds");
    return result;
  }

  private JsonNode imageInput(JsonNode input) {
    JsonNode raw = input.get("imageAssetIds");
    return raw != null && raw.isArray() ? raw : input.get("images");
  }

  private static boolean truth(Object value) {
    if (value instanceof Boolean bool) return bool;
    if (value instanceof Number number) return number.intValue() != 0;
    return Boolean.parseBoolean(String.valueOf(value));
  }

  private static LocalDate localDate(Object value) {
    if (value instanceof LocalDate local) return local;
    return LocalDate.parse(String.valueOf(value));
  }

  private static String requestId(JsonNode input) {
    String value = text(input, "requestId").trim();
    if (!value.isBlank() && !value.matches("^[A-Za-z0-9._:-]{8,64}$")) throw error("请求 ID 无效");
    return value;
  }
}
