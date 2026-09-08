package com.lovespace.server.storage;

import com.lovespace.server.config.LoveSpaceProperties;
import org.junit.jupiter.api.Test;
import org.springframework.boot.actuate.health.Status;
import software.amazon.awssdk.core.exception.SdkClientException;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;
import software.amazon.awssdk.services.s3.model.HeadBucketResponse;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class S3BucketHealthIndicatorTest {
  @Test
  void doesNotProbeBucketUntilHealthIsRequested() {
    S3Client client = mock(S3Client.class);

    new S3BucketHealthIndicator(client, properties());

    verifyNoInteractions(client);
  }

  @Test
  void reportsUpWhenBucketIsReachable() {
    S3Client client = mock(S3Client.class);
    when(client.headBucket(any(HeadBucketRequest.class))).thenReturn(HeadBucketResponse.builder().build());

    var health = new S3BucketHealthIndicator(client, properties()).health();

    assertEquals(Status.UP, health.getStatus());
    assertEquals("lovespace", health.getDetails().get("bucket"));
    verify(client).headBucket(any(HeadBucketRequest.class));
  }

  @Test
  void reportsDownInsteadOfThrowingWhenBucketIsUnavailable() {
    S3Client client = mock(S3Client.class);
    when(client.headBucket(any(HeadBucketRequest.class)))
        .thenThrow(SdkClientException.create("storage unavailable"));

    var health = new S3BucketHealthIndicator(client, properties()).health();

    assertEquals(Status.DOWN, health.getStatus());
    assertEquals("lovespace", health.getDetails().get("bucket"));
    assertTrue(String.valueOf(health.getDetails().get("error")).contains("storage unavailable"));
  }

  private static LoveSpaceProperties properties() {
    return new LoveSpaceProperties(
        null,
        null,
        new LoveSpaceProperties.Storage(
            "http://localhost:9090",
            "http://localhost:9090",
            "us-east-1",
            "lovespace",
            "local",
            "local",
            Duration.ofMinutes(30)));
  }
}
