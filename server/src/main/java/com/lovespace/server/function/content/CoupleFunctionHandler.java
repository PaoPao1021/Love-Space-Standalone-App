package com.lovespace.server.function.content;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.domain.CoupleAccessService;
import com.lovespace.server.storage.MediaService;
import com.lovespace.server.wechat.TextSafetyService;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDate;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Component
public class CoupleFunctionHandler extends ContentFunctionSupport {
  private static final char[] INVITE_ALPHABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ".toCharArray();
  private static final List<String> DEFAULT_ALBUMS = List.of("日常", "约会", "旅行", "美食", "自拍", "节日");
  private final SecureRandom random = new SecureRandom();

  public CoupleFunctionHandler(
      JdbcClient jdbc, ObjectMapper mapper, CoupleAccessService couples,
      TextSafetyService textSafety, MediaService media, TransactionTemplate transactions
  ) {
    super(jdbc, mapper, couples, textSafety, media, transactions);
  }

  @Override
  public String functionName() {
    return "couple";
  }

  @Override
  public Map<String, Object> handle(String openid, JsonNode event) {
    JsonNode input = data(event);
    return switch (action(event)) {
      case "create" -> create(openid, input);
      case "join" -> join(openid, input);
      case "getInfo" -> getInfo(openid);
      case "dissolve" -> dissolve(openid);
      default -> throw error("未知操作");
    };
  }

  private Map<String, Object> create(String openid, JsonNode input) {
    Profile profile = profile(openid, input);
    LocalDate startDate = date(text(input, "startDate"));
    if (startDate == null || startDate.isAfter(today())) return fail("请选择正确的在一起日期");

    for (int attempt = 0; attempt < 4; attempt++) {
      String inviteCode = inviteCode();
      String coupleId = hash32("couple:" + openid + ":" + System.nanoTime() + ":" + newId());
      try {
        transactions.executeWithoutResult(status -> {
          Map<String, Object> user = one("SELECT id, couple_id FROM users WHERE id = :id FOR UPDATE",
              Map.of("id", openid), "用户信息不存在，请重新进入小程序");
          if (user.get("coupleId") != null && !String.valueOf(user.get("coupleId")).isBlank()) {
            throw error("已经绑定过了");
          }
          Instant now = now();
          jdbc.sql("""
                  INSERT INTO couples
                    (id, creator_id, partner_id, start_date, status, invite_code, schema_version, created_at)
                  VALUES (:id, :creator, NULL, :startDate, 'active', :invite, 2, :now)
                  """)
              .param("id", coupleId).param("creator", openid).param("startDate", startDate)
              .param("invite", inviteCode).param("now", now).update();
          jdbc.sql("""
                  UPDATE users
                  SET nick_name = :nickname, avatar_url = :avatar, couple_id = :couple,
                      role = 'creator', updated_at = :now
                  WHERE id = :openid
                  """)
              .param("nickname", profile.nickname()).param("avatar", profile.avatar())
              .param("couple", coupleId).param("now", now).param("openid", openid).update();
          jdbc.sql("""
                  INSERT INTO couple_invites
                    (invite_code, couple_id, status, created_by, created_at, updated_at)
                  VALUES (:invite, :couple, 'active', :creator, :now, :now)
                  """)
              .param("invite", inviteCode).param("couple", coupleId).param("creator", openid).param("now", now).update();
          media.claimOwnedAssets(openid, coupleId);
          ensureDefaults(coupleId, startDate, now);
        });
        Map<String, Object> result = new LinkedHashMap<>();
        result.put("code", 0);
        result.put("coupleId", coupleId);
        result.put("inviteCode", inviteCode);
        result.put("defaultsReady", true);
        return result;
      } catch (DuplicateKeyException collision) {
        if (attempt == 3) throw error("邀请码生成冲突，请重试");
      }
    }
    throw error("邀请码生成冲突，请重试");
  }

