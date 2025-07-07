# Copyright 2025 Prologue PostgreSQL ORM
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## PostgreSQL Driver for Prologue ORM
## 
## This module provides PostgreSQL-specific database operations
## and integrates with the connection pool system.

import std/[asyncdispatch, logging, json, strutils, sequtils, times]
import db_connector/db_postgres
import ./types
import ../../connectionpool

type
  PgDriver* = ref object
    config*: PgConfig
    connectionPool*: ConnectionPool

  PgConnection* = ref object
    poolConn*: connectionpool.DbConn
    pgConn*: db_postgres.DbConn

  PgResult* = object
    rows*: seq[seq[string]]
    columns*: seq[string]
    affectedRows*: int

  PgDriverError* = object of CatchableError

# Create new PostgreSQL driver
proc newPgDriver*(config: PgConfig): PgDriver =
  result = PgDriver(
    config: config,
    connectionPool: newConnectionPool(
      connectionString = config.buildConnectionString(),
      maxConnections = config.maxConnections,
      minConnections = config.minConnections,
      connectionTimeout = config.connectionTimeout
    )
  )
  
  logging.info("PostgreSQL driver initialized for database: " & config.database)

# Get PostgreSQL connection from pool with better error handling
proc getConnection*(driver: PgDriver): Future[PgConnection] {.async.} =
  var poolConn: connectionpool.DbConn = nil
  
  try:
    # Get connection from pool
    poolConn = await driver.connectionPool.getConnection()
    
    # Open actual PostgreSQL connection using separate parameters (like basic_test)
    let pgConn = open(
      driver.config.host,
      driver.config.username,
      driver.config.password,
      driver.config.database
    )
    
    result = PgConnection(
      poolConn: poolConn,
      pgConn: pgConn
    )
    
    logging.debug("PostgreSQL connection established from pool")
    
  except Exception as e:
    # Release pool connection if PostgreSQL connection fails
    if not poolConn.isNil:
      try:
        await driver.connectionPool.releaseConnection(poolConn)
      except Exception as releaseError:
        logging.error("Failed to release pool connection: " & releaseError.msg)
    
    let errorMsg = "Failed to establish PostgreSQL connection: " & e.msg
    logging.error(errorMsg)
    raise newException(PgDriverError, errorMsg)

# Release PostgreSQL connection back to pool
proc releaseConnection*(driver: PgDriver, conn: PgConnection) {.async.} =
  try:
    if not conn.pgConn.isNil:
      conn.pgConn.close()
    
    await driver.connectionPool.releaseConnection(conn.poolConn)
    logging.debug("PostgreSQL connection released")
    
  except Exception as e:
    logging.error("Error releasing PostgreSQL connection: " & e.msg)

# Execute SQL query with parameters and better async handling
proc execute*(driver: PgDriver, sql: string, params: seq[string] = @[]): Future[PgResult] {.async.} =
  var conn: PgConnection = nil
  
  try:
    # Get connection
    conn = await driver.getConnection()
    
    logging.debug("Executing SQL: " & sql)
    if params.len > 0:
      logging.debug("Parameters: " & $params)
    
    var result = PgResult()
    
    # Check SQL type and execute accordingly
    let sqlLower = sql.strip().toLowerAscii()
    
    if sqlLower.startsWith("select") or sqlLower.startsWith("with"):
      # SELECT/WITH query - return rows
      # Convert $1, $2, etc. to ? for db_postgres
      var convertedSql = sql
      for i in 1..params.len:
        convertedSql = convertedSql.replace("$" & $i, "?")
      
      let rows = conn.pgConn.getAllRows(sql(convertedSql), params)
      result.rows = rows
      result.affectedRows = rows.len
      
      # Get column names (simplified - in real implementation would use proper metadata)
      if rows.len > 0:
        for i in 0..<rows[0].len:
          result.columns.add("col_" & $i)
      
    else:
      # INSERT/UPDATE/DELETE - execute and get affected rows
      # Convert $1, $2, etc. to ? for db_postgres
      var convertedSql = sql
      for i in 1..params.len:
        convertedSql = convertedSql.replace("$" & $i, "?")
      
      conn.pgConn.exec(sql(convertedSql), params)
      # In a real implementation, we would get the actual affected row count
      result.affectedRows = 1
    
    return result
    
  except Exception as e:
    let errorMsg = "SQL execution failed: " & e.msg & " (SQL: " & sql & ")"
    logging.error(errorMsg)
    raise newException(PgDriverError, errorMsg)
    
  finally:
    # Always release connection
    if not conn.isNil:
      try:
        await driver.releaseConnection(conn)
      except Exception as releaseError:
        logging.error("Failed to release connection after SQL execution: " & releaseError.msg)

# Execute single row query with better async handling
proc queryRow*(driver: PgDriver, sql: string, params: seq[string] = @[]): Future[seq[string]] {.async.} =
  var conn: PgConnection = nil
  
  try:
    conn = await driver.getConnection()
    logging.debug("Executing single row query: " & sql)
    
    # Convert $1, $2, etc. to ? for db_postgres
    var convertedSql = sql
    for i in 1..params.len:
      convertedSql = convertedSql.replace("$" & $i, "?")
    
    result = conn.pgConn.getRow(sql(convertedSql), params)
    
  except Exception as e:
    let errorMsg = "Query row failed: " & e.msg & " (SQL: " & sql & ")"
    logging.error(errorMsg)
    raise newException(PgDriverError, errorMsg)
    
  finally:
    if not conn.isNil:
      try:
        await driver.releaseConnection(conn)
      except Exception as releaseError:
        logging.error("Failed to release connection after queryRow: " & releaseError.msg)

