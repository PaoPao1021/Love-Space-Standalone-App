package com.lovespace.server.function;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.jdbc.JdbcTime;
import org.springframework.jdbc.core.simple.JdbcClient;

import java.nio.charset.StandardCharsets;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

public abstract class FunctionSupport implements FunctionHandler {
  protected final JdbcClient jdbc;
  protected final ObjectMapper mapper;

  protected FunctionSupport(JdbcClient jdbc, ObjectMapper mapper) {
    this.jdbc = jdbc;
    this.mapper = mapper;
  }

  protected String action(JsonNode event) {
    return event.path("action").asText("");
  }

  protected JsonNode data(JsonNode event) {
    JsonNode data = event.path("data");
    return data.isObject() ? data : mapper.createObjectNode();
  }

  protected static String requiredText(JsonNode data, String field, String message) {
    String value = data.path(field).asText("").trim();
    if (value.isEmpty()) throw new BusinessException(message);
    return value;
  }

  protected static String newId() {
    return UUID.randomUUID().toString();
  }

  protected static Instant now() {
    return Instant.now();
  }

  protected static Map<String, Object> ok() {
    return Map.of("code", 0);
  }

  protected static Map<String, Object> ok(String key, Object value) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    result.put(key, value);
    return result;
  }

  protected Map<String, Object> row(ResultSet rs, int rowNum) throws SQLException {
    var metadata = rs.getMetaData();
    Map<String, Object> result = new LinkedHashMap<>();
    for (int i = 1; i <= metadata.getColumnCount(); i++) {
      String name = metadata.getColumnLabel(i);
      String typeName = metadata.getColumnTypeName(i);
      Object value;
      if ("DATETIME".equalsIgnoreCase(typeName) || "TIMESTAMP".equalsIgnoreCase(typeName)) {
        value = JdbcTime.instant(rs, i);
      } else if ("DATE".equalsIgnoreCase(typeName)) {
        value = JdbcTime.localDate(rs, i);
      } else {
        value = rs.getObject(i);
      }
      if ("JSON".equalsIgnoreCase(typeName)) {
        if (value instanceof String text) value = readJson(text);
        else if (value instanceof byte[] bytes) value = readJson(new String(bytes, StandardCharsets.UTF_8));
      }
      if (value instanceof Number number && isBooleanColumn(name)) value = number.intValue() != 0;
      result.put("is_read".equalsIgnoreCase(name) ? "read" : toCamel(name), value);
    }
    if (result.containsKey("id")) result.put("_id", result.remove("id"));
    return result;
  }

  protected List<Map<String, Object>> rows(String sql, Map<String, ?> params) {
    var spec = jdbc.sql(sql);
    for (var entry : params.entrySet()) spec = spec.param(entry.getKey(), entry.getValue());
    return spec.query(this::row).list();
  }

  protected Map<String, Object> one(String sql, Map<String, ?> params, String message) {
    List<Map<String, Object>> rows = rows(sql, params);
    if (rows.isEmpty()) throw new BusinessException(message);
    return rows.getFirst();
  }

  protected String json(Object value) {
    try {
      return mapper.writeValueAsString(value);
    } catch (JsonProcessingException exception) {
      throw new IllegalArgumentException("无法序列化数据", exception);
    }
  }

  private Object readJson(String value) {
    try {
      return mapper.readValue(value, new TypeReference<Object>() {});
    } catch (JsonProcessingException ignored) {
      return value;
    }
  }

  private static boolean isBooleanColumn(String name) {
    return switch (name.toLowerCase()) {
      case "is_repeat", "is_top", "is_default", "is_favorite", "is_available",
           "healthy_meal", "is_unlocked", "is_matched", "is_read" -> true;
      default -> false;
    };
  }

  private static String toCamel(String value) {
    StringBuilder result = new StringBuilder();
    boolean uppercase = false;
    for (char ch : value.toCharArray()) {
      if (ch == '_') {
        uppercase = true;
      } else if (uppercase) {
        result.append(Character.toUpperCase(ch));
        uppercase = false;
      } else {
        result.append(ch);
      }
    }
    return result.toString();
  }
}
