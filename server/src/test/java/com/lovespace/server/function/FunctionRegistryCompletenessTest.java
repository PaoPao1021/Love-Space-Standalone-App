package com.lovespace.server.function;

import org.junit.jupiter.api.Test;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AssignableTypeFilter;
import org.springframework.stereotype.Component;

import java.lang.reflect.Constructor;
import java.lang.reflect.Modifier;
import java.util.Arrays;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import java.util.TreeSet;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertTrue;

class FunctionRegistryCompletenessTest {
  private static final Set<String> EXPECTED_NAMES = Set.of(
      "couple",
      "user",
      "anniversary",
      "album",
      "moments",
      "mood",
      "points",
      "menu",
      "task",
      "wish",
      "capsule",
      "quiz",
      "notification",
      "daily-question",
      "monthly-report",
      "fitness");

  @Test
  void registersEveryMigratedCloudFunctionExactlyOnce() {
    List<FunctionHandler> handlers = discoverHandlers();
    Set<String> actualNames = new TreeSet<>();
    for (FunctionHandler handler : handlers) {
      assertTrue(actualNames.add(handler.functionName()),
          () -> "Duplicate function handler name: " + handler.functionName());
    }

    assertEquals(new TreeSet<>(EXPECTED_NAMES), actualNames);

    FunctionRegistry registry = new FunctionRegistry(handlers);
    for (String expectedName : EXPECTED_NAMES) {
      FunctionHandler handler = registry.require(expectedName);
      assertSame(handler, registry.require(handler.functionName()));
    }
  }

  private static List<FunctionHandler> discoverHandlers() {
    ClassPathScanningCandidateComponentProvider scanner =
        new ClassPathScanningCandidateComponentProvider(false);
    scanner.addIncludeFilter(new AssignableTypeFilter(FunctionHandler.class));

    return scanner.findCandidateComponents("com.lovespace.server.function").stream()
        .map(definition -> Objects.requireNonNull(definition.getBeanClassName()))
        .map(FunctionRegistryCompletenessTest::loadClass)
        .filter(type -> !type.isInterface() && !Modifier.isAbstract(type.getModifiers()))
        .filter(type -> type.isAnnotationPresent(Component.class))
        .map(FunctionRegistryCompletenessTest::instantiate)
        .toList();
  }

  private static Class<?> loadClass(String className) {
    try {
      return Class.forName(className);
    } catch (ClassNotFoundException exception) {
      throw new AssertionError("Cannot load function handler " + className, exception);
    }
  }

  private static FunctionHandler instantiate(Class<?> type) {
    try {
      Constructor<?> constructor = Arrays.stream(type.getDeclaredConstructors())
          .max((left, right) -> Integer.compare(left.getParameterCount(), right.getParameterCount()))
          .orElseThrow();
      constructor.setAccessible(true);
      Object[] dependencies = new Object[constructor.getParameterCount()];
      return (FunctionHandler) constructor.newInstance(dependencies);
    } catch (ReflectiveOperationException exception) {
      throw new AssertionError("Cannot instantiate function handler " + type.getName(), exception);
    }
  }

}
