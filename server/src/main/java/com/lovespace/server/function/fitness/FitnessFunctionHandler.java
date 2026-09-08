package com.lovespace.server.function.fitness;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import com.lovespace.server.function.commerce.PointsFunctionHandler;
import com.lovespace.server.notification.NotificationOutboxService;
import com.lovespace.server.notification.PartnerNotificationService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.DayOfWeek;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

@Component
public class FitnessFunctionHandler extends FunctionSupport {
  private static final ZoneId CHINA = ZoneId.of("Asia/Shanghai");
  private static final Set<String> GOAL_TYPES = Set.of("fat-loss", "muscle", "shape");
  private static final Set<String> PRIVACY_TYPES = Set.of("private", "trend", "shared");
  private static final Set<String> WORKOUT_TYPES = Set.of("strength", "run", "walk", "cycle", "swim", "yoga", "other");
  private static final int MAX_DAILY_WORKOUTS = 12;
  private static final Pattern TIME_PATTERN = Pattern.compile("^(?:[01]\\d|2[0-3]):[0-5]\\d$");
  private static final Pattern WORKOUT_ID_PATTERN = Pattern.compile("^[\\w-]{1,40}$");
  private static final Map<String, ChallengePreset> CHALLENGE_PRESETS;

  static {
    Map<String, ChallengePreset> presets = new LinkedHashMap<>();
    presets.put("workouts", new ChallengePreset("共同完成 6 次运动", "workouts", 6, "次", 10));
    presets.put("minutes", new ChallengePreset("合计运动 300 分钟", "minutes", 300, "分钟", 10));
    presets.put("steps", new ChallengePreset("共同走满 8 万步", "steps", 80_000, "步", 10));
    presets.put("checkins", new ChallengePreset("一周完成 10 次打卡", "checkins", 10, "次", 10));
    CHALLENGE_PRESETS = Collections.unmodifiableMap(presets);
  }

  private final CoupleAccessService couples;
  private final TransactionTemplate transactions;
  private final NotificationOutboxService outbox;
  private final PartnerNotificationService notifications;

