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

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class AlbumFunctionHandler extends ContentFunctionSupport {
  private final PartnerNotificationService notifications;
  public AlbumFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "album";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "listAlbums" -> listAlbums(openid);
      case "addAlbum" -> addAlbum(openid, input);
      case "updateAlbum" -> updateAlbum(openid, input);
      case "deleteAlbum" -> deleteAlbum(openid, input);
      case "listPhotos" -> listPhotos(openid, input);
      case "addPhotos" -> addPhotos(openid, input);
      case "deletePhoto" -> deletePhoto(openid, input);
      case "toggleFavorite" -> toggleFavorite(openid, input);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> listAlbums(String openid) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return ok("list", List.of());
    List<Map<String, Object>> list = rows("""
        SELECT * FROM albums WHERE couple_id = :couple ORDER BY created_at ASC
        """, Map.of("couple", coupleId));
    list.replaceAll(item -> presentAlbum(openid, item));
    return ok("list", list);
  }

  private Map<String, Object> addAlbum(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    if (coupleId.isBlank()) return fail("请先绑定你们的空间");
    String name = trimmed(input, "name");
    if (name.isEmpty() || name.length() > 30) return fail("相册名称需要 1-30 个字");
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 3000, name);
    String requestId = requestId(input);
    String id = requestId.isBlank() ? newId() : hash32("album:" + openid + ":" + requestId);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO albums
              (id, couple_id, client_request_id, name, cover_url, photo_count, is_default, created_at)
            VALUES (:id, :couple, :requestId, :name, '', 0, FALSE, :now)
            """)
        .param("id", id).param("couple", coupleId).param("requestId", requestId.isBlank() ? null : requestId)
        .param("name", name).param("now", now()).update();
    return Map.of("code", 0, "id", id, "duplicated", inserted == 0);
  }

  private Map<String, Object> updateAlbum(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    owned(openid, "albums", id);
    Map<String, Object> params = new LinkedHashMap<>();
    StringBuilder set = new StringBuilder();
    if (input.has("name")) {
      String name = trimmed(input, "name");
      if (name.isEmpty() || name.length() > 30) return fail("相册名称需要 1-30 个字");
      set.append("name = :name"); params.put("name", name);
    }
    if (input.has("coverUrl")) {
      if (!set.isEmpty()) set.append(", ");
      set.append("cover_url = :cover");
      params.put("cover", mediaForStorage(openid, text(input, "coverUrl")));
    }
    if (set.isEmpty()) return fail("没有可更新的内容");
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 3000,
        params.getOrDefault("name", ""));
    params.put("id", id);
    update("UPDATE albums SET " + set + " WHERE id = :id", params);
    return ok();
  }

  private Map<String, Object> deleteAlbum(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    Map<String, Object> album = owned(openid, "albums", id);
    List<Map<String, Object>> photos = rows("SELECT file_id, thumb_file_id FROM photos WHERE album_id = :album",
        Map.of("album", id));
    Set<String> assets = new LinkedHashSet<>();
    assets.add(String.valueOf(album.getOrDefault("coverUrl", "")));
    for (Map<String, Object> photo : photos) {
      assets.add(String.valueOf(photo.getOrDefault("fileId", "")));
      assets.add(String.valueOf(photo.getOrDefault("thumbFileId", "")));
    }
    transactions.executeWithoutResult(status -> {
      jdbc.sql("DELETE FROM photos WHERE album_id = :album").param("album", id).update();
      jdbc.sql("DELETE FROM albums WHERE id = :id").param("id", id).update();
    });
    for (String asset : assets) deleteAsset(openid, asset);
    return ok();
  }

  private Map<String, Object> listPhotos(String openid, JsonNode input) {
    String coupleId = optionalCoupleId(openid);
    String albumId = trimmed(input, "albumId");
    if (coupleId.isBlank()) {
      if (!albumId.isBlank()) throw error("请先绑定你们的空间");
      return pageResult(List.of(), 0, false);
    }
    if (!albumId.isBlank()) owned(openid, "albums", albumId);
    int page = Math.max(1, integer(input, "page", 1));
    int pageSize = Math.min(50, Math.max(1, integer(input, "pageSize", 20)));
    String condition = albumId.isBlank() ? "couple_id = :couple" : "couple_id = :couple AND album_id = :album";
    Map<String, Object> params = new LinkedHashMap<>();
    params.put("couple", coupleId);
    if (!albumId.isBlank()) params.put("album", albumId);
    long total = count("SELECT COUNT(*) FROM photos WHERE " + condition, params);
    params.put("limit", pageSize);
    params.put("offset", (page - 1) * pageSize);
    List<Map<String, Object>> list = rows("""
        SELECT * FROM photos WHERE %s ORDER BY created_at DESC LIMIT :limit OFFSET :offset
        """.formatted(condition), params);
    list.replaceAll(item -> presentPhoto(openid, item));
    return pageResult(list, total, (long) page * pageSize < total);
  }

  private Map<String, Object> addPhotos(String openid, JsonNode input) {
    String coupleId = requireCoupleId(openid);
    String albumId = trimmed(input, "albumId");
    String batchRequestId = requestId(input);
    owned(openid, "albums", albumId);
    JsonNode source = input.get("photos");
    if (source == null || !source.isArray() || source.isEmpty() || source.size() > 20) {
      return fail("请选择 1-20 张照片");
    }
    List<PhotoInput> photos = new ArrayList<>();
    List<Object> safeValues = new ArrayList<>();
    for (JsonNode item : source) {
      String fileId = mediaForStorage(openid, text(item, "fileId"));
      String thumbFileId = mediaForStorage(openid, text(item, "thumbFileId"));
      String description = slice(text(item, "description"), 300);
      String location = slice(text(item, "location"), 100);
      List<String> tags = stringList(item.get("tags"), 20, 10);
      if (fileId.isBlank()) return fail("照片地址无效");
      photos.add(new PhotoInput(fileId, thumbFileId, description, location, tags));
      safeValues.add(description); safeValues.add(location); safeValues.addAll(tags);
    }
    checkTextFor(openid, "内容包含不适合发布的信息，请修改后重试", 3000, safeValues.toArray());

    List<String> ids = transactions.execute(status -> {
      jdbc.sql("SELECT id FROM albums WHERE id = :id FOR UPDATE").param("id", albumId).query(String.class).single();
      List<String> inserted = new ArrayList<>();
      for (int index = 0; index < photos.size(); index++) {
        PhotoInput photo = photos.get(index);
        String itemRequestId = batchRequestId.isBlank() ? "" : batchRequestId + ":" + index;
        String id = itemRequestId.isBlank() ? newId() : hash32("photo:" + openid + ":" + itemRequestId);
        int changed = jdbc.sql("""
                INSERT IGNORE INTO photos
                  (id, couple_id, album_id, file_id, thumb_file_id, description, location,
                   tags, uploaded_by, client_request_id, is_favorite, created_at)
                VALUES (:id, :couple, :album, :file, :thumb, :description, :location,
                        :tags, :uploader, :requestId, FALSE, :now)
                """)
            .param("id", id).param("couple", coupleId).param("album", albumId)
            .param("file", photo.fileId()).param("thumb", photo.thumbFileId())
            .param("description", photo.description()).param("location", photo.location())
            .param("tags", json(photo.tags())).param("uploader", openid)
            .param("requestId", itemRequestId.isBlank() ? null : itemRequestId).param("now", now()).update();
        if (changed == 1) inserted.add(id);
      }
      long total = jdbc.sql("SELECT COUNT(*) FROM photos WHERE album_id = :album")
          .param("album", albumId).query(Long.class).single();
      String currentCover = jdbc.sql("SELECT cover_url FROM albums WHERE id = :id")
          .param("id", albumId).query(String.class).single();
      String cover = currentCover == null || currentCover.isBlank() ? photos.getFirst().fileId() : currentCover;
      jdbc.sql("UPDATE albums SET photo_count = :count, cover_url = :cover WHERE id = :id")
          .param("count", total).param("cover", cover).param("id", albumId).update();
      return inserted;
    });
    if (!ids.isEmpty()) {
      notifications.notifyPartner(openid, "photo", "TA 上传了新照片",
          "相册里新增了 " + ids.size() + " 张照片。", albumId,
          "photos:" + (batchRequestId.isBlank() ? String.join("-", ids) : batchRequestId));
    }
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0); result.put("ids", ids); result.put("duplicated", ids.isEmpty());
    return result;
  }

  private Map<String, Object> deletePhoto(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    Map<String, Object> photo = owned(openid, "photos", id);
    Set<String> assets = new LinkedHashSet<>();
    assets.add(String.valueOf(photo.getOrDefault("fileId", "")));
    assets.add(String.valueOf(photo.getOrDefault("thumbFileId", "")));
    String albumId = String.valueOf(photo.get("albumId"));
    transactions.executeWithoutResult(status -> {
      String currentCover = jdbc.sql("SELECT cover_url FROM albums WHERE id = :id FOR UPDATE")
          .param("id", albumId).query(String.class).single();
      jdbc.sql("DELETE FROM photos WHERE id = :id").param("id", id).update();
      long total = jdbc.sql("SELECT COUNT(*) FROM photos WHERE album_id = :album")
          .param("album", albumId).query(Long.class).single();
      String deletedFile = String.valueOf(photo.getOrDefault("fileId", ""));
      String cover = currentCover;
      if (currentCover.equals(deletedFile)) {
        cover = jdbc.sql("SELECT file_id FROM photos WHERE album_id = :album ORDER BY created_at DESC LIMIT 1")
            .param("album", albumId).query(String.class).optional().orElse("");
      }
      jdbc.sql("UPDATE albums SET photo_count = :count, cover_url = :cover WHERE id = :id")
          .param("count", total).param("cover", cover).param("id", albumId).update();
    });
    for (String asset : assets) deleteAsset(openid, asset);
    return ok();
  }

  private Map<String, Object> toggleFavorite(String openid, JsonNode input) {
    String id = trimmed(input, "id");
    owned(openid, "photos", id);
    Boolean favorite = transactions.execute(status -> {
      jdbc.sql("UPDATE photos SET is_favorite = NOT is_favorite WHERE id = :id").param("id", id).update();
      return jdbc.sql("SELECT is_favorite FROM photos WHERE id = :id")
          .param("id", id).query(Boolean.class).single();
    });
    return ok("isFavorite", favorite);
  }

  private Map<String, Object> owned(String openid, String table, String id) {
    if (id.isBlank()) throw error("缺少记录 ID");
    if (!"albums".equals(table) && !"photos".equals(table)) throw new IllegalArgumentException("Unsupported table");
    return one("SELECT * FROM " + table + " WHERE id = :id AND couple_id = :couple",
        Map.of("id", id, "couple", requireCoupleId(openid)), "无权操作该记录");
  }

  private Map<String, Object> presentAlbum(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    booleanFields(result, "isDefault");
    displayMedia(openid, result, "coverUrl", "coverAssetId");
    return result;
  }

  private Map<String, Object> presentPhoto(String openid, Map<String, Object> source) {
    Map<String, Object> result = mutable(source);
    booleanFields(result, "isFavorite");
    displayMedia(openid, result, "fileId", "fileAssetId");
    displayMedia(openid, result, "thumbFileId", "thumbAssetId");
    return result;
  }

  private void deleteAsset(String openid, Object value) {
    String reference = value == null ? "" : String.valueOf(value);
    if (reference.startsWith("asset://")) media.deleteIfUnreferenced(openid, reference);
  }

  private long count(String sql, Map<String, ?> params) {
    var spec = jdbc.sql(sql);
    for (Map.Entry<String, ?> entry : params.entrySet()) spec = spec.param(entry.getKey(), entry.getValue());
    return spec.query(Long.class).single();
  }

  private static String requestId(JsonNode input) {
    String value = text(input, "requestId").trim();
    if (!value.isBlank() && !value.matches("^[A-Za-z0-9._:-]{8,64}$")) throw error("请求 ID 无效");
    return value;
  }

  private static Map<String, Object> pageResult(List<Map<String, Object>> list, long total, boolean hasMore) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    result.put("list", list);
    result.put("total", total);
    result.put("hasMore", hasMore);
    return result;
  }

  private record PhotoInput(
      String fileId, String thumbFileId, String description, String location, List<String> tags
  ) {}
}
