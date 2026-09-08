package com.lovespace.server.function.commerce;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.api.BusinessException;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.function.FunctionSupport;
import com.lovespace.server.notification.NotificationOutboxService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.sql.Types;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class TaskFunctionHandler extends FunctionSupport {
  private final CoupleAccessService couples;
  private final TextSafetyService safety;
  private final NotificationOutboxService outbox;
  private final TransactionTemplate transactions;

  public TaskFunctionHandler(JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
                             TextSafetyService safety, NotificationOutboxService outbox,
                             TransactionTemplate transactions) {
    super(jdbc, mapper);
    this.couples = couples;
    this.safety = safety;
    this.outbox = outbox;
    this.transactions = transactions;
  }

  @Override public String functionName() { return "task"; }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode data = data(event);
    return switch (action(event)) {
      case "add" -> add(openid, data);
      case "complete" -> complete(openid, data);
      case "list" -> list(openid, data);
      case "detail" -> detail(openid, data);
      case "delete" -> delete(openid, data);
      default -> throw new BusinessException("未知操作");
    };
  }

  private Map<String, Object> add(String openid, JsonNode data) {
    var couple = couples.require(openid);
    String title = data.path("title").asText("").trim();
    String description = truncate(data.path("description").asText(""), 500);
    if (title.isEmpty() || title.length() > 50) throw new BusinessException("任务标题需要 1-50 个字");
    safety.check(openid, 1000, title, description);
    int reward = Math.min(100, Math.max(0, data.path("rewardPoints").asInt(0)));
    String assignee = switch (data.path("assignee").asText("both")) {
      case "me", "partner", "both" -> data.path("assignee").asText("both");
      default -> "both";
    };
    String rawDueDate = data.path("dueDate").asText("").trim();
    LocalDate dueDate = null;
    if (!rawDueDate.isBlank()) {
      try {
        dueDate = LocalDate.parse(rawDueDate);
        if (!dueDate.toString().equals(rawDueDate)) throw new IllegalArgumentException();
      } catch (RuntimeException invalidDate) {
        throw new BusinessException("截止日期格式不正确");
      }
    }
    String requestId = requestId(data);
    String id = requestId.isBlank() ? newId() : PointsFunctionHandler.hash("task:" + openid + ":" + requestId);
    int inserted = jdbc.sql("""
            INSERT IGNORE INTO tasks
              (id,couple_id,title,description,type,assignee,reward_points,created_by,client_request_id,
               status,completed_by,due_date,created_at)
            VALUES
              (:id,:couple,:title,:description,:type,:assignee,:reward,:creator,:requestId,'pending',NULL,
               :due,:now)
            """)
        .param("id", id).param("couple", couple.coupleId()).param("title", title)
        .param("description", description).param("type", truncate(data.path("type").asText("single"), 32))
        .param("assignee", assignee).param("reward", reward).param("creator", openid)
        .param("requestId", requestId.isBlank() ? null : requestId)
        .param("due", dueDate, Types.DATE).param("now", Instant.now()).update();

    if (inserted == 1 && (assignee.equals("partner") || assignee.equals("both")) && couple.otherId() != null && !couple.otherId().isBlank()) {
      String sender = couples.nickname(openid);
      String notificationId = newId();
      jdbc.sql("""
              INSERT INTO notifications
                (id,couple_id,to_user,from_user,from_name,type,title,content,related_id,is_read,created_at)
              VALUES (:id,:couple,:to,:from,:fromName,'task','新任务',:content,:related,0,:now)
              """)
          .param("id", notificationId).param("couple", couple.coupleId()).param("to", couple.otherId())
          .param("from", openid).param("fromName", sender)
          .param("content", truncate(sender + "给你指派了一个任务：" + title, 500))
          .param("related", id).param("now", Instant.now()).update();
      outbox.enqueue(notificationId, couple.otherId());
    }
    return mutable("id", id, "duplicated", inserted == 0);
  }

  private Map<String, Object> complete(String openid, JsonNode data) {
    String id = requiredText(data, "id", "缺少任务ID");
    var couple = couples.require(openid);
    Map<String, Object> task = one("SELECT * FROM tasks WHERE id=:id AND couple_id=:couple",
        Map.of("id", id, "couple", couple.coupleId()), "无权操作该任务");
    if ("completed".equals(task.get("status"))) {
      if (openid.equals(task.get("completedBy"))) return mutable("duplicated", true);
      throw new BusinessException("任务已由对方完成");
    }
    String assignee = String.valueOf(task.get("assignee"));
    String createdBy = String.valueOf(task.get("createdBy"));
    boolean allowed = assignee.equals("both") || (assignee.equals("me") && createdBy.equals(openid)) ||
        (assignee.equals("partner") && createdBy.equals(couple.otherId()));
    if (!allowed) throw new BusinessException("该任务没有指派给你");
    int reward = Math.min(100, Math.max(0, ((Number) task.get("rewardPoints")).intValue()));

    transactions.executeWithoutResult(status -> {
      Map<String, Object> locked = one("SELECT * FROM tasks WHERE id=:id AND couple_id=:couple FOR UPDATE",
          Map.of("id", id, "couple", couple.coupleId()), "无权操作该任务");
      if ("completed".equals(locked.get("status"))) {
        if (openid.equals(locked.get("completedBy"))) return;
        throw new BusinessException("任务已由对方完成");
      }
      jdbc.sql("UPDATE tasks SET status='completed',completed_by=:user,completed_at=:now WHERE id=:id")
          .param("user", openid).param("now", Instant.now()).param("id", id).update();
      if (reward > 0) {
        ensureBalance(couple.coupleId(), openid);
        String pointId = PointsFunctionHandler.hash("task-reward:" + id);
        int inserted = jdbc.sql("""
                INSERT IGNORE INTO points
                  (id,couple_id,from_user,to_user,amount,reason,note,created_at)
                VALUES (:id,:couple,:user,:user,:amount,:reason,'',:now)
                """)
            .param("id", pointId).param("couple", couple.coupleId()).param("user", openid)
            .param("amount", reward).param("reason", "完成任务: " + task.get("title"))
            .param("now", Instant.now()).update();
        if (inserted == 0) throw new BusinessException("任务奖励已发放");
        jdbc.sql("UPDATE point_balances SET score=score+:amount,updated_at=:now WHERE couple_id=:couple AND user_id=:user")
            .param("amount", reward).param("now", Instant.now()).param("couple", couple.coupleId())
            .param("user", openid).update();
      }
    });

    if (!createdBy.isBlank() && !createdBy.equals(openid)) {
      String notificationId = PointsFunctionHandler.hash("task-complete:" + id + ":" + createdBy);
      String completer = couples.nickname(openid);
      int inserted = jdbc.sql("""
              INSERT IGNORE INTO notifications
                (id,couple_id,to_user,from_user,from_name,type,title,content,related_id,is_read,created_at)
              VALUES (:id,:couple,:to,:from,:name,'task_complete','任务完成',:content,:related,0,:now)
              """)
          .param("id", notificationId).param("couple", couple.coupleId()).param("to", createdBy)
          .param("from", openid).param("name", completer)
          .param("content", truncate(completer + "完成了任务：" + task.get("title"), 500))
          .param("related", id).param("now", Instant.now()).update();
      if (inserted == 1) outbox.enqueue(notificationId, createdBy);
    }
    return ok();
  }

  private Map<String, Object> list(String openid, JsonNode data) {
    String coupleId = couples.require(openid).coupleId();
    String status = data.path("status").asText("");
    List<Map<String, Object>> list = status.isBlank()
        ? rows("SELECT * FROM tasks WHERE couple_id=:couple ORDER BY created_at DESC LIMIT 50", Map.of("couple", coupleId))
        : rows("SELECT * FROM tasks WHERE couple_id=:couple AND status=:status ORDER BY created_at DESC LIMIT 50",
            Map.of("couple", coupleId, "status", status));
    return ok("list", list);
  }

  private Map<String, Object> detail(String openid, JsonNode data) {
    String coupleId = couples.require(openid).coupleId();
    Map<String, Object> task = one("""
            SELECT t.*, creator.nick_name AS creator_name, completer.nick_name AS completer_name
            FROM tasks t
            LEFT JOIN users creator ON creator.id=t.created_by
            LEFT JOIN users completer ON completer.id=t.completed_by
            WHERE t.id=:id AND t.couple_id=:couple
            """, Map.of("id", requiredText(data, "id", "缺少任务ID"), "couple", coupleId), "无权查看该任务");
    task.put("isCreator", openid.equals(task.get("createdBy")));
    task.put("isCompleter", openid.equals(task.get("completedBy")));
    return ok("data", task);
  }

  private Map<String, Object> delete(String openid, JsonNode data) {
    int changed = jdbc.sql("DELETE FROM tasks WHERE id=:id AND couple_id=:couple AND created_by=:user")
        .param("id", requiredText(data, "id", "缺少任务ID"))
        .param("couple", couples.require(openid).coupleId()).param("user", openid).update();
    if (changed == 0) throw new BusinessException("只有创建者可以删除");
    return ok();
  }

  private void ensureBalance(String coupleId, String userId) {
    jdbc.sql("""
            INSERT IGNORE INTO point_balances (id,couple_id,user_id,score,updated_at)
            SELECT :id,:couple,:user,COALESCE(SUM(amount),0),:now
            FROM points WHERE couple_id=:couple AND to_user=:user
            """)
        .param("id", PointsFunctionHandler.hash("balance:" + coupleId + ":" + userId))
        .param("couple", coupleId).param("user", userId).param("now", Instant.now()).update();
  }

  private static String truncate(String value, int max) { return value.substring(0, Math.min(max, value.length())); }
  private static String requestId(JsonNode data) {
    String value = data.path("requestId").asText("").trim();
    if (!value.isBlank() && !value.matches("^[A-Za-z0-9._:-]{8,64}$")) {
      throw new BusinessException("请求 ID 无效");
    }
    return value;
  }
  private static Map<String, Object> mutable(Object... values) {
    Map<String, Object> result = new LinkedHashMap<>(); result.put("code", 0);
    for (int i = 0; i < values.length; i += 2) result.put((String) values[i], values[i + 1]);
    return result;
  }
}
