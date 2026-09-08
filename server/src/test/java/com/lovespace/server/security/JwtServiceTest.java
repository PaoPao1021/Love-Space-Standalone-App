package com.lovespace.server.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.lovespace.server.config.LoveSpaceProperties;
import org.junit.jupiter.api.Test;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

class JwtServiceTest {
  private static final String SECRET = "test-jwt-secret-that-is-at-least-32-bytes-long";

  @Test
  void issuedTokenCanBeVerified() {
    JwtService service = jwtService(Duration.ofMinutes(5));

    String token = service.issue("openid-partner-a");

    assertEquals("openid-partner-a", service.verifyAndGetSubject(token));
  }

  @Test
  void carriesTheAccountRevocationVersion() {
    JwtService service = jwtService(Duration.ofMinutes(5));

    JwtService.VerifiedToken verified = service.verify(service.issue("user-a", 7));

    assertEquals("user-a", verified.subject());
    assertEquals(7, verified.authVersion());
  }

  @Test
  void rejectsTamperedSignature() {
    JwtService service = jwtService(Duration.ofMinutes(5));
    String token = service.issue("openid-partner-a");
    int signatureStart = token.lastIndexOf('.') + 1;
    char replacement = token.charAt(signatureStart) == 'A' ? 'B' : 'A';
    String tampered = token.substring(0, signatureStart) + replacement + token.substring(signatureStart + 1);

    assertNull(service.verifyAndGetSubject(tampered));
  }

  @Test
  void rejectsExpiredToken() {
    JwtService service = jwtService(Duration.ZERO);

    assertNull(service.verifyAndGetSubject(service.issue("openid-partner-a")));
  }

  @Test
  void rejectsMalformedToken() {
    JwtService service = jwtService(Duration.ofMinutes(5));

    assertNull(service.verifyAndGetSubject("not-a-jwt"));
    assertNull(service.verifyAndGetSubject("a.b.c"));
    assertNull(service.verifyAndGetSubject(""));
    assertNull(service.verifyAndGetSubject(null));
  }

  @Test
  void requiresSecretOfAtLeast32Bytes() {
    LoveSpaceProperties properties = properties("too-short", Duration.ofMinutes(5));

    assertThrows(IllegalStateException.class, () -> new JwtService(new ObjectMapper(), properties));
  }

  private static JwtService jwtService(Duration ttl) {
    return new JwtService(new ObjectMapper(), properties(SECRET, ttl));
  }

  private static LoveSpaceProperties properties(String secret, Duration ttl) {
    return new LoveSpaceProperties(
        new LoveSpaceProperties.Auth(secret, ttl, "local-only"),
        null,
        null);
  }
}
