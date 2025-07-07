# Copyright 2025 Prologue Performance Optimizations
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

## Connection Pool Implementation for Prologue
## 
## This module provides a high-performance connection pool for database connections
## that can significantly improve application performance by reusing connections
## instead of creating new ones for each database operation.

import std/[asyncdispatch, times, tables, strutils, logging, options]
import std/locks

type
  DbConn* = ref object
    ## Database connection wrapper
    id*: int
    inUse*: bool
    lastUsed*: int64
    connectionString*: string
    isValid*: bool

  ConnectionPool* = ref object
    ## Connection pool for managing database connections
    maxConnections*: int
    minConnections*: int
    connectionTimeout*: int  # milliseconds
    validationInterval*: int  # milliseconds
    connectionString*: string
    connections*: seq[DbConn]
    availableConnections*: int
    lock*: Lock
    nextId: int
    lastValidation*: int64

  ConnectionPoolError* = object of CatchableError

var connectionIdCounter = 0

proc newDbConn*(connectionString: string): DbConn =
  ## Creates a new database connection
  inc(connectionIdCounter)
  result = DbConn(
    id: connectionIdCounter,
    inUse: false,
    lastUsed: getTime().toUnix(),
    connectionString: connectionString,
    isValid: true
  )

proc isValid*(conn: DbConn): bool =
  ## Checks if a database connection is still valid
  # В реална имплементация тук би се проверила връзката с базата данни
  # За демонстрация просто проверяваме дали е била използвана наскоро
  let now = getTime().toUnix()
  result = conn.isValid and (now - conn.lastUsed) < 300  # 5 минути

proc close*(conn: DbConn) =
  ## Closes a database connection
  conn.isValid = false
  logging.debug("Closed database connection with ID: " & $conn.id)

proc newConnectionPool*(
  connectionString: string,
  maxConnections = 10, 
  minConnections = 2,
  connectionTimeout = 30000,
  validationInterval = 30000
): ConnectionPool =
  ## Creates a new connection pool
  result = ConnectionPool(
    maxConnections: maxConnections,
    minConnections: minConnections,
    connectionTimeout: connectionTimeout,
    validationInterval: validationInterval,
    connectionString: connectionString,
    connections: @[],
    availableConnections: 0,
    nextId: 1,
    lastValidation: getTime().toUnix()
  )
  
  initLock(result.lock)
  
  # Инициализиране на минимални връзки
  for i in 0..<minConnections:
    let conn = newDbConn(connectionString)
    result.connections.add(conn)
    inc(result.availableConnections)
  
  logging.info("Connection pool created with " & $minConnections & " initial connections")

proc getConnection*(pool: ConnectionPool): Future[DbConn] {.async.} =
  ## Получава връзка от пула с proper async handling
  var attempts = 0
  const maxAttempts = 10
  const retryDelayMs = 100
  
  while attempts < maxAttempts:
    acquire(pool.lock)
    
    try:
      # Търсене на налична връзка
      if pool.availableConnections > 0:
        for i, conn in pool.connections:
          if not conn.inUse and conn.isValid():
            conn.inUse = true
            conn.lastUsed = getTime().toUnix()
            dec(pool.availableConnections)
            logging.debug("Reusing connection ID: " & $conn.id)
            release(pool.lock)
            return conn
      
      # Създаване на нова връзка ако има място
      if pool.connections.len < pool.maxConnections:
        let conn = newDbConn(pool.connectionString)
        conn.inUse = true
        pool.connections.add(conn)
        logging.debug("Created new connection ID: " & $conn.id)
        release(pool.lock)
        return conn
      
      # Няма налични връзки - освобождаваме lock и изчакваме
      release(pool.lock)
      
    except Exception as e:
      release(pool.lock)
      logging.error("Error getting connection from pool: " & e.msg)
      raise
    
    # Изчакваме малко преди следващия опит
    inc(attempts)
    if attempts < maxAttempts:
      await sleepAsync(retryDelayMs)
      logging.debug("Retrying connection acquisition, attempt: " & $attempts)
  
  # Ако не успеем да получим връзка след всички опити
  raise newException(ConnectionPoolError, "No available connections in pool after " & $maxAttempts & " attempts")

