package com.lovespace.server.function;

import com.fasterxml.jackson.databind.JsonNode;

import java.util.Map;

public interface FunctionHandler {
  String functionName();

  Map<String, Object> handle(String openid, JsonNode event);
}
