package com.lovespace.server.function.fitness;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Component
public class MonthlyReportFunctionHandler extends FunctionSupport {
  private static final ZoneId CHINA = ZoneId.of("Asia/Shanghai");
  private final CoupleAccessService couples;

  public MonthlyReportFunctionHandler(
      JdbcClient jdbc,
      ObjectMapper mapper,
      CoupleAccessService couples
  ) {
    super(jdbc, mapper);
    this.couples = couples;
  }

  @Override
  public String functionName() {
    return "monthly-report";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    LocalDate nowInChina = LocalDate.now(CHINA);
    int year = event.has("year") ? event.path("year").asInt(Integer.MIN_VALUE) : nowInChina.getYear();
    int month = event.has("month") ? event.path("month").asInt(Integer.MIN_VALUE) : nowInChina.getMonthValue();
    if (year < 2000 || year > 2100 || month < 1 || month > 12 ||
        !isIntegerValue(event.get("year"), year) || !isIntegerValue(event.get("month"), month)) {
      throw new BusinessException("月份参数不正确");
    }

    var couple = couples.require(openid);
    YearMonth selected = YearMonth.of(year, month);
    Instant start = selected.atDay(1).atStartOfDay(CHINA).toInstant();
    Instant end = selected.plusMonths(1).atDay(1).atStartOfDay(CHINA).toInstant();

    List<Map<String, Object>> myMoods = rows("""
        SELECT * FROM moods
        WHERE couple_id=:couple AND user_id=:user AND created_at>=:start AND created_at<:end
        ORDER BY created_at ASC
        """, Map.of("couple", couple.coupleId(), "user", openid, "start", start, "end", end));
    List<Map<String, Object>> partnerMoods = hasPartner(couple.otherId())
        ? rows("""
            SELECT * FROM moods
            WHERE couple_id=:couple AND user_id=:user AND visibility='both'
              AND created_at>=:start AND created_at<:end
            ORDER BY created_at ASC
            """, Map.of("couple", couple.coupleId(), "user", couple.otherId(), "start", start, "end", end))
        : List.of();
    List<Map<String, Object>> points = rows("""
        SELECT * FROM points
        WHERE couple_id=:couple AND created_at>=:start AND created_at<:end
        ORDER BY created_at ASC
        """, Map.of("couple", couple.coupleId(), "start", start, "end", end));
    List<Map<String, Object>> moments = rows("""
        SELECT * FROM moments
        WHERE couple_id=:couple AND created_at>=:start AND created_at<:end
        ORDER BY created_at ASC
        """, Map.of("couple", couple.coupleId(), "start", start, "end", end));
    List<Map<String, Object>> anniversaries = rows("""
        SELECT * FROM anniversaries WHERE couple_id=:couple ORDER BY date ASC
        """, Map.of("couple", couple.coupleId()));
    List<Map<String, Object>> questions = rows("""
        SELECT * FROM daily_questions
        WHERE couple_id=:couple AND created_at>=:start AND created_at<:end
        ORDER BY created_at ASC
        """, Map.of("couple", couple.coupleId(), "start", start, "end", end));

    Map<String, Integer> moodTypes = new LinkedHashMap<>();
    List<Map<String, Object>> allMoods = new ArrayList<>(myMoods);
    allMoods.addAll(partnerMoods);
    for (Map<String, Object> mood : allMoods) {
      String type = text(mood.get("moodType"));
      if (!type.isEmpty()) moodTypes.merge(type, 1, Integer::sum);
    }
    String topMood = "";
    int topMoodCount = 0;
    for (Map.Entry<String, Integer> entry : moodTypes.entrySet()) {
      if (entry.getValue() > topMoodCount) {
        topMood = entry.getKey();
        topMoodCount = entry.getValue();
      }
    }

    Set<String> partnerMoodDays = new LinkedHashSet<>();
    partnerMoods.forEach(item -> partnerMoodDays.add(text(item.get("date"))));
    int togetherMoodDays = (int) myMoods.stream()
        .filter(item -> partnerMoodDays.contains(text(item.get("date"))))
        .count();
    long myPoints = points.stream()
        .filter(item -> openid.equals(text(item.get("toUser"))))
        .mapToLong(item -> integer(item.get("amount"))).sum();
    long partnerPoints = hasPartner(couple.otherId())
        ? points.stream().filter(item -> couple.otherId().equals(text(item.get("toUser"))))
            .mapToLong(item -> integer(item.get("amount"))).sum()
        : 0L;
    int exchangeCount = (int) points.stream().filter(item -> number(item.get("amount")) < 0).count();
    int questionTogether = (int) questions.stream()
        .filter(item -> bothAnswered(item.get("answers"), openid, couple.otherId()))
        .count();
    int photoCount = moments.stream().mapToInt(item -> listSize(item.get("images"))).sum();
    int daysInMonth = selected.lengthOfMonth();
    int connectionScore = Math.min(100, (int) Math.round(
        Math.min(1, togetherMoodDays / 8d) * 35 +
            Math.min(1, questionTogether / 12d) * 40 +
            Math.min(1, moments.size() / 6d) * 25));

    Map<String, Object> report = new LinkedHashMap<>();
    report.put("year", year);
    report.put("month", month);
    report.put("daysInMonth", daysInMonth);
    report.put("connectionScore", connectionScore);
    report.put("mood", mapOf(
        "me", myMoods.size(),
        "partner", partnerMoods.size(),
        "together", togetherMoodDays,
        "topMood", topMood,
        "checkinRate", Math.min(100, (int) Math.round(myMoods.size() / (double) daysInMonth * 100))));
    report.put("questions", mapOf("days", questions.size(), "together", questionTogether));
    report.put("points", mapOf(
        "me", myPoints,
        "partner", partnerPoints,
        "total", myPoints + partnerPoints,
        "exchanges", exchangeCount));
    report.put("moments", mapOf("count", moments.size(), "photos", photoCount));
    report.put("anniversaries", anniversaries.stream()
        .filter(item -> anniversaryInMonth(item, selected))
        .map(item -> mapOf("name", item.get("name"), "date", item.get("date")))
        .toList());

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    result.put("report", report);
    return result;
  }