proc releaseConnection*(pool: ConnectionPool, conn: DbConn) {.async.} =
  ## Освобождава връзка обратно в пула
  acquire(pool.lock)
  defer: release(pool.lock)
  
  try:
    for i, c in pool.connections:
      if c.id == conn.id:
        c.inUse = false
        c.lastUsed = getTime().toUnix()
        inc(pool.availableConnections)
        logging.debug("Released connection ID: " & $conn.id)
        return
    
    logging.warn("Attempted to release unknown connection ID: " & $conn.id)
  except Exception as e:
    logging.error("Error releasing connection: " & e.msg)

proc validateConnections*(pool: ConnectionPool) {.async.} =
  ## Валидира и почиства невалидни връзки
  acquire(pool.lock)
  defer: release(pool.lock)
  
  let now = getTime().toUnix()
  if now - pool.lastValidation < (pool.validationInterval div 1000):
    return
  
  pool.lastValidation = now
  
  var i = 0
  var removedCount = 0
  
  while i < pool.connections.len:
    let conn = pool.connections[i]
    if not conn.inUse and not conn.isValid():
      conn.close()
      pool.connections.delete(i)
      dec(pool.availableConnections)
      inc(removedCount)
      continue
    inc(i)
  
  # Осигуряване на минимални връзки
  while pool.availableConnections < pool.minConnections and 
        pool.connections.len < pool.maxConnections:
    let conn = newDbConn(pool.connectionString)
    pool.connections.add(conn)
    inc(pool.availableConnections)
  
  if removedCount > 0:
    logging.info("Validated connection pool: removed " & $removedCount & " invalid connections")

proc getStats*(pool: ConnectionPool): tuple[total: int, available: int, inUse: int] =
  ## Получава статистики за пула
  acquire(pool.lock)
  defer: release(pool.lock)
  
  var inUseCount = 0
  for conn in pool.connections:
    if conn.inUse:
      inc(inUseCount)
  
  result = (
    total: pool.connections.len,
    available: pool.availableConnections,
    inUse: inUseCount
  )

proc close*(pool: ConnectionPool) =
  ## Затваря всички връзки в пула
  acquire(pool.lock)
  defer: release(pool.lock)
  
  for conn in pool.connections:
    if not conn.inUse:
      conn.close()
  
  pool.connections.setLen(0)
  pool.availableConnections = 0
  
  logging.info("Connection pool closed")

# Интеграция с Prologue Context
import ../core/context
import ../core/application

proc initConnectionPool*(app: Prologue, connectionString: string,
                        maxConnections = 10, minConnections = 2) =
  ## Инициализира пул за връзки в Prologue приложението
  let pool = newConnectionPool(connectionString, maxConnections, minConnections)
  app.gScope.appData["connectionPool"] = $cast[int](pool)
  
  logging.info("Connection pool initialized for Prologue app")

proc getConnectionPool*(app: Prologue): ConnectionPool =
  ## Получава пула за връзки от Prologue приложението
  if not app.gScope.appData.hasKey("connectionPool"):
    raise newException(ConnectionPoolError, "Connection pool not initialized")
  
  let poolPtr = parseInt(app.gScope.appData["connectionPool"])
  result = cast[ConnectionPool](poolPtr)

# Simplified connection helper - removed Context dependency for now
proc withConnection*(pool: ConnectionPool, handler: proc(conn: DbConn): Future[void] {.async.}): Future[void] {.async.} =
  ## Изпълнява операция с връзка от пула
  let conn = await pool.getConnection()
  
  try:
    await handler(conn)
  finally:
    await pool.releaseConnection(conn)

# Периодично валидиране на връзките
proc startConnectionPoolMaintenance*(pool: ConnectionPool, intervalSeconds = 30) {.async.} =
  ## Стартира периодично поддържане на пула
  while true:
    await sleepAsync(intervalSeconds * 1000)
    await pool.validateConnections()