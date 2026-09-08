package com.lovespace.server.storage;

import com.lovespace.server.config.LoveSpaceProperties;
import org.springframework.boot.actuate.health.AbstractHealthIndicator;
import org.springframework.boot.actuate.health.Health;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.HeadBucketRequest;

@Component
public class S3BucketHealthIndicator extends AbstractHealthIndicator {
  private final S3Client client;
  private final String bucket;

  public S3BucketHealthIndicator(S3Client client, LoveSpaceProperties properties) {
    this.client = client;
    this.bucket = properties.storage().bucket();
  }

  @Override
  protected void doHealthCheck(Health.Builder builder) {
    try {
      client.headBucket(HeadBucketRequest.builder().bucket(bucket).build());
      builder.up().withDetail("bucket", bucket);
    } catch (RuntimeException unavailable) {
      builder.down(unavailable).withDetail("bucket", bucket);
    }
  }
}
