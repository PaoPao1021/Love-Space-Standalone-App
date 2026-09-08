package com.lovespace.server.function.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.storage.MediaService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@Component
public class UserFunctionHandler extends ContentFunctionSupport {
  public UserFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
  }

  @Override
  public String functionName() {
    return "user";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    if (!"updateProfile".equals(action(event))) throw error("未知操作");
    JsonNode input = data(event);
    Map<String, Object> fields = new LinkedHashMap<>();
    if (input.has("nickName")) {
      String nickname = trimmed(input, "nickName");
      if (nickname.isEmpty() || nickname.length() > 20) return fail("昵称需要1-20个字符");
      checkTextFor(openid, "昵称包含不适合发布的信息，请修改后重试", 20, nickname);
      fields.put("nick", nickname);
    }
    if (input.has("avatarUrl")) {
      String source = text(input, "avatarUrl");
      String avatar = mediaForStorage(openid, source);
      if (!source.isBlank() && avatar.isBlank()) return fail("头像地址无效");
      fields.put("avatar", avatar);
    }
    if (fields.isEmpty()) return fail("没有需要更新的内容");

    StringBuilder sql = new StringBuilder("UPDATE users SET updated_at = :now");
    Map<String, Object> params = new LinkedHashMap<>();
    params.put("now", Instant.now());
    if (fields.containsKey("nick")) {
      sql.append(", nick_name = :nick");
      params.put("nick", fields.get("nick"));
    }
    if (fields.containsKey("avatar")) {
      sql.append(", avatar_url = :avatar");
      params.put("avatar", fields.get("avatar"));
    }
    sql.append(" WHERE id = :openid");
    params.put("openid", openid);
    if (update(sql.toString(), params) != 1) throw error("用户信息不存在，请重新进入小程序");
    return ok();
  }
}
