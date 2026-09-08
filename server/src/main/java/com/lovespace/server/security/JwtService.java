package com.lovespace.server.security;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.config.LoveSpaceProperties;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

@Service
public class JwtService {
  private static final Base64.Encoder URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
  private static final Base64.Decoder URL_DECODER = Base64.getUrlDecoder();
  private final ObjectMapper mapper;
  private final byte[] secret;
  private final long ttlSeconds;

  public JwtService(ObjectMapper mapper, LoveSpaceProperties properties) {
    this.mapper = mapper;
    this.secret = properties.auth().jwtSecret().getBytes(StandardCharsets.UTF_8);
    if (secret.length < 32) throw new IllegalStateException("lovespace.auth.jwt-secret 至少需要 32 字节");
    this.ttlSeconds = properties.auth().tokenTtl().toSeconds();
  }

  public String issue(String openid) {
    return issue(openid, 0);
  }

  public String issue(String userId, int authVersion) {
    try {
      long now = Instant.now().getEpochSecond();
      String header = encode(mapper.writeValueAsBytes(Map.of("alg", "HS256", "typ", "JWT")));
      Map<String, Object> claims = new LinkedHashMap<>();
      claims.put("sub", userId);
      claims.put("iat", now);
      claims.put("exp", now + ttlSeconds);
      claims.put("ver", authVersion);
      claims.put("jti", UUID.randomUUID().toString());
      String payload = encode(mapper.writeValueAsBytes(claims));
      String unsigned = header + "." + payload;
      return unsigned + "." + encode(sign(unsigned));
    } catch (Exception exception) {
      throw new IllegalStateException("无法创建登录令牌", exception);
    }
  }

  public String verifyAndGetSubject(String token) {
    VerifiedToken verified = verify(token);
    return verified == null ? null : verified.subject();
  }

  public VerifiedToken verify(String token) {
    try {
      if (token == null || token.isBlank()) return null;
      String[] parts = token.split("\\.");
      if (parts.length != 3) return null;
      String unsigned = parts[0] + "." + parts[1];
      if (!java.security.MessageDigest.isEqual(sign(unsigned), URL_DECODER.decode(parts[2]))) return null;
      Map<String, Object> claims = mapper.readValue(URL_DECODER.decode(parts[1]), new TypeReference<>() {});
      Number expires = (Number) claims.get("exp");
      Object subject = claims.get("sub");
      if (expires == null || subject == null || expires.longValue() <= Instant.now().getEpochSecond()) return null;
      Number version = claims.get("ver") instanceof Number number ? number : 0;
      return new VerifiedToken(subject.toString(), version.intValue(), expires.longValue());
    } catch (Exception ignored) {
      return null;
    }
  }

  public long ttlSeconds() {
    return ttlSeconds;
  }

  private byte[] sign(String value) throws Exception {
    Mac mac = Mac.getInstance("HmacSHA256");
    mac.init(new SecretKeySpec(secret, "HmacSHA256"));
    return mac.doFinal(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String encode(byte[] bytes) {
    return URL_ENCODER.encodeToString(bytes);
  }

  public record VerifiedToken(String subject, int authVersion, long expiresAtEpochSecond) {}
}
