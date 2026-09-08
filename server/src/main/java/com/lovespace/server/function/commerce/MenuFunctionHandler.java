package com.lovespace.server.function.commerce;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import com.lovespace.server.storage.MediaService;
import com.lovespace.server.notification.PartnerNotificationService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@Component
public class MenuFunctionHandler extends FunctionSupport {
  private final CoupleAccessService couples;
  private final TextSafetyService safety;
  private final MediaService media;
  private final TransactionTemplate transactions;
  private final PartnerNotificationService notifications;

  public MenuFunctionHandler(JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
                             TextSafetyService safety, MediaService media, TransactionTemplate transactions,
                             PartnerNotificationService notifications) {
    super(jdbc, mapper);
    this.couples = couples;
    this.safety = safety;
    this.media = media;
    this.transactions = transactions;
    this.notifications = notifications;
  }

  @Override public String functionName() { return "menu"; }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode data = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, data);
      case "update" -> update(openid, data);
      case "delete" -> delete(openid, data);
      case "list" -> list(openid, data);
      case "get" -> ok("data", render(openid, owned(openid, requiredText(data, "id", "缺少菜品ID"))));
      case "recommend" -> recommend(openid);
      case "markEaten" -> markEaten(openid, data);
      case "addOrder" -> addOrder(openid, data);
      case "listOrders" -> listOrders(openid, data);
      case "addCategory" -> addCategory(openid, data);
      case "listCategories" -> listCategories(openid);
      case "deleteCategory" -> deleteCategory(openid, data);
      default -> throw new BusinessException("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode data) {
    String coupleId = couples.require(openid).coupleId();
    Dish dish = normalize(openid, data, null);
    safety.check(openid, 5000, dish.name, dish.category, dish.note, dish.description, dish.location, dish.tags);
    String requestId = requestId(data, 64);
    String id = requestId.isBlank() ? newId() : PointsFunctionHandler.hash("dish:" + openid + ":" + requestId);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO dishes
              (id, couple_id, name, category, image_url, tags, rating, location, note, price,
               description, specs, is_available, last_eaten_at, added_by, client_request_id, created_at, updated_at)
            VALUES
              (:id, :couple, :name, :category, :image, :tags, :rating, :location, :note, :price,
               :description, :specs, :available, NULL, :user, :requestId, :now, :now)
            """)
        .param("id", id).param("couple", coupleId).param("name", dish.name).param("category", dish.category)
        .param("image", dish.imageUrl).param("tags", json(dish.tags)).param("rating", dish.rating)
        .param("location", dish.location).param("note", dish.note).param("price", dish.price)
        .param("description", dish.description).param("specs", json(dish.specs)).param("available", dish.available)
        .param("user", openid).param("requestId", requestId.isBlank() ? null : requestId)
        .param("now", Instant.now()).update();
    return mutable("id", id, "duplicated", inserted == 0);
  }

  private Map<String, Object> update(String openid, JsonNode data) {
    String id = requiredText(data, "id", "缺少菜品ID");
    Map<String, Object> existing = owned(openid, id);
    Dish dish = normalize(openid, data, existing);
    safety.check(openid, 5000, dish.name, dish.category, dish.note, dish.description, dish.location, dish.tags);
    jdbc.sql("""
            UPDATE dishes SET name=:name, category=:category, image_url=:image, tags=:tags,
              rating=:rating, location=:location, note=:note, price=:price, description=:description,
              specs=:specs, is_available=:available, updated_at=:now
            WHERE id=:id
            """)
        .param("name", dish.name).param("category", dish.category).param("image", dish.imageUrl)
        .param("tags", json(dish.tags)).param("rating", dish.rating).param("location", dish.location)
        .param("note", dish.note).param("price", dish.price).param("description", dish.description)
        .param("specs", json(dish.specs)).param("available", dish.available).param("now", Instant.now())
        .param("id", id).update();
    return ok();
  }

  private Map<String, Object> delete(String openid, JsonNode data) {
    Map<String, Object> dish = owned(openid, requiredText(data, "id", "缺少菜品ID"));
    jdbc.sql("DELETE FROM dishes WHERE id=:id").param("id", dish.get("_id")).update();
    return ok();
  }

  private Map<String, Object> list(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String coupleId = couple.coupleId();
    StringBuilder sql = new StringBuilder("SELECT * FROM dishes WHERE couple_id=:couple");
    Map<String, Object> params = new LinkedHashMap<>();
    params.put("couple", coupleId);
    if (!data.path("category").asText("").isBlank()) {
      sql.append(" AND category=:category"); params.put("category", data.path("category").asText());
    }
    if (!data.path("tag").asText("").isBlank()) {
      sql.append(" AND JSON_CONTAINS(tags, JSON_QUOTE(:tag))"); params.put("tag", data.path("tag").asText());
    }
    if (!data.path("keyword").asText("").isBlank()) {
      sql.append(" AND LOWER(name) LIKE :keyword");
      params.put("keyword", "%" + escapeLike(truncate(data.path("keyword").asText(""), 30).toLowerCase()) + "%");
    }
    sql.append(" ORDER BY rating DESC LIMIT 100");
    List<Map<String, Object>> list = rows(sql.toString(), params);
    list.replaceAll(item -> render(openid, item));
    return ok("list", list);
  }

  private Map<String, Object> recommend(String openid) {
    String coupleId = couples.require(openid).coupleId();
    List<Map<String, Object>> list = rows("""
        SELECT * FROM dishes WHERE couple_id=:couple AND rating>=4 LIMIT 20
        """, Map.of("couple", coupleId));
    Collections.shuffle(list);
    list = new ArrayList<>(list.subList(0, Math.min(3, list.size())));
    list.replaceAll(item -> render(openid, item));
    return ok("list", list);
  }

  private Map<String, Object> markEaten(String openid, JsonNode data) {
    Map<String, Object> dish = owned(openid, requiredText(data, "id", "缺少菜品ID"));
    jdbc.sql("UPDATE dishes SET last_eaten_at=:date, updated_at=:now WHERE id=:id")
        .param("date", LocalDate.now()).param("now", Instant.now()).param("id", dish.get("_id")).update();
    return ok();
  }

  @SuppressWarnings("unchecked")
  private Map<String, Object> addOrder(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String coupleId = couple.coupleId();
    JsonNode itemsNode = data.path("items");
    if (!itemsNode.isArray() || itemsNode.isEmpty() || itemsNode.size() > 30) throw new BusinessException("请选择 1-30 个菜品");
    String note = truncate(data.path("note").asText(""), 200);
    safety.check(openid, 5000, note);
    List<Map<String, Object>> safeItems = new ArrayList<>();
    BigDecimal total = BigDecimal.ZERO;
    for (JsonNode item : itemsNode) {
      String id = firstText(item, "_id", "id", "dishId");
      if (id.isBlank()) throw new BusinessException("订单中存在无效菜品");
      Map<String, Object> dish = owned(openid, id);
      int quantity = Math.min(99, Math.max(1, item.path("quantity").asInt(1)));
      BigDecimal price = decimal(dish.get("price"));
      List<Map<String, Object>> specs = dish.get("specs") instanceof List<?> list
          ? mapper.convertValue(list, new TypeReference<>() {}) : List.of();
      Map<String, String> selected = item.path("selectedSpecs").isObject()
          ? mapper.convertValue(item.path("selectedSpecs"), new TypeReference<>() {}) : Map.of();
      Map<String, String> safeSelected = new LinkedHashMap<>();
      List<String> specText = new ArrayList<>();
      BigDecimal specAdd = BigDecimal.ZERO;
      for (Map<String, Object> group : specs) {
        String groupName = String.valueOf(group.getOrDefault("name", ""));
        String chosen = selected.get(groupName);
        if (chosen == null) continue;
        List<Map<String, Object>> options = group.get("options") instanceof List<?> list
            ? mapper.convertValue(list, new TypeReference<>() {}) : List.of();
        for (Map<String, Object> option : options) {
          if (chosen.equals(String.valueOf(option.get("name")))) {
            safeSelected.put(truncate(groupName, 20), truncate(chosen, 20));
            specText.add(chosen);
            specAdd = specAdd.add(decimal(option.get("priceAdd")));
            break;
          }
        }
      }
      Map<String, Object> safe = new LinkedHashMap<>();
      safe.put("dishId", id); safe.put("name", dish.get("name")); safe.put("price", price);
      safe.put("selectedSpecs", safeSelected); safe.put("specPriceAdd", specAdd);
      safe.put("specText", String.join(" / ", specText)); safe.put("quantity", quantity);
      safeItems.add(safe);
      total = total.add(price.add(specAdd).multiply(BigDecimal.valueOf(quantity)));
    }
    String requestId = requestId(data, 80);
    String orderId = PointsFunctionHandler.hash("order:" + openid + ":" + (requestId.isEmpty() ? UUID.randomUUID() : requestId));
    BigDecimal finalTotal = total;
    Boolean duplicated = transactions.execute(status -> {
      int inserted = jdbc.sql("""
              INSERT IGNORE INTO orders
                (id, couple_id, items, total_price, note, status, ordered_by, created_at)
              VALUES (:id, :couple, :items, :total, :note, 'placed', :user, :now)
              """)
          .param("id", orderId).param("couple", coupleId).param("items", json(safeItems))
          .param("total", finalTotal).param("note", note).param("user", openid).param("now", Instant.now()).update();
      if (inserted == 1) return false;
      Map<String, Object> existing = one("SELECT ordered_by, couple_id FROM orders WHERE id=:id",
          Map.of("id", orderId), "订单请求冲突");
      if (!openid.equals(existing.get("orderedBy")) || !coupleId.equals(existing.get("coupleId"))) {
        throw new BusinessException("订单请求冲突");
      }
      return true;
    });
    if (!Boolean.TRUE.equals(duplicated)) {
      notifications.notifyPartner(openid, "menu_order", "TA 点好了今天的菜单",
          "共 " + safeItems.size() + " 道菜，合计 ¥" + total.stripTrailingZeros().toPlainString(),
          orderId, "menu-order:" + orderId);
    }
    return mutable("id", orderId, "totalPrice", total, "items", safeItems, "duplicated", Boolean.TRUE.equals(duplicated));
  }

  private Map<String, Object> listOrders(String openid, JsonNode data) {
    String coupleId = couples.require(openid).coupleId();
    int page = Math.max(1, data.path("page").asInt(1));
    int size = Math.min(50, Math.max(1, data.path("pageSize").asInt(20)));
    return ok("list", rows("""
        SELECT * FROM orders WHERE couple_id=:couple ORDER BY created_at DESC LIMIT :limit OFFSET :offset
        """, Map.of("couple", coupleId, "limit", size, "offset", (page - 1) * size)));
  }

  private Map<String, Object> addCategory(String openid, JsonNode data) {
    String coupleId = couples.require(openid).coupleId();
    String name = data.path("name").asText("").trim();
    if (name.isEmpty() || name.length() > 20) throw new BusinessException("分类名称需要 1-20 个字");
    safety.check(openid, 5000, name);
    String id = newId();
    jdbc.sql("""
            INSERT INTO menu_categories (id,couple_id,name,icon,sort_order,created_at)
            VALUES (:id,:couple,:name,:icon,:sort,:now)
            """)
        .param("id", id).param("couple", coupleId).param("name", name)
        .param("icon", truncate(data.path("icon").asText("🍽️"), 8))
        .param("sort", Math.min(10000, Math.max(-10000, data.path("sortOrder").asInt(0))))
        .param("now", Instant.now()).update();
    return ok("id", id);
  }

  private Map<String, Object> listCategories(String openid) {
    String coupleId = couples.require(openid).coupleId();
    return ok("list", rows("SELECT * FROM menu_categories WHERE couple_id=:couple ORDER BY sort_order ASC",
        Map.of("couple", coupleId)));
  }

  private Map<String, Object> deleteCategory(String openid, JsonNode data) {
    String coupleId = couples.require(openid).coupleId();
    int count = jdbc.sql("DELETE FROM menu_categories WHERE id=:id AND couple_id=:couple")
        .param("id", requiredText(data, "id", "缺少ID")).param("couple", coupleId).update();
    if (count == 0) throw new BusinessException("无权操作该记录");
    return ok();
  }

  private Map<String, Object> owned(String openid, String id) {
    String coupleId = couples.require(openid).coupleId();
    return one("SELECT * FROM dishes WHERE id=:id AND couple_id=:couple",
        Map.of("id", id, "couple", coupleId), "无权操作该记录");
  }

  private Dish normalize(String openid, JsonNode data, Map<String, Object> existing) {
    boolean update = existing != null;
    String name = value(data, "name", existing, "name", update ? "" : "").trim();
    if (name.isEmpty() || name.length() > 40) throw new BusinessException("菜品名称需要 1-40 个字");
    String category = value(data, "category", existing, "category", "主食").trim();
    if (category.isEmpty()) category = "主食";
    String image = data.has("imageUrl") ? media.normalizeForStorage(openid, data.path("imageUrl").asText(""))
        : String.valueOf(existing == null ? "" : existing.getOrDefault("imageUrl", ""));
    List<String> tags = data.has("tags") && data.path("tags").isArray()
        ? mapper.convertValue(data.path("tags"), new TypeReference<>() {})
        : existing != null && existing.get("tags") instanceof List<?> list ? mapper.convertValue(list, new TypeReference<>() {}) : List.of();
    tags = tags.stream().map(String::trim).filter(s -> !s.isEmpty()).map(s -> truncate(s, 20)).limit(10).toList();
    int rating = data.has("rating") ? data.path("rating").asInt(5) : number(existing, "rating", 5).intValue();
    rating = Math.min(5, Math.max(1, rating));
    BigDecimal price = data.has("price") ? BigDecimal.valueOf(Math.max(0, Math.min(100000, data.path("price").asDouble(0)))) : decimal(existing == null ? 0 : existing.get("price"));
    List<Map<String, Object>> specs = data.has("specs") ? normalizeSpecs(data.path("specs"))
        : existing != null && existing.get("specs") instanceof List<?> list ? mapper.convertValue(list, new TypeReference<>() {}) : List.of();
    boolean available = data.has("isAvailable") ? data.path("isAvailable").asBoolean(true)
        : existing == null || Boolean.TRUE.equals(existing.get("isAvailable"));
    return new Dish(name, truncate(category, 20), image, tags, rating,
        truncate(value(data, "location", existing, "location", ""), 100),
        truncate(value(data, "note", existing, "note", ""), 500), price,
        truncate(value(data, "description", existing, "description", ""), 1000), specs, available);
  }

  private List<Map<String, Object>> normalizeSpecs(JsonNode node) {
    if (!node.isArray()) return List.of();
    List<Map<String, Object>> result = new ArrayList<>();
    for (JsonNode group : node) {
      if (result.size() >= 10) break;
      String name = truncate(group.path("name").asText("").trim(), 20);
      if (name.isEmpty() || !group.path("options").isArray()) continue;
      List<Map<String, Object>> options = new ArrayList<>();
      for (JsonNode option : group.path("options")) {
        if (options.size() >= 20) break;
        String optionName = truncate(option.path("name").asText("").trim(), 20);
        if (!optionName.isEmpty()) options.add(Map.of("name", optionName,
            "priceAdd", Math.min(100000, Math.max(0, option.path("priceAdd").asDouble(0)))));
      }
      if (!options.isEmpty()) result.add(Map.of("name", name, "options", options));
    }
    return result;
  }

  private Map<String, Object> render(String openid, Map<String, Object> dish) {
    Map<String, Object> result = new LinkedHashMap<>(dish);
    String raw = String.valueOf(result.getOrDefault("imageUrl", ""));
    result.put("imageAssetId", raw);
    result.put("imageUrl", media.resolveForDisplay(openid, raw));
    return result;
  }

  private static String value(JsonNode data, String field, Map<String, Object> existing, String existingField, String fallback) {
    if (data.has(field)) return data.path(field).asText(fallback);
    return existing == null ? fallback : String.valueOf(existing.getOrDefault(existingField, fallback));
  }

  private static Number number(Map<String, Object> map, String key, Number fallback) {
    return map != null && map.get(key) instanceof Number value ? value : fallback;
  }

  private static BigDecimal decimal(Object value) {
    if (value == null) return BigDecimal.ZERO;
    return value instanceof BigDecimal decimal ? decimal : new BigDecimal(String.valueOf(value));
  }

  private static String firstText(JsonNode node, String... fields) {
    for (String field : fields) if (!node.path(field).asText("").isBlank()) return node.path(field).asText();
    return "";
  }

  private static String requestId(JsonNode data, int maxLength) {
    String value = data.path("requestId").asText("").trim();
    if (!value.isBlank() && (!value.matches("^[A-Za-z0-9._:-]{8,80}$") || value.length() > maxLength)) {
      throw new BusinessException("请求标识无效");
    }
    return value;
  }

  private static String truncate(String value, int max) { return value.substring(0, Math.min(max, value.length())); }
  private static String escapeLike(String value) { return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_"); }

  private static Map<String, Object> mutable(Object... values) {
    Map<String, Object> result = new LinkedHashMap<>(); result.put("code", 0);
    for (int i = 0; i < values.length; i += 2) result.put((String) values[i], values[i + 1]);
    return result;
  }

  private record Dish(String name, String category, String imageUrl, List<String> tags, int rating,
                      String location, String note, BigDecimal price, String description,
                      List<Map<String, Object>> specs, boolean available) {}
}
