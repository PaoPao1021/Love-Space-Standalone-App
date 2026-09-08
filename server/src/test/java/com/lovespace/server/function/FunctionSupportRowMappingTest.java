package com.lovespace.server.function;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.sql.Date;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.Timestamp;
import java.sql.Types;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Calendar;
import java.util.List;
import java.util.Map;
import javax.sql.rowset.RowSetMetaDataImpl;
import javax.sql.rowset.RowSetProvider;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class FunctionSupportRowMappingTest {
  private final TestSupport support = new TestSupport();

  @Test
  void keepsJsonLookingTextAsText() throws Exception {
    Map<String, Object> row = mapSingleColumn("content", "LONGTEXT", "[]");
    assertEquals("[]", row.get("content"));
  }

  @Test
  void parsesOnlyActualMySqlJsonColumns() throws Exception {
    Map<String, Object> row = mapSingleColumn("tags", "JSON", "[\"旅行\",\"纪念日\"]");
    assertEquals(List.of("旅行", "纪念日"), row.get("tags"));
  }

  @Test
  void mapsMySqlDatetimeAndTimestampToUtcInstants() throws Exception {
    Instant createdAt = Instant.parse("2026-08-23T01:02:03.456Z");
    Instant updatedAt = Instant.parse("2026-08-24T04:05:06.789Z");
    ResultSet resultSet = temporalResultSet(
        new String[] {"created_at", "updated_at"},
        new String[] {"DATETIME", "TIMESTAMP"});
    when(resultSet.getTimestamp(eq(1), any(Calendar.class))).thenAnswer(invocation -> {
      assertEquals("UTC", invocation.<Calendar>getArgument(1).getTimeZone().getID());
      return Timestamp.from(createdAt);
    });
    when(resultSet.getTimestamp(eq(2), any(Calendar.class))).thenAnswer(invocation -> {
      assertEquals("UTC", invocation.<Calendar>getArgument(1).getTimeZone().getID());
      return Timestamp.from(updatedAt);
    });

    Map<String, Object> row = support.map(resultSet);

    assertInstanceOf(Instant.class, row.get("createdAt"));
    assertEquals(createdAt, row.get("createdAt"));
    assertEquals(updatedAt, row.get("updatedAt"));
  }

  @Test
  void keepsMySqlDateAsLocalDate() throws Exception {
    LocalDate eventDate = LocalDate.of(2026, 8, 23);
    ResultSet resultSet = temporalResultSet(new String[] {"event_date"}, new String[] {"DATE"});
    when(resultSet.getDate(eq(1), any(Calendar.class))).thenAnswer(invocation -> {
      assertEquals("UTC", invocation.<Calendar>getArgument(1).getTimeZone().getID());
      return Date.valueOf(eventDate);
    });

    Map<String, Object> row = support.map(resultSet);

    assertInstanceOf(LocalDate.class, row.get("eventDate"));
    assertEquals(eventDate, row.get("eventDate"));
  }

  @Test
  void preservesNullTemporalValues() throws Exception {
    ResultSet resultSet = temporalResultSet(
        new String[] {"completed_at", "due_date"},
        new String[] {"DATETIME", "DATE"});

    Map<String, Object> row = support.map(resultSet);

    assertNull(row.get("completedAt"));
    assertNull(row.get("dueDate"));
  }

  private Map<String, Object> mapSingleColumn(String label, String typeName, Object value) throws Exception {
    RowSetMetaDataImpl metadata = new RowSetMetaDataImpl();
    metadata.setColumnCount(1);
    metadata.setColumnName(1, label);
    metadata.setColumnLabel(1, label);
    metadata.setColumnType(1, Types.LONGVARCHAR);
    metadata.setColumnTypeName(1, typeName);
    var rowSet = RowSetProvider.newFactory().createCachedRowSet();
    rowSet.setMetaData(metadata);
    rowSet.moveToInsertRow();
    rowSet.updateObject(1, value);
    rowSet.insertRow();
    rowSet.moveToCurrentRow();
    rowSet.beforeFirst();
    rowSet.next();
    return support.map(rowSet);
  }

  private ResultSet temporalResultSet(String[] labels, String[] typeNames) throws Exception {
    ResultSet resultSet = mock(ResultSet.class);
    ResultSetMetaData metadata = mock(ResultSetMetaData.class);
    when(resultSet.getMetaData()).thenReturn(metadata);
    when(metadata.getColumnCount()).thenReturn(labels.length);
    for (int index = 0; index < labels.length; index++) {
      when(metadata.getColumnLabel(index + 1)).thenReturn(labels[index]);
      when(metadata.getColumnTypeName(index + 1)).thenReturn(typeNames[index]);
    }
    return resultSet;
  }

  private static final class TestSupport extends FunctionSupport {
    private TestSupport() {
      super(null, new ObjectMapper());
    }

    private Map<String, Object> map(ResultSet resultSet) throws Exception {
      return row(resultSet, 0);
    }

    @Override
    public String functionName() {
      return "test";
    }

    @Override
    public Map<String, Object> handle(String openid, JsonNode event) {
      return Map.of();
    }
  }
}
