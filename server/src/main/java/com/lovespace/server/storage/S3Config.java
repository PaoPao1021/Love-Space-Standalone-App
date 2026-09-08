package com.lovespace.server.storage;

import com.lovespace.server.config.LoveSpaceProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

import java.net.URI;

@Configuration
public class S3Config {
  @Bean
  S3Client s3Client(LoveSpaceProperties properties) {
    var storage = properties.storage();
    return S3Client.builder()
        .endpointOverride(URI.create(storage.internalEndpoint()))
        .region(Region.of(storage.region()))
        .credentialsProvider(credentials(storage))
        .serviceConfiguration(configuration(storage))
        .build();
  }

  @Bean
  S3Presigner s3Presigner(LoveSpaceProperties properties) {
    var storage = properties.storage();
    return S3Presigner.builder()
        .endpointOverride(URI.create(storage.publicEndpoint()))
        .region(Region.of(storage.region()))
        .credentialsProvider(credentials(storage))
        .serviceConfiguration(configuration(storage))
        .build();
  }

  private S3Configuration configuration(LoveSpaceProperties.Storage storage) {
    return S3Configuration.builder()
        .pathStyleAccessEnabled(storage.pathStyleAccessEnabled())
        .chunkedEncodingEnabled(storage.chunkedEncodingEnabled())
        .build();
  }

  private StaticCredentialsProvider credentials(LoveSpaceProperties.Storage storage) {
    return StaticCredentialsProvider.create(AwsBasicCredentials.create(storage.accessKey(), storage.secretKey()));
  }
}
