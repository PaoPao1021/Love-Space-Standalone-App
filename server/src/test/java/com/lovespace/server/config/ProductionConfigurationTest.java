package com.lovespace.server.config;

import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.PropertySource;
import org.springframework.core.io.ClassPathResource;

import java.io.IOException;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class ProductionConfigurationTest {
  @Test
  void productionCriticalSettingsHaveNoLocalFallbacks() throws IOException {
    PropertySource<?> production = load("application-prod.yml");
    Map<String, String> required = Map.ofEntries(
        Map.entry("spring.datasource.url", "${DB_URL}"),
        Map.entry("spring.datasource.username", "${DB_USERNAME}"),
        Map.entry("spring.datasource.password", "${DB_PASSWORD}"),
        Map.entry("lovespace.auth.jwt-secret", "${JWT_SECRET}"),
        Map.entry("lovespace.storage.internal-endpoint", "${S3_INTERNAL_ENDPOINT}"),
        Map.entry("lovespace.storage.public-endpoint", "${S3_PUBLIC_ENDPOINT}"),
        Map.entry("lovespace.storage.region", "${S3_REGION}"),
        Map.entry("lovespace.storage.bucket", "${S3_BUCKET}"),
        Map.entry("lovespace.storage.access-key", "${S3_ACCESS_KEY}"),
        Map.entry("lovespace.storage.secret-key", "${S3_SECRET_KEY}"));

    required.forEach((property, placeholder) -> assertEquals(placeholder, production.getProperty(property), property));
    assertEquals(Boolean.FALSE, production.getProperty("lovespace.wechat.integrations-enabled"));
  }

  @Test
  void devAndProductionUseSafeAddressDefaults() throws IOException {
    assertEquals("${SERVER_ADDRESS:127.0.0.1}", load("application.yml").getProperty("server.address"));
    assertEquals("${SERVER_ADDRESS:0.0.0.0}", load("application-prod.yml").getProperty("server.address"));
  }

  private static PropertySource<?> load(String resource) throws IOException {
    return new YamlPropertySourceLoader()
        .load(resource, new ClassPathResource(resource))
        .getFirst();
  }
}
