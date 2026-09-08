package com.lovespace.server.function;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/v1/functions")
public class FunctionController {
  private final FunctionRegistry registry;

  public FunctionController(FunctionRegistry registry) {
    this.registry = registry;
  }

  @PostMapping("/{name}")
  public Map<String, Object> invoke(
      @PathVariable String name,
      @RequestBody(required = false) JsonNode event,
      Authentication authentication
  ) {
    return registry.require(name).handle(
        authentication.getName(),
        event == null ? JsonNodeFactory.instance.objectNode() : event);
  }
}