# Execute scalar query (single value) with better async handling
proc queryValue*(driver: PgDriver, sql: string, params: seq[string] = @[]): Future[string] {.async.} =
  var conn: PgConnection = nil
  
  try:
    conn = await driver.getConnection()
    logging.debug("Executing scalar query: " & sql)
    
    # Convert $1, $2, etc. to ? for db_postgres
    var convertedSql = sql
    for i in 1..params.len:
      convertedSql = convertedSql.replace("$" & $i, "?")
    
    result = conn.pgConn.getValue(sql(convertedSql), params)
    
  except Exception as e:
    let errorMsg = "Query value failed: " & e.msg & " (SQL: " & sql & ")"
    logging.error(errorMsg)
    raise newException(PgDriverError, errorMsg)
    
  finally:
    if not conn.isNil:
      try:
        await driver.releaseConnection(conn)
      except Exception as releaseError:
        logging.error("Failed to release connection after queryValue: " & releaseError.msg)

# Test database connection
proc testConnection*(driver: PgDriver): Future[bool] {.async.} =
  try:
    let version = await driver.queryValue("SELECT version()")
    logging.info("PostgreSQL connection test successful. Version: " & version)
    return true
    
  except Exception as e:
    logging.error("PostgreSQL connection test failed: " & e.msg)
    return false

# Execute transaction with proper async handling
proc withTransaction*[T](driver: PgDriver, operation: proc(): Future[T] {.async.}): Future[T] {.async.} =
  let conn = await driver.getConnection()
  var transactionStarted = false
  
  try:
    # Start transaction
    conn.pgConn.exec(sql"BEGIN")
    transactionStarted = true
    logging.debug("Transaction started")
    
    # Execute operation
    result = await operation()
    
    # Commit transaction
    conn.pgConn.exec(sql"COMMIT")
    transactionStarted = false
    logging.debug("Transaction committed")
    
  except Exception as e:
    # Rollback if transaction was started
    if transactionStarted:
      try:
        conn.pgConn.exec(sql"ROLLBACK")
        logging.debug("Transaction rolled back due to error: " & e.msg)
      except Exception as rollbackError:
        logging.error("Failed to rollback transaction: " & rollbackError.msg)
    
    logging.error("Transaction error: " & e.msg)
    raise
    
  finally:
    await driver.releaseConnection(conn)

# Simplified transaction for void operations
proc withTransactionVoid*(driver: PgDriver, operation: proc(): Future[void] {.async.}): Future[void] {.async.} =
  let conn = await driver.getConnection()
  var transactionStarted = false
  
  try:
    # Start transaction
    conn.pgConn.exec(sql"BEGIN")
    transactionStarted = true
    logging.debug("Transaction started")
    
    # Execute operation
    await operation()
    
    # Commit transaction
    conn.pgConn.exec(sql"COMMIT")
    transactionStarted = false
    logging.debug("Transaction committed")
    
  except Exception as e:
    # Rollback if transaction was started
    if transactionStarted:
      try:
        conn.pgConn.exec(sql"ROLLBACK")
        logging.debug("Transaction rolled back due to error: " & e.msg)
      except Exception as rollbackError:
        logging.error("Failed to rollback transaction: " & rollbackError.msg)
    
    logging.error("Transaction error: " & e.msg)
    raise
    
  finally:
    await driver.releaseConnection(conn)

# Get table schema information
proc getTableSchema*(driver: PgDriver, tableName: string): Future[seq[tuple[name: string, pgType: string, nullable: bool]]] {.async.} =
  let sql = """
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns 
    WHERE table_name = $1
    ORDER BY ordinal_position
  """
  
  let rows = await driver.execute(sql, @[tableName])
  
  for row in rows.rows:
    if row.len >= 3:
      result.add((
        name: row[0],
        pgType: row[1],
        nullable: row[2].toLowerAscii() == "yes"
      ))

# Check if table exists
proc tableExists*(driver: PgDriver, tableName: string): Future[bool] {.async.} =
  let sql = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables 
      WHERE table_name = $1
    )
  """
  
  let result = await driver.queryValue(sql, @[tableName])
  return result.toLowerAscii() == "t" or result.toLowerAscii() == "true"

# Create table from schema
proc createTable*(driver: PgDriver, tableName: string, columns: seq[tuple[name: string, pgType: PgFieldType, constraints: seq[PgConstraint]]]): Future[void] {.async.} =
  var sql = "CREATE TABLE " & tableName & " ("
  var columnDefs: seq[string] = @[]
  
  for col in columns:
    var colDef = col.name & " " & $col.pgType
    
    for constraint in col.constraints:
      colDef.add(" " & $constraint)
    
    columnDefs.add(colDef)
  
  sql.add(columnDefs.join(", "))
  sql.add(")")
  
  let result = await driver.execute(sql)
  logging.info("Table created: " & tableName & " (affected rows: " & $result.affectedRows & ")")

# Drop table
proc dropTable*(driver: PgDriver, tableName: string, ifExists = true): Future[void] {.async.} =
  var sql = "DROP TABLE "
  if ifExists:
    sql.add("IF EXISTS ")
  sql.add(tableName)
  
  let result = await driver.execute(sql)
  logging.info("Table dropped: " & tableName & " (affected rows: " & $result.affectedRows & ")")

# Close driver and cleanup
proc close*(driver: PgDriver) =
  if not driver.connectionPool.isNil:
    driver.connectionPool.close()
  logging.info("PostgreSQL driver closed")