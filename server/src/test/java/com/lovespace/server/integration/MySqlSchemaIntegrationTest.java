package com.lovespace.server.integration;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.mysql.MySQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.sql.DriverManager;

import static org.junit.jupiter.api.Assertions.assertEquals;

@Testcontainers(disabledWithoutDocker = true)
class MySqlSchemaIntegrationTest {
  @Container
  private static final MySQLContainer MYSQL = new MySQLContainer(DockerImageName.parse("mysql:8.4.8"))
      .withDatabaseName("lovespace")
      .withUsername("lovespace")
      .withPassword("lovespace-test");

  @Test
  void flywayCreatesTheCompleteMySqlSchema() throws Exception {
    Flyway.configure()
        .dataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword())
        .locations("classpath:db/migration")
        .load()
        .migrate();

    try (var connection = DriverManager.getConnection(
        MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
         var statement = connection.prepareStatement("""
             SELECT COUNT(*) FROM information_schema.tables
             WHERE table_schema = ? AND table_type = 'BASE TABLE'
             """)) {
      statement.setString(1, MYSQL.getDatabaseName());
      try (var result = statement.executeQuery()) {
        result.next();
        // 28 domain tables plus Flyway's schema-history table.
        assertEquals(29, result.getInt(1));
      }

      try (var columns = connection.prepareStatement("""
          SELECT COUNT(*) FROM information_schema.columns
          WHERE table_schema = ? AND (
            (table_name = 'albums' AND column_name = 'client_request_id') OR
            (table_name = 'moments' AND column_name = 'client_request_id') OR
            (table_name = 'photos' AND column_name = 'client_request_id') OR
            (table_name = 'tasks' AND column_name = 'client_request_id') OR
            (table_name = 'dishes' AND column_name = 'client_request_id') OR
            (table_name = 'wishes' AND column_name = 'client_request_id') OR
            (table_name = 'capsules' AND column_name = 'client_request_id') OR
            (table_name = 'notification_outbox' AND column_name IN ('lease_owner', 'lease_until', 'updated_at'))
          )
          """)) {
        columns.setString(1, MYSQL.getDatabaseName());
        try (var result = columns.executeQuery()) {
          result.next();
          assertEquals(10, result.getInt(1));
        }
      }

      try (var indexes = connection.prepareStatement("""
          SELECT COUNT(DISTINCT index_name) FROM information_schema.statistics
          WHERE table_schema = ? AND index_name IN (
            'uk_albums_request', 'uk_moments_request', 'uk_photos_request',
            'uk_tasks_request', 'uk_dishes_request', 'uk_wishes_request',
            'uk_capsules_request', 'idx_notification_outbox_lease'
          )
          """)) {
        indexes.setString(1, MYSQL.getDatabaseName());
        try (var result = indexes.executeQuery()) {
          result.next();
          assertEquals(8, result.getInt(1));
        }
      }
    }
  }
}