  private Map<String, Object> join(String openid, JsonNode input) {
    Profile profile = profile(openid, input);
    String invite = trimmed(input, "inviteCode").toUpperCase();
    if (!invite.matches("[23456789A-HJ-NP-Z]{6}")) return fail("邀请码格式不正确");

    String coupleId = transactions.execute(status -> {
      Map<String, Object> user = one("SELECT id, couple_id FROM users WHERE id = :id FOR UPDATE",
          Map.of("id", openid), "用户信息不存在，请重新进入小程序");
      if (user.get("coupleId") != null && !String.valueOf(user.get("coupleId")).isBlank()) {
        throw error("你已经绑定过了");
      }
      List<Map<String, Object>> matches = rows("""
          SELECT c.id, c.creator_id, c.partner_id, c.status, i.status AS invite_status
          FROM couple_invites i
          JOIN couples c ON c.id = i.couple_id
          WHERE i.invite_code = :invite
          FOR UPDATE
          """, Map.of("invite", invite));
      if (matches.isEmpty()) throw error("邀请码无效或已使用");
      Map<String, Object> target = matches.getFirst();
      String targetId = String.valueOf(target.get("_id"));
      String creatorId = String.valueOf(target.get("creatorId"));
      if (creatorId.equals(openid)) throw error("不能加入自己创建的空间");
      if (!"active".equals(target.get("status")) || !"active".equals(target.get("inviteStatus")) ||
          target.get("partnerId") != null) {
        throw error("邀请码无效或已使用");
      }
      Instant now = now();
      int changed = jdbc.sql("""
              UPDATE couples SET partner_id = :partner
              WHERE id = :id AND status = 'active' AND partner_id IS NULL
              """)
          .param("partner", openid).param("id", targetId).update();
      if (changed != 1) throw error("邀请码已被使用");
      jdbc.sql("""
              UPDATE users
              SET nick_name = :nickname, avatar_url = :avatar, couple_id = :couple,
                  role = 'partner', updated_at = :now
              WHERE id = :openid AND couple_id IS NULL
              """)
          .param("nickname", profile.nickname()).param("avatar", profile.avatar()).param("couple", targetId)
          .param("now", now).param("openid", openid).update();
      jdbc.sql("""
              UPDATE couple_invites
              SET status = 'used', used_by = :openid, used_at = :now, updated_at = :now
              WHERE invite_code = :invite
              """)
          .param("openid", openid).param("now", now).param("invite", invite).update();
      media.claimOwnedAssets(openid, targetId);
      return targetId;
    });
    return ok("coupleId", coupleId);
  }

  private Map<String, Object> getInfo(String openid) {
    Map<String, Object> user = user(openid);
    Object storedCouple = user.get("coupleId");
    if (storedCouple == null || String.valueOf(storedCouple).isBlank()) {
      user.put("coupleId", "");
      user.put("role", user.get("role") == null ? "" : user.get("role"));
      presentAvatar(openid, user);
      Map<String, Object> result = new LinkedHashMap<>();
      result.put("code", 0);
      result.put("couple", null);
      result.put("user", user);
      return result;
    }

    String coupleId = String.valueOf(storedCouple);
    Map<String, Object> couple = one("""
            SELECT id, creator_id AS creator, partner_id AS partner, start_date, status,
                   invite_code, schema_version, created_at, dissolved_at, dissolved_by
            FROM couples WHERE id = :id
            """, Map.of("id", coupleId), "情侣空间状态异常，请联系客服处理");
    String creator = String.valueOf(couple.get("creator"));
    String partnerId = couple.get("partner") == null ? "" : String.valueOf(couple.get("partner"));
    if (!"active".equals(couple.get("status")) || (!openid.equals(creator) && !openid.equals(partnerId))) {
      throw error("情侣空间状态异常，请联系客服处理");
    }
    couple.put("partner", partnerId);
    Number schemaVersion = (Number) couple.get("schemaVersion");
    if (schemaVersion != null && schemaVersion.intValue() == 2) {
      LocalDate startDate = couple.get("startDate") instanceof LocalDate local
          ? local : LocalDate.parse(String.valueOf(couple.get("startDate")));
      transactions.executeWithoutResult(status -> ensureDefaults(coupleId, startDate, now()));
    }
    dateFields(couple, "startDate");

    Map<String, Object> partner = partnerId.isBlank() ? null : user(partnerId);
    user.put("role", user.get("role") == null ? "" : user.get("role"));
    presentAvatar(openid, user);
    if (partner != null) {
      partner.put("role", partner.get("role") == null ? "" : partner.get("role"));
      presentAvatar(openid, partner);
    }
    Map<String, Object> result = new LinkedHashMap<>();
    result.put("code", 0);
    result.put("couple", couple);
    result.put("user", user);
    result.put("partner", partner);
    return result;
  }

