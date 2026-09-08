package com.lovespace.server.storage;

import com.lovespace.server.api.BusinessException;
import com.lovespace.server.config.LoveSpaceProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.io.IOException;
import java.net.URI;
import java.net.URLDecoder;
import java.time.Instant;
import java.nio.charset.StandardCharsets;
import java.sql.Types;
import java.util.Map;
import java.util.UUID;

@Service
public class MediaService {
  private static final Logger log = LoggerFactory.getLogger(MediaService.class);
  private static final long MAX_SIZE = 10L * 1024 * 1024;
  private static final Map<String, String> ALLOWED = Map.of(
      "image/jpeg", "jpg",
      "image/png", "png",
      "image/webp", "webp",
      "image/gif", "gif");

  private final JdbcClient jdbc;
  private final S3Client client;
  private final S3Presigner presigner;
  private final LoveSpaceProperties properties;

  public MediaService(JdbcClient jdbc, S3Client client, S3Presigner presigner, LoveSpaceProperties properties) {
    this.jdbc = jdbc;
    this.client = client;
    this.presigner = presigner;
    this.properties = properties;
  }

  public StoredMedia upload(String openid, MultipartFile file) throws IOException {
    if (file == null || file.isEmpty()) throw new BusinessException("请选择图片");
    if (file.getSize() > MAX_SIZE) throw new BusinessException("图片不能超过 10MB");
    String type = normalizeContentType(file);
    String extension = ALLOWED.get(type);
    if (extension == null) throw new BusinessException("仅支持 JPEG、PNG、WebP 或 GIF 图片");

    String id = UUID.randomUUID().toString();
    String coupleId = jdbc.sql("SELECT couple_id FROM users WHERE id = :id")
        .param("id", openid).query(String.class).optional().orElse(null);
    String prefix = coupleId == null || coupleId.isBlank() ? "users/" + openid : "couples/" + coupleId;
    String key = prefix + "/images/" + id + "." + extension;

    client.putObject(
        PutObjectRequest.builder().bucket(properties.storage().bucket()).key(key).contentType(type).build(),
        RequestBody.fromInputStream(file.getInputStream(), file.getSize()));
    try {
      jdbc.sql("""
              INSERT INTO media_assets
                (id, owner_id, couple_id, object_key, content_type, size_bytes, status, created_at)
              VALUES (:id, :owner, :couple, :key, :type, :size, 'active', :now)
              """)
          .param("id", id).param("owner", openid).param("couple", coupleId, Types.VARCHAR)
          .param("key", key).param("type", type).param("size", file.getSize()).param("now", Instant.now())
          .update();
    } catch (RuntimeException databaseFailure) {
      try {
        client.deleteObject(DeleteObjectRequest.builder()
            .bucket(properties.storage().bucket()).key(key).build());
      } catch (RuntimeException cleanupFailure) {
        databaseFailure.addSuppressed(cleanupFailure);
        log.error("Failed to remove orphaned object {} after media row insert failed", key, cleanupFailure);
      }
      throw databaseFailure;
    }
    return new StoredMedia("asset://" + id, signedUrl(openid, "asset://" + id));
  }

  public String signedUrl(String openid, String fileId) {
    MediaRow media = requireAccessible(openid, fileId);
    var get = GetObjectRequest.builder().bucket(properties.storage().bucket()).key(media.objectKey()).build();
    var request = GetObjectPresignRequest.builder()
        .signatureDuration(properties.storage().signedUrlTtl())
        .getObjectRequest(get)
        .build();
    return presigner.presignGetObject(request).url().toString();
  }

  public String resolveForDisplay(String openid, String reference) {
    if (reference == null || reference.isBlank() || !reference.startsWith("asset://")) return reference == null ? "" : reference;
    try {
      return signedUrl(openid, reference);
    } catch (BusinessException inaccessible) {
      log.info("Media reference {} is no longer accessible to {}", reference, openid);
      return "";
    }
  }

  /**
   * Converts our own signed S3 URL back to the stable asset reference before a business row is stored.
   * External HTTPS images remain allowed for backwards compatibility.
   */
  public String normalizeForStorage(String openid, String reference) {
    if (reference == null || reference.isBlank()) return "";
    if (reference.length() > 1024) throw new BusinessException("图片地址过长");
    if (reference.startsWith("asset://")) {
      requireAccessible(openid, reference);
      return reference;
    }
    if (!reference.startsWith("https://") && !reference.startsWith("http://")) return "";
    try {
      String path = URLDecoder.decode(URI.create(reference).getPath(), StandardCharsets.UTF_8);
      String bucketPrefix = "/" + properties.storage().bucket() + "/";
      String objectKey = path.startsWith(bucketPrefix) ? path.substring(bucketPrefix.length()) : path.replaceFirst("^/", "");
      String id = jdbc.sql("""
              SELECT a.id FROM media_assets a
              LEFT JOIN users u ON u.id = :openid
              WHERE a.object_key = :key AND a.status = 'active'
                AND (a.owner_id = :openid OR (a.couple_id IS NOT NULL AND a.couple_id = u.couple_id))
              """)
          .param("openid", openid).param("key", objectKey).query(String.class).optional().orElse(null);
      return id == null ? reference : "asset://" + id;
    } catch (Exception ignored) {
      return reference;
    }
  }