  private boolean anniversaryInMonth(Map<String, Object> item, YearMonth selected) {
    LocalDate date = localDate(item.get("date"));
    if (date == null || date.getMonthValue() != selected.getMonthValue()) return false;
    return !Boolean.FALSE.equals(asBoolean(item.get("isRepeat"))) || date.getYear() == selected.getYear();
  }

  private boolean bothAnswered(Object rawAnswers, String openid, String partnerId) {
    if (!hasPartner(partnerId)) return false;
    Map<?, ?> answers;
    if (rawAnswers instanceof Map<?, ?> map) {
      answers = map;
    } else if (rawAnswers instanceof JsonNode node && node.isObject()) {
      answers = mapper.convertValue(node, Map.class);
    } else {
      return false;
    }
    return truthy(answers.get(openid)) && truthy(answers.get(partnerId));
  }

  private int listSize(Object raw) {
    if (raw instanceof List<?> list) return list.size();
    if (raw instanceof JsonNode node && node.isArray()) return node.size();
    return 0;
  }

  private static boolean isIntegerValue(JsonNode value, int parsed) {
    if (value == null || value.isMissingNode()) return true;
    if (value.isIntegralNumber()) return true;
    if (value.isFloatingPointNumber()) return Double.isFinite(value.asDouble()) && value.asDouble() == parsed;
    if (value.isTextual()) {
      try {
        double number = Double.parseDouble(value.asText().trim());
        return Double.isFinite(number) && number == parsed;
      } catch (NumberFormatException ignored) {
        return false;
      }
    }
    return false;
  }

  private static LocalDate localDate(Object value) {
    if (value instanceof LocalDate date) return date;
    if (value == null) return null;
    String text = String.valueOf(value);
    return text.length() >= 10 ? LocalDate.parse(text.substring(0, 10)) : null;
  }

  private static Boolean asBoolean(Object value) {
    if (value instanceof Boolean bool) return bool;
    if (value instanceof Number number) return number.intValue() != 0;
    if (value == null) return null;
    return Boolean.valueOf(String.valueOf(value));
  }

  private static boolean truthy(Object value) {
    if (value == null) return false;
    if (value instanceof Boolean bool) return bool;
    if (value instanceof Number number) return number.doubleValue() != 0 && !Double.isNaN(number.doubleValue());
    if (value instanceof String text) return !text.isEmpty();
    return true;
  }

  private static boolean hasPartner(String partnerId) {
    return partnerId != null && !partnerId.isBlank();
  }

  private static String text(Object value) {
    return value == null ? "" : String.valueOf(value);
  }

  private static double number(Object value) {
    if (value instanceof Number number) return number.doubleValue();
    try {
      return value == null ? 0 : Double.parseDouble(String.valueOf(value));
    } catch (NumberFormatException ignored) {
      return 0;
    }
  }

  private static int integer(Object value) {
    return (int) Math.round(number(value));
  }

  private static Map<String, Object> mapOf(Object... entries) {
    Map<String, Object> result = new LinkedHashMap<>();
    for (int index = 0; index < entries.length; index += 2) {
      result.put((String) entries[index], entries[index + 1]);
    }
    return result;
  }
}
