package com.lovespace.server.storage;

import com.lovespace.server.config.LoveSpaceProperties;
import org.junit.jupiter.api.Test;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.net.URI;
import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;

class S3ConfigTest {
  @Test
  void clientUsesInternalEndpointAndPresignerUsesPublicEndpoint() {
    String internalEndpoint = "http://s3.internal:9000";
    String publicEndpoint = "https://files.example.test";
    LoveSpaceProperties properties = properties(internalEndpoint, publicEndpoint);
    S3Config configuration = new S3Config();

    try (var client = configuration.s3Client(properties);
         var presigner = configuration.s3Presigner(properties)) {
      assertEquals(
          URI.create(internalEndpoint),
          client.serviceClientConfiguration().endpointOverride().orElseThrow());

      var signed = presigner.presignGetObject(GetObjectPresignRequest.builder()
          .signatureDuration(Duration.ofMinutes(5))
          .getObjectRequest(GetObjectRequest.builder().bucket("lovespace").key("images/photo.jpg").build())
          .build());
      assertEquals("https", signed.url().getProtocol());
      assertEquals("files.example.test", signed.url().getHost());
    }
  }

  @Test
  void aliyunCompatibilityUsesVirtualHostedStyle() {
    LoveSpaceProperties properties = new LoveSpaceProperties(
        null,
        null,
        new LoveSpaceProperties.Storage(
            "https://s3.oss-cn-hangzhou-internal.aliyuncs.com",
            "https://s3.oss-cn-hangzhou.aliyuncs.com",
            "aws-global",
            "lovespace",
            "access-key",
            "secret-key",
            Duration.ofMinutes(30),
            false,
            false));
    S3Config configuration = new S3Config();

    try (var presigner = configuration.s3Presigner(properties)) {
      var signed = presigner.presignGetObject(GetObjectPresignRequest.builder()
          .signatureDuration(Duration.ofMinutes(5))
          .getObjectRequest(GetObjectRequest.builder().bucket("lovespace").key("images/photo.jpg").build())
          .build());

      assertEquals("lovespace.s3.oss-cn-hangzhou.aliyuncs.com", signed.url().getHost());
    }
  }

  private static LoveSpaceProperties properties(String internalEndpoint, String publicEndpoint) {
    return new LoveSpaceProperties(
        null,
        null,
        new LoveSpaceProperties.Storage(
            internalEndpoint,
            publicEndpoint,
            "us-east-1",
            "lovespace",
            "access-key",
            "secret-key",
            Duration.ofMinutes(30)));
  }
}