  public void claimOwnedAssets(String openid, String coupleId) {
    jdbc.sql("""
            UPDATE media_assets SET couple_id = :couple
            WHERE owner_id = :owner AND couple_id IS NULL AND status = 'active'
            """)
        .param("couple", coupleId).param("owner", openid).update();
  }

  public void delete(String openid, String fileId) {
    MediaRow media = requireAccessible(openid, fileId);
    if (isReferenced(media.id())) throw new BusinessException("文件仍在使用中，不能直接删除");
    if (!remove(media)) throw new BusinessException("文件已删除");
  }

  public boolean deleteIfUnreferenced(String openid, String fileId) {
    MediaRow media;
    try {
      media = requireAccessible(openid, fileId);
    } catch (BusinessException inaccessible) {
      return false;
    }
    if (isReferenced(media.id())) return false;
    return remove(media);
  }

  private boolean remove(MediaRow media) {
    int changed = jdbc.sql("""
            UPDATE media_assets SET status = 'deleted', deleted_at = :now
            WHERE id = :id AND status = 'active'
            """)
        .param("now", Instant.now()).param("id", media.id()).update();
    if (changed == 0) return false;
    try {
      client.deleteObject(DeleteObjectRequest.builder()
          .bucket(properties.storage().bucket()).key(media.objectKey()).build());
    } catch (RuntimeException storageFailure) {
      // The private object is already inaccessible through this service. A later cleanup job can remove it.
      log.warn("Media {} was marked deleted but object {} could not be removed", media.id(), media.objectKey(), storageFailure);
    }
    return true;
  }

  private boolean isReferenced(String id) {
    String reference = "asset://" + id;
    Integer referenced = jdbc.sql("""
            SELECT CASE WHEN
              EXISTS (SELECT 1 FROM users WHERE avatar_url = :reference) OR
              EXISTS (SELECT 1 FROM anniversaries WHERE cover_url = :reference) OR
              EXISTS (SELECT 1 FROM albums WHERE cover_url = :reference) OR
              EXISTS (SELECT 1 FROM photos WHERE file_id = :reference OR thumb_file_id = :reference) OR
              EXISTS (SELECT 1 FROM moments WHERE voice_file_id = :reference OR JSON_CONTAINS(images, JSON_QUOTE(:reference))) OR
              EXISTS (SELECT 1 FROM moods WHERE JSON_CONTAINS(images, JSON_QUOTE(:reference))) OR
              EXISTS (SELECT 1 FROM dishes WHERE image_url = :reference) OR
              EXISTS (SELECT 1 FROM wishes WHERE image_url = :reference) OR
              EXISTS (SELECT 1 FROM capsules WHERE voice_file_id = :reference OR JSON_CONTAINS(images, JSON_QUOTE(:reference)))
            THEN 1 ELSE 0 END
            """)
        .param("reference", reference).query(Integer.class).single();
    return referenced != null && referenced != 0;
  }

  private MediaRow requireAccessible(String openid, String fileId) {
    String id = normalizeId(fileId);
    return jdbc.sql("""
            SELECT a.id, a.object_key
            FROM media_assets a
            LEFT JOIN users u ON u.id = :openid
            WHERE a.id = :id AND a.status = 'active'
              AND (a.owner_id = :openid OR (a.couple_id IS NOT NULL AND a.couple_id = u.couple_id))
            """)
        .param("openid", openid).param("id", id)
        .query((rs, rowNum) -> new MediaRow(rs.getString("id"), rs.getString("object_key")))
        .optional().orElseThrow(() -> new BusinessException("文件不存在或无权访问"));
  }

  private static String normalizeId(String value) {
    if (value == null) return "";
    return value.startsWith("asset://") ? value.substring("asset://".length()) : value;
  }

  private static String normalizeContentType(MultipartFile file) throws IOException {
    byte[] prefix = file.getInputStream().readNBytes(12);
    if (prefix.length >= 3 && (prefix[0] & 0xff) == 0xff && (prefix[1] & 0xff) == 0xd8 && (prefix[2] & 0xff) == 0xff) return "image/jpeg";
    if (prefix.length >= 8 && (prefix[0] & 0xff) == 0x89 && prefix[1] == 0x50 && prefix[2] == 0x4e && prefix[3] == 0x47) return "image/png";
    if (prefix.length >= 6 && new String(prefix, 0, 3).equals("GIF")) return "image/gif";
    if (prefix.length >= 12 && new String(prefix, 0, 4).equals("RIFF") && new String(prefix, 8, 4).equals("WEBP")) return "image/webp";
    return "";
  }

  public record StoredMedia(String fileId, String url) {}
  private record MediaRow(String id, String objectKey) {}
}
