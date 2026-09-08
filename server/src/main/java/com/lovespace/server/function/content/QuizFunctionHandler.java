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

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class QuizFunctionHandler extends ContentFunctionSupport {
  private static final Map<String, List<String>> QUESTIONS = Map.of(
      "TA最喜欢吃什么水果？", List.of("草莓", "西瓜", "芒果", "葡萄"),
      "TA最讨厌什么行为？", List.of("迟到", "撒谎", "不回消息", "敷衍"),
      "TA最喜欢什么颜色？", List.of("粉色", "蓝色", "白色", "紫色"),
      "TA的压力解压方式是？", List.of("睡觉", "吃东西", "听歌", "运动"),
      "TA的理想约会是？", List.of("看电影", "逛街", "在家待着", "旅行")
  );

  private final PartnerNotificationService notifications;

  public QuizFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "quiz";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    String coupleId = requireCoupleId(openid);
    return switch (action(event)) {
      case "list" -> list(openid, coupleId);
      case "questions" -> ok("list", QUESTIONS.entrySet().stream()
          .map(entry -> Map.of("question", entry.getKey(), "options", entry.getValue())).toList());
      case "submit" -> submit(openid, coupleId, data(event));
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> list(String openid, String coupleId) {
    List<Map<String, Object>> records = rows("""
        SELECT * FROM quizzes WHERE couple_id = :couple ORDER BY created_at DESC LIMIT 30
        """, Map.of("couple", coupleId));
    for (Map<String, Object> record : records) {
      normalize(record);
      boolean viewerIsFirst = openid.equals(record.get("user1Id"));
      boolean viewerIsSecond = openid.equals(record.get("user2Id"));
      boolean viewerAnswered = viewerIsFirst || viewerIsSecond;
      boolean bothAnswered = !String.valueOf(record.get("user1Answer")).isBlank()
          && !String.valueOf(record.get("user2Answer")).isBlank();
      boolean partnerAnswered = viewerIsFirst ? !String.valueOf(record.get("user2Answer")).isBlank()
          : viewerIsSecond ? !String.valueOf(record.get("user1Answer")).isBlank()
          : !String.valueOf(record.get("user1Answer")).isBlank() || !String.valueOf(record.get("user2Answer")).isBlank();
      if (!viewerAnswered && !bothAnswered) {
        record.put("user1Answer", "");
        record.put("user1Id", "");
      }
      record.put("myAnswer", viewerIsFirst ? record.get("user1Answer")
          : viewerIsSecond ? record.get("user2Answer") : "");
      record.put("partnerAnswer", viewerIsFirst ? record.get("user2Answer")
          : viewerIsSecond ? record.get("user1Answer") : "");
      record.put("partnerAnswered", partnerAnswered);
      record.put("bothAnswered", bothAnswered);
    }
    return ok("list", records);
  }

  private Map<String, Object> submit(String openid, String coupleId, JsonNode input) {
    String question = text(input, "question");
    List<String> options = QUESTIONS.get(question);
    String answer = text(input, "answer");
    if (options == null || !options.contains(answer)) return fail("题目或答案无效");
    String id = hash32("quiz:" + coupleId + ":" + question);
    transactions.executeWithoutResult(status -> {
      jdbc.sql("SELECT id FROM couples WHERE id = :id FOR UPDATE").param("id", coupleId).query(String.class).single();
      List<Map<String, Object>> existing = rows("""
          SELECT * FROM quizzes WHERE couple_id = :couple AND question = :question FOR UPDATE
          """, Map.of("couple", coupleId, "question", question));
      if (existing.isEmpty()) {
        jdbc.sql("""
                INSERT INTO quizzes
                  (id, couple_id, question, options, user1_id, user1_answer, user2_id,
                   user2_answer, is_matched, created_at, updated_at)
                VALUES (:id, :couple, :question, :options, :user1, :answer, NULL,
                        '', FALSE, :now, :now)
                """)
            .param("id", id).param("couple", coupleId)
            .param("question", question).param("options", json(options)).param("user1", openid)
            .param("answer", answer).param("now", now()).update();
        return;
      }
      Map<String, Object> quiz = existing.getFirst();
      normalize(quiz);
      String user1 = String.valueOf(quiz.get("user1Id"));
      String user2 = String.valueOf(quiz.get("user2Id"));
      String answer1 = String.valueOf(quiz.get("user1Answer"));
      String answer2 = String.valueOf(quiz.get("user2Answer"));
      if (!answer1.isBlank() && !answer2.isBlank()) throw error("这道题已经完成");
      String existingId = String.valueOf(quiz.get("_id"));
      if (user1.isBlank() || user1.equals(openid)) {
        jdbc.sql("UPDATE quizzes SET user1_id = :user, user1_answer = :answer, updated_at = :now WHERE id = :id")
            .param("user", openid).param("answer", answer).param("now", now()).param("id", existingId).update();
      } else if (user2.isBlank() || user2.equals(openid)) {
        jdbc.sql("""
                UPDATE quizzes SET user2_id = :user, user2_answer = :answer,
                    is_matched = :matched, updated_at = :now WHERE id = :id
                """)
            .param("user", openid).param("answer", answer).param("matched", answer1.equals(answer))
            .param("now", now()).param("id", existingId).update();
      } else {
        throw error("这道题已经完成");
      }
    });
    notifications.notifyPartner(openid, "quiz", "TA 完成了一道默契测试",
        "打开 LoveSpace，回答后一起看看默契结果。", id, "quiz:" + id + ":" + openid);
    return ok("id", id);
  }

  private static void normalize(Map<String, Object> record) {
    if (record.get("user1Id") == null) record.put("user1Id", "");
    if (record.get("user2Id") == null) record.put("user2Id", "");
    if (record.get("user1Answer") == null) record.put("user1Answer", "");
    if (record.get("user2Answer") == null) record.put("user2Answer", "");
    booleanFields(record, "isMatched");
  }
}
