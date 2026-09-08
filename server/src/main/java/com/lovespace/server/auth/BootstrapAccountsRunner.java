package com.lovespace.server.auth;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionTemplate;

import java.security.SecureRandom;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Locale;
import java.util.UUID;

@Component
@ConditionalOnProperty(prefix = "lovespace.bootstrap", name = "enabled", havingValue = "true")
public class BootstrapAccountsRunner implements ApplicationRunner {
  private static final Logger log = LoggerFactory.getLogger(BootstrapAccountsRunner.class);
  private static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  private static final SecureRandom RANDOM = new SecureRandom();

  private final JdbcClient jdbc;
  private final PasswordEncoder passwordEncoder;
  private final TransactionTemplate transactions;
  private final ConfigurableApplicationContext context;
  private final String userA;
  private final String passwordA;
  private final String nicknameA;
  private final String userB;
  private final String passwordB;
  private final String nicknameB;
  private final String startDate;

  public BootstrapAccountsRunner(
      JdbcClient jdbc,
      PasswordEncoder passwordEncoder,
      TransactionTemplate transactions,
      ConfigurableApplicationContext context,
      @Value("${lovespace.bootstrap.user-a:}") String userA,
      @Value("${lovespace.bootstrap.password-a:}") String passwordA,
      @Value("${lovespace.bootstrap.nickname-a:Partner A}") String nicknameA,
      @Value("${lovespace.bootstrap.user-b:}") String userB,
      @Value("${lovespace.bootstrap.password-b:}") String passwordB,
      @Value("${lovespace.bootstrap.nickname-b:Partner B}") String nicknameB,
      @Value("${lovespace.bootstrap.start-date:}") String startDate
  ) {
    this.jdbc = jdbc;
    this.passwordEncoder = passwordEncoder;
    this.transactions = transactions;
    this.context = context;
    this.userA = normalizeUsername(userA);
    this.passwordA = requirePassword(passwordA, "password-a");
    this.nicknameA = requireNickname(nicknameA, "nickname-a");
    this.userB = normalizeUsername(userB);
    this.passwordB = requirePassword(passwordB, "password-b");
    this.nicknameB = requireNickname(nicknameB, "nickname-b");
    this.startDate = startDate;
  }

  @Override
  public void run(ApplicationArguments args) {
    transactions.executeWithoutResult(status -> bootstrap());
    log.info("LoveSpace bootstrap completed; the application will now stop.");
    SpringApplication.exit(context, () -> 0);
  }

  private void bootstrap() {
    if (userA.equals(userB)) throw new IllegalArgumentException("两个初始化用户名必须不同");
    LocalDate relationshipStart;
    try {
      relationshipStart = LocalDate.parse(startDate);
    } catch (Exception invalid) {
      throw new IllegalArgumentException("lovespace.bootstrap.start-date 必须使用 yyyy-MM-dd", invalid);
    }

    Integer existing = jdbc.sql("SELECT COUNT(*) FROM users WHERE username IN (:a, :b)")
        .param("a", userA)
        .param("b", userB)
        .query(Integer.class)
        .single();
    if (existing != null && existing > 0) {
      throw new IllegalStateException("初始化账号已存在；为防止错绑，bootstrap 不会覆盖已有账号");
    }

    Instant now = Instant.now();
    String userAId = UUID.randomUUID().toString();
    String userBId = UUID.randomUUID().toString();
    String coupleId = UUID.randomUUID().toString();

    insertUser(userAId, userA, passwordA, nicknameA, now);
    insertUser(userBId, userB, passwordB, nicknameB, now);
    jdbc.sql("""
            INSERT INTO couples
              (id, creator_id, partner_id, start_date, status, invite_code, schema_version, created_at)
            VALUES (:id, :creator, :partner, :start, 'active', :code, 2, :now)
            """)
        .param("id", coupleId)
        .param("creator", userAId)
        .param("partner", userBId)
        .param("start", relationshipStart)
        .param("code", inviteCode())
        .param("now", now)
        .update();
    jdbc.sql("UPDATE users SET couple_id = :couple, role = 'creator' WHERE id = :id")
        .param("couple", coupleId).param("id", userAId).update();
    jdbc.sql("UPDATE users SET couple_id = :couple, role = 'partner' WHERE id = :id")
        .param("couple", coupleId).param("id", userBId).update();
    log.info("Created the two private LoveSpace accounts and bound couple {}", coupleId);
  }

  private void insertUser(String id, String username, String password, String nickname, Instant now) {
    jdbc.sql("""
            INSERT INTO users
              (id, username, password_hash, enabled, auth_version, nick_name, avatar_url,
               couple_id, role, created_at, updated_at)
            VALUES
              (:id, :username, :password, 1, 0, :nickname, '', NULL, '', :now, :now)
            """)
        .param("id", id)
        .param("username", username)
        .param("password", passwordEncoder.encode(password))
        .param("nickname", nickname)
        .param("now", now)
        .update();
  }

  private static String normalizeUsername(String value) {
    String username = value == null ? "" : value.trim().toLowerCase(Locale.ROOT);
    if (!username.matches("[a-z0-9._-]{3,64}")) {
      throw new IllegalArgumentException("bootstrap 用户名必须为3-64位字母、数字、点、下划线或横线");
    }
    return username;
  }

  private static String requirePassword(String value, String property) {
    if (value == null || value.length() < 12 || value.length() > 128) {
      throw new IllegalArgumentException("lovespace.bootstrap." + property + " 必须为12-128位");
    }
    return value;
  }

  private static String requireNickname(String value, String property) {
    String nickname = value == null ? "" : value.trim();
    if (nickname.isBlank() || nickname.length() > 20) {
      throw new IllegalArgumentException("lovespace.bootstrap." + property + " 必须为1-20位");
    }
    return nickname;
  }

  private static String inviteCode() {
    StringBuilder code = new StringBuilder(6);
    for (int index = 0; index < 6; index++) {
      code.append(CODE_ALPHABET.charAt(RANDOM.nextInt(CODE_ALPHABET.length())));
    }
    return code.toString();
  }
}