  private Map<String, Object> dissolve(String openid) {
    transactions.executeWithoutResult(status -> {
      Map<String, Object> user = one("SELECT id, couple_id FROM users WHERE id = :id FOR UPDATE",
          Map.of("id", openid), "未绑定");
      if (user.get("coupleId") == null || String.valueOf(user.get("coupleId")).isBlank()) throw error("未绑定");
      String coupleId = String.valueOf(user.get("coupleId"));
      Map<String, Object> couple = one("""
              SELECT id, creator_id, partner_id, invite_code, status
              FROM couples WHERE id = :id FOR UPDATE
              """, Map.of("id", coupleId), "空间已经解除");
      String creator = String.valueOf(couple.get("creatorId"));
      String partner = couple.get("partnerId") == null ? "" : String.valueOf(couple.get("partnerId"));
      if (!openid.equals(creator) && !openid.equals(partner)) throw error("无权解除该空间");
      if (!"active".equals(couple.get("status"))) throw error("空间已经解除");
      Instant now = now();
      jdbc.sql("""
              UPDATE couples SET status = 'dissolved', dissolved_at = :now, dissolved_by = :openid
              WHERE id = :id
              """)
          .param("now", now).param("openid", openid).param("id", coupleId).update();
      jdbc.sql("""
              UPDATE users SET couple_id = NULL, role = NULL, updated_at = :now
              WHERE id = :creator OR id = :partner
              """)
          .param("now", now).param("creator", creator).param("partner", partner.isBlank() ? creator : partner).update();
      jdbc.sql("""
              UPDATE couple_invites SET status = 'dissolved', updated_at = :now
              WHERE invite_code = :invite
              """)
          .param("now", now).param("invite", String.valueOf(couple.get("inviteCode"))).update();
    });
    return ok();
  }

  private Profile profile(String openid, JsonNode input) {
    String nickname = trimmed(input, "nickName");
    if (nickname.isEmpty() || nickname.length() > 20) throw error("昵称需要 1-20 个字");
    String rawAvatar = text(input, "avatarUrl");
    String avatar = mediaForStorage(openid, rawAvatar);
    if (!rawAvatar.isBlank() && avatar.isBlank()) throw error("头像地址无效");
    checkTextFor(openid, "昵称包含不适合发布的信息，请修改后重试", 20, nickname);
    return new Profile(nickname, avatar);
  }

  private Map<String, Object> user(String openid) {
    Map<String, Object> result = one("""
            SELECT id, nick_name, avatar_url, couple_id, role, created_at, updated_at
            FROM users WHERE id = :id
            """, Map.of("id", openid), "用户信息不存在，请重新进入小程序");
    if (result.get("coupleId") == null) result.put("coupleId", "");
    return result;
  }

  private void presentAvatar(String viewer, Map<String, Object> user) {
    displayMedia(viewer, user, "avatarUrl", "avatarAssetId");
  }

  private void ensureDefaults(String coupleId, LocalDate startDate, Instant instant) {
    for (String name : DEFAULT_ALBUMS) {
      jdbc.sql("""
              INSERT IGNORE INTO albums
                (id, couple_id, name, cover_url, photo_count, is_default, created_at)
              VALUES (:id, :couple, :name, '', 0, TRUE, :now)
              """)
          .param("id", hash32("default-album:" + coupleId + ":" + name))
          .param("couple", coupleId).param("name", name).param("now", instant).update();
    }
    jdbc.sql("""
            INSERT IGNORE INTO anniversaries
              (id, couple_id, name, date, type, cover_url, note, is_repeat,
               remind_days_before, is_top, created_at, updated_at)
            VALUES (:id, :couple, '在一起纪念日', :date, 'together', '', '', TRUE, 3, TRUE, :now, :now)
            """)
        .param("id", hash32("default-anniversary:" + coupleId)).param("couple", coupleId)
        .param("date", startDate).param("now", instant).update();
  }

  private String inviteCode() {
    StringBuilder result = new StringBuilder(6);
    for (int i = 0; i < 6; i++) result.append(INVITE_ALPHABET[random.nextInt(INVITE_ALPHABET.length)]);
    return result.toString();
  }

  private record Profile(String nickname, String avatar) {}
}
