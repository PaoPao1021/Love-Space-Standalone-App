package com.lovespace.server;

import com.lovespace.server.config.LoveSpaceProperties;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.scheduling.annotation.EnableScheduling;

@EnableScheduling
@SpringBootApplication
@EnableConfigurationProperties(LoveSpaceProperties.class)
public class LoveSpaceApplication {
  public static void main(String[] args) {
    SpringApplication.run(LoveSpaceApplication.class, args);
  }
}
