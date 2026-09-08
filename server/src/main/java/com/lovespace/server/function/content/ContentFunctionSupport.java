package com.lovespace.server.function.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import com.lovespace.server.storage.MediaService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

abstract class ContentFunctionSupport extends FunctionSupport {
  protected static final ZoneId CHINA = ZoneId.of("Asia/Shanghai");

  protected final CoupleAccessService couples;
  protected final TextSafetyService textSafety;
  protected final MediaService media;
  protected final TransactionTemplate transactions;

  protected ContentFunctionSupport(
      JdbcClient jdbc,
      ObjectMapper mapper,
      CoupleAccessService couples,
      TextSafetyService textSafety,
      MediaService media,
      TransactionTemplate transactions
  ) {
    super(jdbc, mapper);
    this.couples = couples;
    this.textSafety = textSafety;
    this.media = media;
    this.transactions = transactions;
  }

  protected static BusinessException error(String message) {
    return new BusinessException(message);
  }

  protected static Map<String, Object> fail(String message) {
    return Map.of("code", -1, "message", message);
  }

  protected static String text(JsonNode node, String field) {
    JsonNode value = node.get(field);
    if (value == null || value.isNull()) return "";
    return value.isTextual() ? value.textValue() : value.asText("");
  }

  protected static String trimmed(JsonNode node, String field) {
    return text(node, field).trim();
  }

  protected static String slice(String value, int maximum) {
    if (value == null) return "";
    return value.length() <= maximum ? value : value.substring(0, maximum);
  }

  protected static int integer(JsonNode node, String field, int fallback) {
    JsonNode value = node.get(field);
    if (value == null || value.isNull()) return fallback;
    try {
      double number = value.isNumber() ? value.asDouble() : Double.parseDouble(value.asText());
      if (!Double.isFinite(number)) return fallback;
      return (int) Math.round(number);
    } catch (NumberFormatException ignored) {
      return fallback;
    }
  }

  protected static boolean bool(JsonNode node, String field, boolean fallback) {
    JsonNode value = node.get(field);
    if (value == null || value.isNull()) return fallback;
    if (value.isBoolean()) return value.booleanValue();
    if (value.isNumber()) return value.asInt() != 0;
    String raw = value.asText("");
    if (raw.isEmpty()) return false;
    return !"false".equalsIgnoreCase(raw) && !"0".equals(raw);
  }

  protected static LocalDate date(String value) {
    try {
      if (value == null || !value.matches("\\d{4}-\\d{2}-\\d{2}")) return null;
      LocalDate parsed = LocalDate.parse(value);
      return parsed.toString().equals(value) ? parsed : null;
    } catch (RuntimeException ignored) {
      return null;
    }
  }

  protected static LocalDate today() {
    return LocalDate.now(CHINA);
  }

  protected String optionalCoupleId(String openid) {
    String stored = jdbc.sql("SELECT couple_id FROM users WHERE id = :id")
        .param("id", openid)
        .query(String.class)
        .optional()
        .orElse(null);
    if (stored == null || stored.isBlank()) return "";
    return couples.require(openid).coupleId();
  }

  protected String requireCoupleId(String openid) {
    return couples.require(openid).coupleId();
  }

  protected void checkTextFor(String openid, String riskMessage, int maximum, Object... values) {
    try {
      textSafety.check(openid, maximum, values);
    } catch (BusinessException exception) {
      if (exception.getMessage() != null && exception.getMessage().startsWith("内容包含不适合")) {
        throw error(riskMessage);
      }
      throw exception;
    }
  }

  protected String mediaForStorage(String openid, String value) {
    String reference = value == null ? "" : value;
    if (reference.isBlank()) return "";
    if (reference.length() > 1024) throw error("图片地址过长");
    if (reference.startsWith("cloud://")) return reference;
    if (!reference.startsWith("asset://") && !reference.startsWith("https://")) return "";
    return media.normalizeForStorage(openid, reference);
  }

  protected List<String> mediaListForStorage(String openid, JsonNode value, int maximum) {
    if (value == null || !value.isArray()) return List.of();
    List<String> result = new ArrayList<>();
    for (JsonNode item : value) {
      String normalized = mediaForStorage(openid, item.asText(""));
      if (!normalized.isBlank()) result.add(normalized);
      if (result.size() == maximum) break;
    }
    return result;
  }

  protected List<String> stringList(JsonNode value, int itemMaximum, int maximum) {
    if (value == null || !value.isArray()) return List.of();
    List<String> result = new ArrayList<>();
    for (JsonNode item : value) {
      String normalized = slice(item.asText("").trim(), itemMaximum);
      if (!normalized.isBlank()) result.add(normalized);
      if (result.size() == maximum) break;
    }
    return result;
  }

  @SuppressWarnings("unchecked")
  protected List<String> strings(Object value) {
    if (!(value instanceof List<?> list)) return List.of();
    List<String> result = new ArrayList<>();
    for (Object item : list) result.add(item == null ? "" : String.valueOf(item));
    return result;
  }

  protected void displayMedia(String openid, Map<String, Object> record, String field, String rawField) {
    Object value = record.get(field);
    String raw = value == null ? "" : String.valueOf(value);
    record.put(rawField, raw);
    record.put(field, raw.isBlank() ? "" : media.resolveForDisplay(openid, raw));
  }

  protected void displayMediaList(String openid, Map<String, Object> record, String field, String rawField) {
    List<String> raw = strings(record.get(field));
    record.put(rawField, raw);
    record.put(field, raw.stream().map(item -> media.resolveForDisplay(openid, item))
        .filter(item -> !item.isBlank()).toList());
  }

  protected static void booleanFields(Map<String, Object> record, String... names) {
    for (String name : names) {
      Object value = record.get(name);
      if (value instanceof Boolean) continue;
      if (value instanceof Number number) record.put(name, number.intValue() != 0);
      else if (value != null) record.put(name, Boolean.parseBoolean(String.valueOf(value)));
    }
  }

  protected static void dateFields(Map<String, Object> record, String... names) {
    for (String name : names) {
      Object value = record.get(name);
      if (value != null) record.put(name, String.valueOf(value));
    }
  }

  protected int update(String sql, Map<String, ?> params) {
    var spec = jdbc.sql(sql);
    for (Map.Entry<String, ?> entry : params.entrySet()) spec = spec.param(entry.getKey(), entry.getValue());
    return spec.update();
  }

  protected static Map<String, Object> mutable(Map<String, Object> source) {
    return new LinkedHashMap<>(source);
  }

  protected static String hash32(String value) {
    try {
      byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
      StringBuilder result = new StringBuilder(32);
      for (int i = 0; i < 16; i++) result.append(String.format("%02x", digest[i]));
      return result.toString();
    } catch (Exception exception) {
      throw new IllegalStateException("SHA-256 unavailable", exception);
    }
  }
}
