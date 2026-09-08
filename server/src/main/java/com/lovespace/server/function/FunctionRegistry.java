package com.lovespace.server.function;

import com.lovespace.server.api.BusinessException;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Component
public class FunctionRegistry {
  private final Map<String, FunctionHandler> handlers;

  public FunctionRegistry(List<FunctionHandler> handlers) {
    this.handlers = handlers.stream().collect(Collectors.toUnmodifiableMap(FunctionHandler::functionName, Function.identity()));
  }

  public FunctionHandler require(String name) {
    FunctionHandler handler = handlers.get(name);
    if (handler == null) throw new BusinessException("未知服务");
    return handler;
  }
}
