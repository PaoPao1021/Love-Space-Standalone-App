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
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class DailyQuestionFunctionHandler extends ContentFunctionSupport {
  private final PartnerNotificationService notifications;
  private static final List<Question> QUESTIONS = List.of(
      new Question("如果现在可以和 TA 去任何地方，你最想去哪里？", "旅行"),
      new Question("最近 TA 做过哪件小事，让你觉得被爱着？", "心动"),
      new Question("如果只留下一张你们的合照，你会选哪一张？", "回忆"),
      new Question("今年最想和 TA 一起完成的一件事是什么？", "未来"),
      new Question("你最欣赏 TA 身上的哪一种品质？", "了解"),
      new Question("你们一起吃过最难忘的一顿饭是什么？", "美食"),
      new Question("如果可以重温你们的某一天，你会选哪一天？", "时光"),
      new Question("你觉得你们最有默契的一件事是什么？", "默契"),
      new Question("今天有什么一直想对 TA 说的话？", "表达"),
      new Question("TA 的哪个小习惯让你觉得特别可爱？", "日常"),
      new Question("第一次见面时，你对 TA 的第一印象是什么？", "回忆"),
      new Question("最近哪一刻，你最想给 TA 一个拥抱？", "关怀"),
      new Question("你现在最感谢 TA 的是什么？", "感恩"),
      new Question("你们之间有哪些专属暗号或梗？", "默契"),
      new Question("如果这个周末完全空下来，你想和 TA 做什么？", "约会"),
      new Question("TA 让你发生过哪一种好的改变？", "成长"),
      new Question("你觉得你们的相处像哪部电影或哪本书？", "趣味"),
      new Question("你偷偷为 TA 做过什么、但 TA 可能不知道？", "浪漫"),
      new Question("给今天的关系状态打几分？为什么？", "连接"),
      new Question("你最喜欢和 TA 一起做的日常小事是什么？", "日常"),
      new Question("TA 说过最让你印象深刻的一句话是什么？", "回忆"),
      new Question("你希望你们三年后的普通一天是什么样子？", "未来"),
      new Question("如果今天送 TA 一份不用花钱的礼物，会是什么？", "浪漫"),
      new Question("TA 最近可能需要你怎样的支持？", "关怀"),
      new Question("你们之间最好笑的一次经历是什么？", "快乐"),
      new Question("最近一次被 TA 打动是在什么时候？", "心动"),
      new Question("如果能给刚在一起时的你们一句话，会说什么？", "时光"),
      new Question("你最想帮 TA 实现的一个愿望是什么？", "愿望"),
      new Question("今天你想邀请 TA 一起完成哪件小事？", "行动"),
      new Question("最近有什么压力，是你希望 TA 理解的？", "倾听"),
      new Question("你觉得被 TA 爱着时，最明显的感受是什么？", "连接")
  );

  public DailyQuestionFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions,
      PartnerNotificationService notifications
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
    this.notifications = notifications;
  }

  @Override
  public String functionName() {
    return "daily-question";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    CoupleAccessService.CoupleContext context = couples.require(openid);
    LocalDate day = today();
    Question todayQuestion = QUESTIONS.get(Integer.parseInt(day.toString().replace("-", "")) % QUESTIONS.size());
    String recordId = "daily_" + context.coupleId() + "_" + day.toString().replace("-", "");
    return switch (action(event)) {
      case "getToday", "reveal" -> shape(find(recordId), openid, context.otherId(), todayQuestion);
      case "submit" -> submit(openid, data(event), context, day, todayQuestion, recordId);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> submit(
      String openid, JsonNode input, CoupleAccessService.CoupleContext context,
      LocalDate day, Question question, String recordId
  ) {
    String answer = trimmed(input, "answer");
    if (answer.isEmpty()) return fail("写下你的回答后再提交");
    if (answer.length() > 500) return fail("回答最多 500 个字");
    checkTextFor(openid, "回答包含不适合发布的信息，请修改后重试", 500, answer);
    boolean[] newlyAnswered = {false};
    transactions.executeWithoutResult(status -> {
      jdbc.sql("SELECT id FROM couples WHERE id = :id FOR UPDATE")
          .param("id", context.coupleId()).query(String.class).single();
      Map<String, Object> current = find(recordId);
      Map<String, String> answers = answers(current == null ? null : current.get("answers"));
      boolean wasMine = !answers.getOrDefault(openid, "").isBlank();
      boolean frozen = !answers.getOrDefault(openid, "").isBlank()
          && !answers.getOrDefault(context.otherId(), "").isBlank();
      if (frozen) throw error("双方答案已经揭晓，今天的回答不能再修改");
      answers.put(openid, answer);
      newlyAnswered[0] = !wasMine;
      if (current == null) {
        jdbc.sql("""
                INSERT INTO daily_questions
                  (id, couple_id, date, question, category, answers, created_at, updated_at)
                VALUES (:id, :couple, :date, :question, :category, :answers, :now, :now)
                """)
            .param("id", recordId).param("couple", context.coupleId()).param("date", day)
            .param("question", question.question()).param("category", question.category())
            .param("answers", json(answers)).param("now", now()).update();
      } else {
        jdbc.sql("UPDATE daily_questions SET answers = :answers, updated_at = :now WHERE id = :id")
            .param("answers", json(answers)).param("now", now()).param("id", recordId).update();
      }
    });
    if (newlyAnswered[0]) {
      notifications.notifyPartner(openid, "daily-question", "TA 已回答今日问题",
          "打开 LoveSpace，完成回答后一起揭晓。", recordId, "daily-question:" + recordId + ":" + openid);
    }
    return shape(find(recordId), openid, context.otherId(), question);
  }

  private Map<String, Object> find(String id) {
    List<Map<String, Object>> records = rows("SELECT * FROM daily_questions WHERE id = :id", Map.of("id", id));
    return records.isEmpty() ? null : records.getFirst();
  }

  private Map<String, Object> shape(Map<String, Object> record, String openid, String partnerId, Question fallback) {
    Map<String, String> answers = answers(record == null ? null : record.get("answers"));
    String mine = answers.getOrDefault(openid, "");
    String partner = partnerId == null || partnerId.isBlank() ? "" : answers.getOrDefault(partnerId, "");
    boolean both = !mine.isBlank() && !partner.isBlank();
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    result.put("question", record == null ? fallback.question() : record.get("question"));
    result.put("category", record == null ? fallback.category() : record.get("category"));
    result.put("myAnswer", mine.isBlank() ? null : mine);
    result.put("partnerAnswer", both ? partner : null);
    result.put("partnerAnswered", !partner.isBlank());
    result.put("bothAnswered", both);
    return result;
  }

  @SuppressWarnings("unchecked")
  private Map<String, String> answers(Object value) {
    Map<String, String> result = new LinkedHashMap<>();
    if (value instanceof Map<?, ?> map) {
      for (Map.Entry<?, ?> entry : map.entrySet()) {
        result.put(String.valueOf(entry.getKey()), entry.getValue() == null ? "" : String.valueOf(entry.getValue()));
      }
    }
    return result;
  }

  private record Question(String question, String category) {}
}
