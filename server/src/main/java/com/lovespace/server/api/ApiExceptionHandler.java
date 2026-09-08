package com.lovespace.server.api;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.Map;

@RestControllerAdvice
public class ApiExceptionHandler {
  private static final Logger log = LoggerFactory.getLogger(ApiExceptionHandler.class);

  @ExceptionHandler(BusinessException.class)
  public Map<String, Object> business(BusinessException exception) {
    return Map.of("code", -1, "message", exception.getMessage());
  }

  @ExceptionHandler(MethodArgumentNotValidException.class)
  public Map<String, Object> validation(MethodArgumentNotValidException exception) {
    var error = exception.getBindingResult().getFieldError();
    return Map.of("code", -1, "message", error == null ? "参数无效" : error.getDefaultMessage());
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<Map<String, Object>> unexpected(Exception exception) {
    log.error("Unhandled request failure", exception);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(Map.of("code", -1, "message", "服务暂时不可用"));
  }
}
