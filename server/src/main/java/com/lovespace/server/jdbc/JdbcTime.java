package com.lovespace.server.jdbc;

import java.sql.Date;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Calendar;
import java.util.GregorianCalendar;
import java.util.Locale;
import java.util.TimeZone;

/** Explicit UTC conversions for MySQL JDBC temporal values. */
public final class JdbcTime {
  private static final String UTC = "UTC";

  private JdbcTime() {}

  public static Instant instant(ResultSet resultSet, int columnIndex) throws SQLException {
    Timestamp value = resultSet.getTimestamp(columnIndex, utcCalendar());
    return value == null ? null : value.toInstant();
  }

  public static Instant instant(ResultSet resultSet, String columnLabel) throws SQLException {
    Timestamp value = resultSet.getTimestamp(columnLabel, utcCalendar());
    return value == null ? null : value.toInstant();
  }

  public static LocalDate localDate(ResultSet resultSet, int columnIndex) throws SQLException {
    Date value = resultSet.getDate(columnIndex, utcCalendar());
    return value == null ? null : value.toLocalDate();
  }

  private static Calendar utcCalendar() {
    return new GregorianCalendar(TimeZone.getTimeZone(UTC), Locale.ROOT);
  }
}
