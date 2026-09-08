package com.lovespace.server.security;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
  private final JwtService jwtService;
  private final JdbcClient jdbc;

  public JwtAuthenticationFilter(JwtService jwtService, JdbcClient jdbc) {
    this.jwtService = jwtService;
    this.jdbc = jdbc;
  }

  @Override
  protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
      throws ServletException, IOException {
    String header = request.getHeader("Authorization");
    if (header != null && header.startsWith("Bearer ")) {
      JwtService.VerifiedToken token = jwtService.verify(header.substring(7));
      if (token != null && isActive(token)) {
        SecurityContextHolder.getContext().setAuthentication(
            new UsernamePasswordAuthenticationToken(token.subject(), null, List.of()));
      }
    }
    chain.doFilter(request, response);
  }

  private boolean isActive(JwtService.VerifiedToken token) {
    return jdbc.sql("""
            SELECT COUNT(*) FROM users
            WHERE id = :id AND enabled = 1 AND auth_version = :version
            """)
        .param("id", token.subject())
        .param("version", token.authVersion())
        .query(Integer.class)
        .single() == 1;
  }
}