  public FitnessFunctionHandler(
      JdbcClient jdbc,
      ObjectMapper mapper,
      CoupleAccessService couples,
      TransactionTemplate transactions,
      NotificationOutboxService outbox,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper);
    this.couples = couples;
    this.transactions = transactions;
    this.outbox = outbox;
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "fitness";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode data = data(event);
    return switch (action(event)) {
      case "dashboard" -> dashboard(openid);
      case "saveGoal" -> saveGoal(openid, data);
      case "checkIn" -> checkIn(openid, data);
      case "createChallenge" -> createChallenge(openid, data);
      case "weeklyReport" -> weeklyReport(openid, data);
      default -> throw new BusinessException("未知操作");
    };
  }

  private Map<String, Object> dashboard(String openid) {
    var couple = couples.require(openid);
    WeekRange range = weekRange(today(), 0);
    Map<String, Object> myGoal = getGoal(couple.coupleId(), openid);
    Map<String, Object> partnerGoal = getGoal(couple.coupleId(), couple.otherId());
    List<Map<String, Object>> checkins = getCheckins(
        couple.coupleId(), openid, couple.otherId(), range.start(), range.end());
    List<Map<String, Object>> challenges = listChallenges(couple.coupleId());

    Map<String, Object> myStats = memberStats(checkins, myGoal, openid);
    Map<String, Object> partnerStats = hasPartner(couple.otherId())
        ? memberStats(checkins, partnerGoal, couple.otherId())
        : null;
    LocalDate currentDate = today();
    Map<String, Object> todayMine = findCheckin(checkins, openid, currentDate);
    Map<String, Object> todayPartner = findCheckin(checkins, couple.otherId(), currentDate);
    int memberCount = partnerStats == null ? 1 : 2;
    int teamProgress = (int) Math.round(
        (number(myStats.get("progress")) + (partnerStats == null ? 0 : number(partnerStats.get("progress")))) / memberCount);

    Map<String, Object> result = response();
    result.put("today", currentDate);
    result.put("week", rangeMap(range));
    result.put("me", memberProfile(openid, "我"));
    result.put("partner", hasPartner(couple.otherId()) ? memberProfile(couple.otherId(), "TA") : null);
    result.put("myGoal", myGoal);
    result.put("partnerGoal", sanitizePartnerGoal(partnerGoal));
    result.put("myStats", myStats);
    result.put("partnerStats", partnerStats == null ? null : sanitizePartnerStats(partnerStats, partnerGoal));
    result.put("todayCheckin", todayMine);
    result.put("nutritionPlan", buildNutritionPlan(myGoal, todayMine));
    result.put("partnerCheckedIn", todayPartner != null);
    result.put("partnerToday", sanitizePartnerToday(todayPartner));
    result.put("partnerTodayMinutes", todayPartner == null ? 0 : integer(todayPartner.get("minutes")));
    result.put("teamProgress", teamProgress);
    result.put("challenges", challenges.stream().map(item -> formatChallenge(item, checkins)).toList());
    result.put("challengePresets", challengePresetList());
    return result;
  }

  private Map<String, Object> saveGoal(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String goalType = data.path("goalType").asText("");
    String privacy = data.path("privacy").asText("trend");
    if (!GOAL_TYPES.contains(goalType)) throw new BusinessException("请选择正确的健康目标");
    if (!PRIVACY_TYPES.contains(privacy)) throw new BusinessException("隐私设置无效");

    String biologicalSex = data.path("biologicalSex").asText("");
    if (!biologicalSex.isEmpty() && !Set.of("male", "female").contains(biologicalSex)) {
      throw new BusinessException("基础代谢计算参数无效");
    }
    Double height = asNumber(data.get("height"), 120, 230, "身高", true);
    Double ageValue = asNumber(data.get("age"), 18, 80, "年龄", true);
    Double currentWeight = asNumber(data.get("currentWeight"), 30, 300, "当前体重", true);
    int profileParts = (biologicalSex.isEmpty() ? 0 : 1) + (height == null ? 0 : 1) + (ageValue == null ? 0 : 1);
    if (profileParts > 0 && profileParts < 3) throw new BusinessException("请完整填写身高、年龄和生理性别");
    if (profileParts == 3 && currentWeight == null) throw new BusinessException("计算基础代谢需要填写当前体重");

    Double targetWeight = asNumber(data.get("targetWeight"), 30, 300, "目标体重", true);
    int age = ageValue == null ? 0 : (int) Math.round(ageValue);
    int weeklyWorkouts = (int) Math.round(requireNumber(data.get("weeklyWorkouts"), 1, 7, "每周运动次数"));
    int dailySteps = (int) Math.round(requireNumber(data.get("dailySteps"), 1000, 50_000, "每日步数"));
    String id = goalId(couple.coupleId(), openid);
    Instant updatedAt = now();

    jdbc.sql("""
            INSERT INTO fitness_goals
              (id,couple_id,user_id,goal_type,current_weight,target_weight,height,age,biological_sex,
               weekly_workouts,daily_steps,privacy,updated_at)
            VALUES
              (:id,:couple,:user,:goalType,:currentWeight,:targetWeight,:height,:age,:sex,
               :weeklyWorkouts,:dailySteps,:privacy,:updatedAt)
            ON DUPLICATE KEY UPDATE
              goal_type=VALUES(goal_type),current_weight=VALUES(current_weight),target_weight=VALUES(target_weight),
              height=VALUES(height),age=VALUES(age),biological_sex=VALUES(biological_sex),
              weekly_workouts=VALUES(weekly_workouts),daily_steps=VALUES(daily_steps),privacy=VALUES(privacy),
              updated_at=VALUES(updated_at)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("user", openid)
        .param("goalType", goalType).param("currentWeight", currentWeight).param("targetWeight", targetWeight)
        .param("height", height).param("age", ageValue == null ? null : age).param("sex", biologicalSex.isEmpty() ? null : biologicalSex)
        .param("weeklyWorkouts", weeklyWorkouts).param("dailySteps", dailySteps).param("privacy", privacy)
        .param("updatedAt", updatedAt).update();

    Map<String, Object> goal = new LinkedHashMap<>();
    goal.put("coupleId", couple.coupleId());
    goal.put("userId", openid);
    goal.put("goalType", goalType);
    goal.put("currentWeight", currentWeight);
    goal.put("targetWeight", targetWeight);
    goal.put("height", height);
    goal.put("age", ageValue == null ? null : age);
    goal.put("biologicalSex", biologicalSex);
    goal.put("weeklyWorkouts", weeklyWorkouts);
    goal.put("dailySteps", dailySteps);
    goal.put("privacy", privacy);
    goal.put("updatedAt", updatedAt);
    goal.put("configured", true);
    return response("goal", goal);
  }

  private Map<String, Object> checkIn(String openid, JsonNode data) {
    var couple = couples.require(openid);
    LocalDate date = today();
    Checkin normalized = normalizeCheckin(data);
    String storedId = jdbc.sql("""
            SELECT id FROM fitness_checkins
            WHERE couple_id=:couple AND user_id=:user AND date=:date
            """)
        .param("couple", couple.coupleId()).param("user", openid).param("date", date)
        .query(String.class).optional().orElse(null);
    boolean existed = storedId != null;
    String id = existed ? storedId : checkinId(couple.coupleId(), openid, date);
    Instant timestamp = now();

    jdbc.sql("""
            INSERT INTO fitness_checkins
              (id,couple_id,user_id,date,workouts,workout_count,workout_type,minutes,calories,
               steps,water,sleep,healthy_meal,weight,created_at,updated_at)
            VALUES
              (:id,:couple,:user,:date,:workouts,:workoutCount,:workoutType,:minutes,:calories,
               :steps,:water,:sleep,:healthyMeal,:weight,:now,:now)
            ON DUPLICATE KEY UPDATE
              workouts=VALUES(workouts),workout_count=VALUES(workout_count),workout_type=VALUES(workout_type),
              minutes=VALUES(minutes),calories=VALUES(calories),steps=VALUES(steps),water=VALUES(water),
              sleep=VALUES(sleep),healthy_meal=VALUES(healthy_meal),weight=VALUES(weight),updated_at=VALUES(updated_at)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("user", openid).param("date", date)
        .param("workouts", json(normalized.workouts())).param("workoutCount", normalized.workouts().size())
        .param("workoutType", normalized.workoutType()).param("minutes", normalized.minutes())
        .param("calories", normalized.calories()).param("steps", normalized.steps()).param("water", normalized.water())
        .param("sleep", normalized.sleep()).param("healthyMeal", normalized.healthyMeal()).param("weight", normalized.weight())
        .param("now", timestamp).update();

    Map<String, Object> saved = checkinMap(couple.coupleId(), openid, date, normalized);
    List<Map<String, Object>> completed = completeEligibleChallenges(couple, openid);
    Map<String, Object> result = response();
    result.put("id", id);
    result.put("updated", existed);
    result.put("completed", completed);
    result.put("checkin", saved);
    result.put("nutritionPlan", buildNutritionPlan(getGoal(couple.coupleId(), openid), saved));
    return result;
  }

  private Map<String, Object> createChallenge(String openid, JsonNode data) {
    var couple = couples.require(openid);
    if (!hasPartner(couple.otherId())) throw new BusinessException("等 TA 加入空间后再发起双人挑战");
    String presetId = data.path("presetId").asText("");
    ChallengePreset preset = CHALLENGE_PRESETS.get(presetId);
    if (preset == null) throw new BusinessException("挑战类型无效");
    LocalDate date = today();
    long active = jdbc.sql("""
            SELECT COUNT(*) FROM fitness_challenges
            WHERE couple_id=:couple AND preset_id=:preset AND status='active' AND end_date>=:today
            """)
        .param("couple", couple.coupleId()).param("preset", presetId).param("today", date)
        .query(Long.class).single();
    if (active > 0) throw new BusinessException("这个挑战正在进行中");

    String id = PointsFunctionHandler.hash("fitness-challenge:" + couple.coupleId() + ":" + presetId + ":" + date);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO fitness_challenges
              (id,couple_id,preset_id,title,metric,target,unit,reward_points,start_date,end_date,status,
               created_by,created_date,created_at)
            VALUES
              (:id,:couple,:preset,:title,:metric,:target,:unit,:reward,:start,:end,'active',:creator,:createdDate,:now)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("preset", presetId)
        .param("title", preset.title()).param("metric", preset.metric()).param("target", preset.target())
        .param("unit", preset.unit()).param("reward", preset.rewardPoints()).param("start", date)
        .param("end", date.plusDays(6)).param("creator", openid).param("createdDate", date)
        .param("now", now()).update();
    if (inserted == 0) throw new BusinessException("这个挑战正在进行中");
    notifications.notifyPartner(openid, "fitness", "TA 发起了双人健康挑战",
        preset.title(), id, "fitness-challenge:" + id);
    return response("id", id);
  }

  private Map<String, Object> weeklyReport(String openid, JsonNode data) {
    var couple = couples.require(openid);
    double rawOffset = jsNumber(data.get("offset"));
    if (!Double.isFinite(rawOffset)) throw new BusinessException("周报范围无效");
    long roundedOffset = Math.round(rawOffset);
    if (roundedOffset < 0 || roundedOffset > 12) throw new BusinessException("周报范围无效");
    WeekRange range = weekRange(today(), (int) roundedOffset);
    Map<String, Object> myGoal = getGoal(couple.coupleId(), openid);
    Map<String, Object> partnerGoal = getGoal(couple.coupleId(), couple.otherId());
    List<Map<String, Object>> checkins = getCheckins(
        couple.coupleId(), openid, couple.otherId(), range.start(), range.end());
    Map<String, Object> myStats = memberStats(checkins, myGoal, openid);
    Map<String, Object> partnerStats = hasPartner(couple.otherId())
        ? memberStats(checkins, partnerGoal, couple.otherId())
        : null;
    List<Map<String, Object>> stats = partnerStats == null ? List.of(myStats) : List.of(myStats, partnerStats);
    int teamScore = (int) Math.round(stats.stream().mapToDouble(item -> number(item.get("progress"))).average().orElse(0));
    int totalMinutes = stats.stream().mapToInt(item -> integer(item.get("minutes"))).sum();
    int totalCalories = stats.stream().mapToInt(item -> integer(item.get("calories"))).sum();
    int totalSteps = stats.stream().mapToInt(item -> integer(item.get("totalSteps"))).sum();
    int workouts = stats.stream().mapToInt(item -> integer(item.get("workouts"))).sum();
    int activeDays = (int) checkins.stream().map(this::dateOf).distinct().count();
    String bestHabit = "开始记录";
    if (workouts >= 4) bestHabit = "规律运动";
    if (stats.stream().mapToInt(item -> integer(item.get("stepGoalDays"))).sum() >= 8) bestHabit = "日常步行";
    if (stats.stream().mapToInt(item -> integer(item.get("healthyMealDays"))).sum() >= 8) bestHabit = "健康饮食";

    Map<String, Object> report = new LinkedHashMap<>();
    report.put("range", rangeMap(range));
    report.put("teamScore", teamScore);
    report.put("totalMinutes", totalMinutes);
    report.put("totalCalories", totalCalories);
    report.put("totalSteps", totalSteps);
    report.put("workouts", workouts);
    report.put("activeDays", activeDays);
    report.put("bestHabit", bestHabit);
    report.put("headline", teamScore >= 80
        ? "这一周，你们把坚持变成了日常"
        : teamScore >= 50 ? "节奏正在形成，继续互相接住" : "从两次约好的共同运动重新开始");
    report.put("insight", reportInsight(teamScore, totalMinutes, totalSteps));
    List<Map<String, Object>> members = new ArrayList<>();
    members.add(memberReport(openid, "我", true, myGoal, myStats));
    if (partnerStats != null) {
      members.add(memberReport(couple.otherId(), "TA", false,
          sanitizePartnerGoal(partnerGoal), sanitizePartnerStats(partnerStats, partnerGoal)));
    }
    report.put("members", members);
    return response("report", report);
  }

  private Map<String, Object> getGoal(String coupleId, String userId) {
    if (!hasPartner(userId)) return null;
    List<Map<String, Object>> found = rows("""
            SELECT * FROM fitness_goals WHERE couple_id=:couple AND user_id=:user LIMIT 1
            """, Map.of("couple", coupleId, "user", userId));
    Map<String, Object> goal = defaultGoal(userId, coupleId);
    if (found.isEmpty()) return goal;
    goal.putAll(found.getFirst());
    if (goal.get("biologicalSex") == null) goal.put("biologicalSex", "");
    goal.put("configured", true);
    return goal;
  }

  private Map<String, Object> defaultGoal(String userId, String coupleId) {
    Map<String, Object> goal = new LinkedHashMap<>();
    goal.put("coupleId", coupleId);
    goal.put("userId", userId);
    goal.put("configured", false);
    goal.put("goalType", "fat-loss");
    goal.put("currentWeight", null);
    goal.put("targetWeight", null);
    goal.put("height", null);
    goal.put("age", null);
    goal.put("biologicalSex", "");
    goal.put("weeklyWorkouts", 3);
    goal.put("dailySteps", 8000);
    goal.put("privacy", "trend");
    return goal;
  }

  private List<Map<String, Object>> getCheckins(
      String coupleId, String userId, String partnerId, LocalDate start, LocalDate end
  ) {
    if (hasPartner(partnerId)) {
      return rows("""
          SELECT * FROM fitness_checkins
          WHERE couple_id=:couple AND (user_id=:user OR user_id=:partner) AND date BETWEEN :start AND :end
          ORDER BY date ASC, user_id ASC
          """, Map.of("couple", coupleId, "user", userId, "partner", partnerId, "start", start, "end", end));
    }
    return rows("""
        SELECT * FROM fitness_checkins
        WHERE couple_id=:couple AND user_id=:user AND date BETWEEN :start AND :end
        ORDER BY date ASC
        """, Map.of("couple", coupleId, "user", userId, "start", start, "end", end));
  }

  private Map<String, Object> memberStats(
      List<Map<String, Object>> checkins, Map<String, Object> goal, String userId
  ) {
    List<Map<String, Object>> mine = checkins.stream()
        .filter(item -> userId.equals(text(item.get("userId"))))
        .toList();
    int workouts = mine.stream().mapToInt(item -> workoutsForCheckin(item).size()).sum();
    int minutes = mine.stream().mapToInt(item -> integer(item.get("minutes"))).sum();
    int calories = mine.stream().mapToInt(item -> integer(item.get("calories"))).sum();
    int totalSteps = mine.stream().mapToInt(item -> integer(item.get("steps"))).sum();
    int dailySteps = goal == null ? 8000 : integerOr(goal.get("dailySteps"), 8000);
    int stepGoalDays = (int) mine.stream().filter(item -> integer(item.get("steps")) >= dailySteps).count();
    int healthyMealDays = (int) mine.stream().filter(item -> bool(item.get("healthyMeal"))).count();
    List<Map<String, Object>> weights = mine.stream()
        .filter(item -> number(item.get("weight")) > 0)
        .sorted((left, right) -> dateOf(left).compareTo(dateOf(right)))
        .toList();
    Double latestWeight = weights.isEmpty() ? null : number(weights.getLast().get("weight"));
    Double weightChange = weights.size() < 2 ? null : roundOne(
        number(weights.getLast().get("weight")) - number(weights.getFirst().get("weight")));
    int weeklyWorkouts = goal == null ? 3 : integerOr(goal.get("weeklyWorkouts"), 3);
    double workoutScore = Math.min(1, workouts / (double) Math.max(1, weeklyWorkouts));
    double checkinScore = Math.min(1, mine.size() / 7d);
    double stepScore = Math.min(1, stepGoalDays / 7d);
    double mealScore = Math.min(1, healthyMealDays / 7d);

    Map<String, Object> stats = new LinkedHashMap<>();
    stats.put("checkinDays", mine.size());
    stats.put("workouts", workouts);
    stats.put("minutes", minutes);
    stats.put("calories", calories);
    stats.put("totalSteps", totalSteps);
    stats.put("averageSteps", mine.isEmpty() ? 0 : (int) Math.round(totalSteps / (double) mine.size()));
    stats.put("stepGoalDays", stepGoalDays);
    stats.put("healthyMealDays", healthyMealDays);
    stats.put("latestWeight", latestWeight);
    stats.put("weightChange", weightChange);
    stats.put("progress", (int) Math.round(
        (workoutScore * .45 + checkinScore * .25 + stepScore * .2 + mealScore * .1) * 100));
    return stats;
  }

  private Map<String, Object> sanitizePartnerGoal(Map<String, Object> goal) {
    if (goal == null) return null;
    Map<String, Object> sanitized = new LinkedHashMap<>(goal);
    sanitized.remove("height");
    sanitized.remove("age");
    sanitized.remove("biologicalSex");
    if (!"shared".equals(text(goal.get("privacy")))) {
      sanitized.remove("currentWeight");
      sanitized.remove("targetWeight");
    }
    return sanitized;
  }

  private Map<String, Object> sanitizePartnerToday(Map<String, Object> checkin) {
    if (checkin == null) return null;
    List<Map<String, Object>> workouts = workoutsForCheckin(checkin).stream().map(item -> {
      Map<String, Object> sanitized = new LinkedHashMap<>();
      sanitized.put("id", text(item.get("id")));
      sanitized.put("type", text(item.get("type")));
      sanitized.put("startTime", text(item.get("startTime")));
      sanitized.put("minutes", integer(item.get("minutes")));
      sanitized.put("calories", integer(item.get("calories")));
      return sanitized;
    }).toList();
    Map<String, Object> sanitized = new LinkedHashMap<>();
    sanitized.put("date", checkin.get("date"));
    sanitized.put("workouts", workouts);
    sanitized.put("workoutCount", workouts.size());
    sanitized.put("minutes", integer(checkin.get("minutes")));
    sanitized.put("calories", integer(checkin.get("calories")));
    return sanitized;
  }

  private Map<String, Object> sanitizePartnerStats(
      Map<String, Object> stats, Map<String, Object> goal
  ) {
    Map<String, Object> sanitized = new LinkedHashMap<>(stats);
    String privacy = goal == null ? "" : text(goal.get("privacy"));
    if (goal == null || "private".equals(privacy)) {
      sanitized.remove("latestWeight");
      sanitized.remove("weightChange");
    } else if ("trend".equals(privacy)) {
      sanitized.remove("latestWeight");
    }
    return sanitized;
  }

  private List<Map<String, Object>> listChallenges(String coupleId) {
    LocalDate date = today();
    return rows("""
        SELECT * FROM fitness_challenges WHERE couple_id=:couple
        ORDER BY created_date DESC, created_at DESC LIMIT 20
        """, Map.of("couple", coupleId)).stream()
        .filter(item -> "completed".equals(text(item.get("status"))) ||
            ("active".equals(text(item.get("status"))) && !dateOf(item, "endDate").isBefore(date)))
        .limit(6)
        .toList();
  }

  private Map<String, Object> formatChallenge(
      Map<String, Object> challenge, List<Map<String, Object>> checkins
  ) {
    int target = Math.max(1, integer(challenge.get("target")));
    int current = "completed".equals(text(challenge.get("status")))
        ? target
        : challengeValue(challenge, checkins);
    Map<String, Object> formatted = new LinkedHashMap<>(challenge);
    formatted.put("current", current);
    formatted.put("percent", Math.min(100, (int) Math.round(current / (double) target * 100)));
    return formatted;
  }

  private int challengeValue(Map<String, Object> challenge, List<Map<String, Object>> checkins) {
    LocalDate start = dateOf(challenge, "startDate");
    LocalDate end = dateOf(challenge, "endDate");
    List<Map<String, Object>> relevant = checkins.stream()
        .filter(item -> !dateOf(item).isBefore(start) && !dateOf(item).isAfter(end))
        .toList();
    return switch (text(challenge.get("metric"))) {
      case "minutes" -> relevant.stream().mapToInt(item -> integer(item.get("minutes"))).sum();
      case "steps" -> relevant.stream().mapToInt(item -> integer(item.get("steps"))).sum();
      case "workouts" -> relevant.stream().mapToInt(item -> workoutsForCheckin(item).size()).sum();
      default -> relevant.size();
    };
  }

  private List<Map<String, Object>> completeEligibleChallenges(
      CoupleAccessService.CoupleContext couple, String openid
  ) {
    List<Map<String, Object>> completed = new ArrayList<>();
    for (Map<String, Object> challenge : listChallenges(couple.coupleId())) {
      if (!"active".equals(text(challenge.get("status")))) continue;
      LocalDate start = dateOf(challenge, "startDate");
      LocalDate end = dateOf(challenge, "endDate");
      List<Map<String, Object>> checkins = getCheckins(
          couple.coupleId(), openid, couple.otherId(), start, end);
      if (challengeValue(challenge, checkins) < integer(challenge.get("target"))) continue;
      if (completeChallenge(couple, challenge)) {
        Map<String, Object> item = new LinkedHashMap<>();
        item.put("title", challenge.get("title"));
        item.put("points", integerOr(challenge.get("rewardPoints"), 10));
        completed.add(item);
      }
    }
    return completed;
  }

  private boolean completeChallenge(
      CoupleAccessService.CoupleContext couple, Map<String, Object> challenge
  ) {
    String challengeId = text(challenge.get("_id"));
    LinkedHashSet<String> recipients = new LinkedHashSet<>();
    recipients.add(couple.creatorId());
    if (hasPartner(couple.partnerId())) recipients.add(couple.partnerId());
    recipients.removeIf(value -> value == null || value.isBlank());
    recipients.forEach(userId -> ensureBalance(couple.coupleId(), userId));

    Boolean awarded = transactions.execute(status -> {
      String currentStatus = jdbc.sql("""
              SELECT status FROM fitness_challenges
              WHERE id=:id AND couple_id=:couple FOR UPDATE
              """)
          .param("id", challengeId).param("couple", couple.coupleId())
          .query(String.class).optional().orElse("");
      if (!"active".equals(currentStatus)) return false;
      jdbc.sql("""
              UPDATE fitness_challenges SET status='completed',completed_at=:now
              WHERE id=:id AND couple_id=:couple
              """)
          .param("now", now()).param("id", challengeId).param("couple", couple.coupleId()).update();
      int reward = integerOr(challenge.get("rewardPoints"), 10);
      String title = text(challenge.get("title"));
      for (String userId : recipients) {
        String pointId = PointsFunctionHandler.hash("fitness-reward:" + challengeId + ":" + userId);
        int inserted = jdbc.sql("""
                INSERT IGNORE INTO points
                  (id,couple_id,from_user,to_user,amount,reason,note,created_at)
                VALUES (:id,:couple,'fitness',:user,:amount,:reason,'双人健康挑战完成奖励',:now)
                """)
            .param("id", pointId).param("couple", couple.coupleId()).param("user", userId)
            .param("amount", reward).param("reason", truncate("健康挑战：" + title, 30))
            .param("now", now()).update();
        if (inserted > 0) {
          jdbc.sql("""
                  UPDATE point_balances SET score=score+:amount,updated_at=:now
                  WHERE couple_id=:couple AND user_id=:user
                  """)
              .param("amount", reward).param("now", now()).param("couple", couple.coupleId())
              .param("user", userId).update();
        }
        String notificationId = PointsFunctionHandler.hash(
            "fitness-notification:" + challengeId + ":" + userId);
        int notificationInserted = jdbc.sql("""
                INSERT IGNORE INTO notifications
                  (id,couple_id,to_user,from_user,from_name,type,title,content,related_id,is_read,created_at)
                VALUES
                  (:id,:couple,:user,'fitness','一起变好','fitness','双人健康挑战完成',:content,:related,0,:now)
                """)
            .param("id", notificationId).param("couple", couple.coupleId()).param("user", userId)
            .param("content", truncate(title + "，双方各获得 " + reward + " 积分", 500))
            .param("related", challengeId).param("now", now()).update();
        if (notificationInserted == 1) outbox.enqueue(notificationId, userId);
      }
      return true;
    });
    if (!Boolean.TRUE.equals(awarded)) return false;
    return true;
  }

  private void ensureBalance(String coupleId, String userId) {
    jdbc.sql("""
            INSERT IGNORE INTO point_balances (id,couple_id,user_id,score,updated_at)
            SELECT :id,:couple,:user,COALESCE(SUM(amount),0),:now
            FROM points WHERE couple_id=:couple AND to_user=:user
            """)
        .param("id", PointsFunctionHandler.hash("balance:" + coupleId + ":" + userId))
        .param("couple", coupleId).param("user", userId).param("now", now()).update();
  }

  private Checkin normalizeCheckin(JsonNode data) {
    List<Map<String, Object>> workouts = normalizeWorkouts(data);
    int minutes = workouts.stream().mapToInt(item -> integer(item.get("minutes"))).sum();
    int calories = workouts.stream().mapToInt(item -> integer(item.get("calories"))).sum();
    return new Checkin(
        workouts,
        workouts.isEmpty() ? "rest" : text(workouts.getFirst().get("type")),
        minutes,
        calories,
        (int) Math.round(asNumberWithDefault(data.get("steps"), 0, 0, 100_000, "今日步数")),
        (int) Math.round(asNumberWithDefault(data.get("water"), 0, 0, 20, "饮水杯数")),
        asNumberWithDefault(data.get("sleep"), 0, 0, 24, "睡眠时长"),
        jsTruthy(data.get("healthyMeal")),
        asNumber(data.get("weight"), 30, 300, "今日体重", true));
  }

  private List<Map<String, Object>> normalizeWorkouts(JsonNode data) {
    JsonNode workoutNodes = data.get("workouts");
    if (workoutNodes == null || !workoutNodes.isArray()) {
      String legacyType = jsTextOr(data.get("workoutType"), "rest");
      double rawMinutes = jsNumber(data.get("minutes"));
      if ("rest".equals(legacyType) || !Double.isFinite(rawMinutes) || rawMinutes == 0) return List.of();
      if (!WORKOUT_TYPES.contains(legacyType)) throw new BusinessException("运动类型无效");
      Map<String, Object> workout = new LinkedHashMap<>();
      workout.put("id", "legacy");
      workout.put("type", legacyType);
      workout.put("startTime", "");
      workout.put("minutes", (int) Math.round(requireNumber(data.get("minutes"), 1, 600, "运动时长")));
      workout.put("calories", (int) Math.round(asNumberWithDefault(data.get("calories"), 0, 0, 5000, "消耗热量")));
      return List.of(workout);
    }
    if (workoutNodes.size() > MAX_DAILY_WORKOUTS) {
      throw new BusinessException("每天最多添加 " + MAX_DAILY_WORKOUTS + " 条运动记录");
    }
    List<Map<String, Object>> workouts = new ArrayList<>();
    for (int index = 0; index < workoutNodes.size(); index++) {
      JsonNode item = workoutNodes.get(index);
      String type = item == null ? "" : item.path("type").asText("");
      if (!WORKOUT_TYPES.contains(type)) throw new BusinessException("第 " + (index + 1) + " 条运动类型无效");
      String startTime = item.path("startTime").asText("").trim();
      if (!TIME_PATTERN.matcher(startTime).matches()) {
        throw new BusinessException("请选择第 " + (index + 1) + " 条运动的开始时间");
      }
      String rawId = item.path("id").asText("");
      Map<String, Object> workout = new LinkedHashMap<>();
      workout.put("id", WORKOUT_ID_PATTERN.matcher(rawId).matches() ? rawId : "workout-" + (index + 1));
      workout.put("type", type);
      workout.put("startTime", startTime);
      workout.put("minutes", (int) Math.round(requireNumber(
          item.get("minutes"), 1, 600, "第 " + (index + 1) + " 条运动时长")));
      workout.put("calories", (int) Math.round(requireNumber(
          item.get("calories"), 1, 5000, "第 " + (index + 1) + " 条消耗热量")));
      workouts.add(workout);
    }
    return workouts;
  }

  private List<Map<String, Object>> workoutsForCheckin(Map<String, Object> checkin) {
    if (checkin == null) return List.of();
    Object raw = checkin.get("workouts");
    if (raw instanceof List<?> list) {
      List<Map<String, Object>> result = new ArrayList<>();
      for (Object item : list) {
        if (item instanceof Map<?, ?> map) {
          Map<String, Object> workout = new LinkedHashMap<>();
          map.forEach((key, value) -> workout.put(String.valueOf(key), value));
          result.add(workout);
        }
      }
      return result;
    }
    if (raw instanceof JsonNode node && node.isArray()) {
      List<Map<String, Object>> result = new ArrayList<>();
      node.forEach(item -> result.add(mapper.convertValue(
          item, new TypeReference<Map<String, Object>>() {})));
      return result;
    }
    String type = text(checkin.get("workoutType"));
    if (!type.isEmpty() && !"rest".equals(type) && number(checkin.get("minutes")) > 0) {
      Map<String, Object> legacy = new LinkedHashMap<>();
      legacy.put("id", "legacy");
      legacy.put("type", type);
      legacy.put("startTime", "");
      legacy.put("minutes", integer(checkin.get("minutes")));
      legacy.put("calories", integer(checkin.get("calories")));
      return List.of(legacy);
    }
    return List.of();
  }

  private Map<String, Object> buildNutritionPlan(
      Map<String, Object> goal, Map<String, Object> checkin
  ) {
    double recordedWeight = checkin == null ? 0 : number(checkin.get("weight"));
    double goalWeight = goal == null ? 0 : number(goal.get("currentWeight"));
    double weight = recordedWeight > 0 ? recordedWeight : goalWeight > 0 ? goalWeight : 0;
    if (weight == 0) {
      return mapOf("ready", false, "message", "填写当前体重后，才能生成你的饮食参考。");
    }

    List<Map<String, Object>> workouts = workoutsForCheckin(checkin);
    int workoutMinutes = workouts.stream().mapToInt(item -> integer(item.get("minutes"))).sum();
    int workoutCalories = workouts.stream().mapToInt(item -> integer(item.get("calories"))).sum();
    boolean hasStrength = workouts.stream().anyMatch(item -> "strength".equals(text(item.get("type"))));
    String intensity = workoutMinutes >= 75 || workoutCalories >= 600
        ? "高训练量"
        : workoutMinutes >= 35 || workoutCalories >= 280
            ? "中等训练量"
            : !workouts.isEmpty() ? "轻训练量" : "休息日";
    String goalType = goal != null && !text(goal.get("goalType")).isEmpty()
        ? text(goal.get("goalType")) : "shape";
    Map<String, Object> bmr = calculateBmr(goal, weight);
    int baseRate = switch (goalType) {
      case "fat-loss" -> 28;
      case "muscle" -> 33;
      default -> 30;
    };
    int fallbackCalories = clamp((int) Math.round(weight * baseRate / 10) * 10, 1400, 3200);
    int restingDailyCalories = bool(bmr.get("ready"))
        ? (int) Math.round(number(bmr.get("value")) * 1.2 / 10) * 10
        : fallbackCalories;
    int goalAdjustment = "fat-loss".equals(goalType) ? -250 : "muscle".equals(goalType) ? 200 : 0;
    int trainingRecovery = clamp((int) Math.round(workoutCalories * .7 / 10) * 10, 0, 700);
    int calorieFloor = bool(bmr.get("ready"))
        ? Math.max(1200, (int) Math.round(number(bmr.get("value")) * .95))
        : 1400;
    int calories = clamp(restingDailyCalories + goalAdjustment + trainingRecovery, calorieFloor, 3600);
    double proteinRate = "muscle".equals(goalType) ? 1.8 : "fat-loss".equals(goalType) ? 1.7 : 1.6;
    double adjustedProteinRate = clamp(
        proteinRate + (hasStrength || "高训练量".equals(intensity) ? .1 : 0), 1.4, 2);
    int protein = clamp((int) Math.round(weight * adjustedProteinRate), 50, 200);
    int fat = (int) Math.round(calories * .25 / 9);
    int carbohydrates = Math.max(100, (int) Math.round((calories - protein * 4 - fat * 9) / 4d));
    int totalMacroCalories = carbohydrates * 4 + protein * 4 + fat * 9;

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("ready", true);
    result.put("bmr", bmr);
    result.put("calories", calories);
    result.put("weight", weight);
    result.put("intensity", intensity);
    result.put("workoutMinutes", workoutMinutes);
    result.put("workoutCalories", workoutCalories);
    result.put("trainingRecovery", trainingRecovery);
    result.put("summary", workouts.isEmpty()
        ? "今天按休息日估算，训练后保存记录会自动调整。"
        : "已结合今天 " + workouts.size() + " 条训练、" + workoutMinutes + " 分钟和 " + workoutCalories + " 大卡消耗估算。");
    result.put("macros", List.of(
        macro("carbohydrates", "碳水", carbohydrates, ratio(carbohydrates * 4, totalMacroCalories), "#c99857"),
        macro("protein", "蛋白质", protein, ratio(protein * 4, totalMacroCalories), "#5f8f76"),
        macro("fat", "脂肪", fat, ratio(fat * 9, totalMacroCalories), "#9b776b")));
    result.put("foodGroups", List.of(
        food("carbohydrates", "优质碳水", "燕麦、糙米、全麦面、土豆、玉米和水果",
            "休息日".equals(intensity) ? "均匀分配到三餐" : "训练前后优先安排一部分"),
        food("protein", "优质蛋白", "鸡蛋、鱼虾、鸡胸、瘦牛肉、牛奶、豆腐", "分到 3—4 餐，比集中一餐更容易执行"),
        food("fat", "健康脂肪", "坚果、牛油果、橄榄油和深海鱼", "优先不饱和脂肪，控制油炸食品"),
        food("vegetables", "蔬果与纤维", "深色蔬菜、菌菇、豆类和低糖水果", "每天至少安排两种蔬菜和一种水果")));
    result.put("disclaimer", "仅供健康成年人作日常参考；未结合身高、年龄、体脂及疾病情况，不替代医生或注册营养师方案。");
    return result;
  }

  private Map<String, Object> calculateBmr(Map<String, Object> goal, double weight) {
    double height = goal == null ? 0 : number(goal.get("height"));
    double age = goal == null ? 0 : number(goal.get("age"));
    String biologicalSex = goal == null ? "" : text(goal.get("biologicalSex"));
    if (weight == 0 || height == 0 || age == 0 || !Set.of("male", "female").contains(biologicalSex)) {
      return mapOf("ready", false, "message", "补充身高、年龄和生理性别后可计算基础代谢。");
    }
    int sexAdjustment = "male".equals(biologicalSex) ? 5 : -161;
    return mapOf(
        "ready", true,
        "value", (int) Math.round(10 * weight + 6.25 * height - 5 * age + sexAdjustment),
        "formula", "Mifflin-St Jeor",
        "note", "表示身体静息状态下维持基本生命活动的估算能量，不等于每天建议摄入量。");
  }

  private Map<String, Object> memberProfile(String userId, String fallbackName) {
    List<Map<String, Object>> users = rows(
        "SELECT nick_name,avatar_url FROM users WHERE id=:id", Map.of("id", userId));
    Map<String, Object> profile = new LinkedHashMap<>();
    if (users.isEmpty()) {
      profile.put("name", fallbackName);
      profile.put("avatarUrl", "");
    } else {
      profile.put("name", textOr(users.getFirst().get("nickName"), fallbackName));
      profile.put("avatarUrl", text(users.getFirst().get("avatarUrl")));
    }
    return profile;
  }

  private Map<String, Object> memberReport(
      String userId, String fallbackName, boolean isMe,
      Map<String, Object> goal, Map<String, Object> stats
  ) {
    Map<String, Object> profile = memberProfile(userId, fallbackName);
    Map<String, Object> member = new LinkedHashMap<>();
    member.put("name", profile.get("name"));
    member.put("isMe", isMe);
    member.put("goal", goal);
    member.put("stats", stats);
    return member;
  }

  private Map<String, Object> findCheckin(
      List<Map<String, Object>> checkins, String userId, LocalDate date
  ) {
    if (!hasPartner(userId)) return null;
    return checkins.stream()
        .filter(item -> userId.equals(text(item.get("userId"))) && date.equals(dateOf(item)))
        .findFirst().orElse(null);
  }

  private Map<String, Object> checkinMap(
      String coupleId, String userId, LocalDate date, Checkin checkin
  ) {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("coupleId", coupleId);
    result.put("userId", userId);
    result.put("date", date);
    result.put("workouts", checkin.workouts());
    result.put("workoutCount", checkin.workouts().size());
    result.put("workoutType", checkin.workoutType());
    result.put("minutes", checkin.minutes());
    result.put("calories", checkin.calories());
    result.put("steps", checkin.steps());
    result.put("water", checkin.water());
    result.put("sleep", checkin.sleep());
    result.put("healthyMeal", checkin.healthyMeal());
    result.put("weight", checkin.weight());
    return result;
  }

  private List<Map<String, Object>> challengePresetList() {
    List<Map<String, Object>> result = new ArrayList<>();
    CHALLENGE_PRESETS.forEach((id, preset) -> {
      Map<String, Object> item = new LinkedHashMap<>();
      item.put("id", id);
      item.put("title", preset.title());
      item.put("metric", preset.metric());
      item.put("target", preset.target());
      item.put("unit", preset.unit());
      item.put("rewardPoints", preset.rewardPoints());
      result.add(item);
    });
    return result;
  }

  private String reportInsight(int teamScore, int totalMinutes, int totalSteps) {
    if (teamScore >= 85) return "这周的节奏很稳定，保持恢复和睡眠，不需要继续加码。";
    if (totalMinutes >= 240) return "运动量已经不错，下周更值得关注步数、饮食和睡眠。";
    if (totalSteps >= 70_000) return "日常活动保持得很好，可以安排两次有计划的力量训练。";
    return "先约定两次一起运动的时间，比临时提醒更容易坚持。";
  }

  private static LocalDate today() {
    return LocalDate.now(CHINA);
  }

  private static WeekRange weekRange(LocalDate date, int offset) {
    LocalDate monday = date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)).minusWeeks(offset);
    return new WeekRange(monday, monday.plusDays(6));
  }

  private static Map<String, Object> rangeMap(WeekRange range) {
    return mapOf("start", range.start(), "end", range.end());
  }

  private static String goalId(String coupleId, String userId) {
    return PointsFunctionHandler.hash("fitness-goal:" + coupleId + ":" + userId);
  }

  private static String checkinId(String coupleId, String userId, LocalDate date) {
    return PointsFunctionHandler.hash("fitness-checkin:" + coupleId + ":" + userId + ":" + date);
  }

  private static boolean hasPartner(String userId) {
    return userId != null && !userId.isBlank();
  }

  private LocalDate dateOf(Map<String, Object> item) {
    return dateOf(item, "date");
  }

  private LocalDate dateOf(Map<String, Object> item, String key) {
    Object value = item.get(key);
    if (value instanceof LocalDate date) return date;
    return LocalDate.parse(String.valueOf(value));
  }

  private static double requireNumber(JsonNode value, double min, double max, String label) {
    Double parsed = asNumber(value, min, max, label, false);
    return parsed == null ? 0 : parsed;
  }

  private static double asNumberWithDefault(
      JsonNode value, double defaultValue, double min, double max, String label
  ) {
    if (!jsTruthy(value)) return requireNumber(nullNode(defaultValue), min, max, label);
    return requireNumber(value, min, max, label);
  }

  private static JsonNode nullNode(double value) {
    return com.fasterxml.jackson.databind.node.DoubleNode.valueOf(value);
  }

  private static Double asNumber(JsonNode value, double min, double max, String label, boolean optional) {
    if ((value == null || value.isMissingNode() || value.isNull() || (value.isTextual() && value.asText().isEmpty())) && optional) {
      return null;
    }
    double parsed = jsNumber(value);
    if (!Double.isFinite(parsed) || parsed < min || parsed > max) {
      throw new BusinessException(label + "需要在 " + formatLimit(min) + "-" + formatLimit(max) + " 之间");
    }
    return roundOne(parsed);
  }

  private static String formatLimit(double value) {
    return value == Math.rint(value) ? String.valueOf((long) value) : String.valueOf(value);
  }

  private static double jsNumber(JsonNode value) {
    if (value == null || value.isMissingNode() || value.isNull()) return 0;
    if (value.isNumber()) return value.asDouble();
    if (value.isBoolean()) return value.asBoolean() ? 1 : 0;
    if (value.isTextual()) {
      String text = value.asText().trim();
      if (text.isEmpty()) return 0;
      try {
        return Double.parseDouble(text);
      } catch (NumberFormatException ignored) {
        return Double.NaN;
      }
    }
    return Double.NaN;
  }

  private static boolean jsTruthy(JsonNode value) {
    if (value == null || value.isMissingNode() || value.isNull()) return false;
    if (value.isBoolean()) return value.asBoolean();
    if (value.isNumber()) return value.asDouble() != 0 && !Double.isNaN(value.asDouble());
    if (value.isTextual()) return !value.asText().isEmpty();
    return true;
  }

  private static String jsTextOr(JsonNode value, String fallback) {
    return jsTruthy(value) ? value.asText() : fallback;
  }

  private static double number(Object value) {
    if (value == null) return 0;
    if (value instanceof Number number) return number.doubleValue();
    if (value instanceof Boolean bool) return bool ? 1 : 0;
    try {
      return Double.parseDouble(String.valueOf(value));
    } catch (NumberFormatException ignored) {
      return 0;
    }
  }

  private static int integer(Object value) {
    return (int) Math.round(number(value));
  }

  private static int integerOr(Object value, int fallback) {
    return value == null ? fallback : integer(value);
  }

  private static boolean bool(Object value) {
    if (value instanceof Boolean bool) return bool;
    if (value instanceof Number number) return number.doubleValue() != 0;
    return value != null && !String.valueOf(value).isEmpty() && !"false".equalsIgnoreCase(String.valueOf(value));
  }

  private static String text(Object value) {
    return value == null ? "" : String.valueOf(value);
  }

  private static String textOr(Object value, String fallback) {
    String result = text(value);
    return result.isEmpty() ? fallback : result;
  }

  private static double roundOne(double value) {
    return Math.round(value * 10) / 10d;
  }

  private static int clamp(int value, int min, int max) {
    return Math.min(max, Math.max(min, value));
  }

  private static double clamp(double value, double min, double max) {
    return Math.min(max, Math.max(min, value));
  }

  private static int ratio(int value, int total) {
    return (int) Math.round(value / (double) total * 100);
  }

  private static String truncate(String value, int max) {
    String safe = value == null ? "" : value;
    return safe.substring(0, Math.min(safe.length(), max));
  }

  private static Map<String, Object> macro(String key, String name, int grams, int ratio, String color) {
    return mapOf("key", key, "name", name, "grams", grams, "ratio", ratio, "color", color);
  }

  private static Map<String, Object> food(String key, String name, String foods, String note) {
    return mapOf("key", key, "name", name, "foods", foods, "note", note);
  }

  private static Map<String, Object> response() {
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    return result;
  }

  private static Map<String, Object> response(String key, Object value) {
    Map<String, Object> result = response();
    result.put(key, value);
    return result;
  }

  private static Map<String, Object> mapOf(Object... entries) {
    Map<String, Object> result = new LinkedHashMap<>();
    for (int index = 0; index < entries.length; index += 2) {
      result.put((String) entries[index], entries[index + 1]);
    }
    return result;
  }

  private record ChallengePreset(String title, String metric, int target, String unit, int rewardPoints) {}
  private record WeekRange(LocalDate start, LocalDate end) {}
  private record Checkin(
      List<Map<String, Object>> workouts,
      String workoutType,
      int minutes,
      int calories,
      int steps,
      int water,
      double sleep,
      boolean healthyMeal,
      Double weight
  ) {}
}
