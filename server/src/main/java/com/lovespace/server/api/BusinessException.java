package com.lovespace.server.api;

public class BusinessException extends RuntimeException {
  public BusinessException(String message) {
    super(message);
  }
}
