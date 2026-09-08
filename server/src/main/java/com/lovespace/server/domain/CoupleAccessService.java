package com.lovespace.server.domain;

import com.lovespace.server.api.BusinessException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Service;

@Service
public class CoupleAccessService {
  private final JdbcClient jdbc;

  public CoupleAccessService(JdbcClient jdbc) {
    this.jdbc = jdbc;
  }

  public CoupleContext require(String openid) {
    return jdbc.sql("""
            SELECT u.couple_id, c.creator_id, c.partner_id
            FROM users u
            JOIN couples c ON c.id = u.couple_id AND c.status = 'active'
            WHERE u.id = :openid AND (c.creator_id = :openid OR c.partner_id = :openid)
            """)
        .param("openid", openid)
        .query((rs, rowNum) -> {
          String creator = rs.getString("creator_id");
          String partner = rs.getString("partner_id");
          return new CoupleContext(
              rs.getString("couple_id"),
              creator,
              partner,
              openid.equals(creator) ? partner : creator);
        })
        .optional()
        .orElseThrow(() -> new BusinessException("请先绑定你们的空间"));
  }

  public String nickname(String openid) {
    if (openid == null || openid.isBlank()) return "你的另一半";
    return jdbc.sql("SELECT nick_name FROM users WHERE id = :id")
        .param("id", openid)
        .query(String.class)
        .optional()
        .filter(value -> !value.isBlank())
        .orElse("你的另一半");
  }

  public record CoupleContext(String coupleId, String creatorId, String partnerId, String otherId) {}
}
