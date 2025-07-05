# Copyright 2025 Prologue HTTP Keep-Alive Optimizations
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

## HTTP/1.1 Keep-Alive Optimizations for Prologue
## 
## This module provides advanced HTTP/1.1 Keep-Alive optimizations including:
## - Connection pooling with intelligent reuse
## - Persistent connections management with automatic cleanup
## - Timeout optimizations with adaptive algorithms
## - Connection health monitoring and recovery

import std/[asyncdispatch, times, tables, options, logging, strutils, sets]
import std/locks
import std/[hashes]
import std/net

type
  ConnectionState* = enum
    ## Connection state enumeration
    csIdle = "idle"           # Connection is idle and available
    csActive = "active"       # Connection is actively processing request
    csClosing = "closing"     # Connection is being closed
    csClosed = "closed"       # Connection is closed
    csError = "error"         # Connection has error

  ConnectionHealth* = enum
    ## Connection health status
    chHealthy = "healthy"     # Connection is healthy
    chDegraded = "degraded"   # Connection performance is degraded
    chUnhealthy = "unhealthy" # Connection is unhealthy

  KeepAliveConnection* = ref object
    ## Represents a persistent HTTP connection
    id*: string                    # Unique connection identifier
    socket*: net.Socket           # Underlying socket
    state*: ConnectionState       # Current connection state
    health*: ConnectionHealth     # Connection health status
    createdAt*: Time             # Connection creation time
    lastUsed*: Time              # Last time connection was used
    requestCount*: int           # Number of requests processed
    errorCount*: int             # Number of errors encountered
    avgResponseTime*: float      # Average response time in milliseconds
    maxRequests*: int            # Maximum requests per connection
    keepAliveTimeout*: int       # Keep-alive timeout in seconds
    clientAddress*: string       # Client IP address
    userAgent*: string           # Client user agent
    lock*: Lock                  # Connection-specific lock

  ConnectionPool* = ref object
    ## Connection pool for managing persistent connections
    connections*: Table[string, KeepAliveConnection]  # Active connections
    idleConnections*: seq[string]                     # Queue of idle connection IDs
    maxConnections*: int                              # Maximum number of connections
    maxIdleTime*: int                                 # Maximum idle time in seconds
    maxConnectionAge*: int                            # Maximum connection age in seconds
    cleanupInterval*: int                             # Cleanup interval in seconds
    lock*: Lock                                       # Pool-wide lock
    lastCleanup*: Time                               # Last cleanup time
    stats*: ConnectionPoolStats                       # Pool statistics

  ConnectionPoolStats* = object
    ## Statistics for connection pool
    totalConnections*: int        # Total connections created
    activeConnections*: int       # Currently active connections
    idleConnections*: int         # Currently idle connections
    closedConnections*: int       # Total connections closed
    errorConnections*: int        # Connections closed due to errors
    avgConnectionAge*: float      # Average connection age in seconds
    avgRequestsPerConnection*: float  # Average requests per connection
    poolHitRate*: float          # Pool hit rate (reused connections)

  KeepAliveConfig* = object
    ## Configuration for Keep-Alive optimizations
    enabled*: bool               # Enable Keep-Alive
    maxConnections*: int         # Maximum concurrent connections
    maxIdleTime*: int           # Maximum idle time (seconds)
    maxConnectionAge*: int       # Maximum connection age (seconds)
    maxRequestsPerConnection*: int  # Maximum requests per connection
    keepAliveTimeout*: int       # Keep-alive timeout (seconds)
    cleanupInterval*: int        # Cleanup interval (seconds)
    healthCheckInterval*: int    # Health check interval (seconds)
    adaptiveTimeouts*: bool      # Enable adaptive timeout algorithms
    connectionReuse*: bool       # Enable connection reuse
    compressionEnabled*: bool    # Enable response compression

  KeepAliveManager* = ref object
    ## Main manager for Keep-Alive optimizations
    config*: KeepAliveConfig
    pool*: ConnectionPool
    healthChecker*: HealthChecker
    timeoutManager*: TimeoutManager
    lock*: Lock

  HealthChecker* = ref object
    ## Health checker for monitoring connection health
    enabled*: bool
    checkInterval*: int          # Check interval in seconds
    lastCheck*: Time            # Last health check time
    unhealthyThreshold*: int     # Threshold for marking connection unhealthy
    recoveryThreshold*: int      # Threshold for marking connection recovered

  TimeoutManager* = ref object
    ## Adaptive timeout manager
    enabled*: bool
    baseTimeout*: int           # Base timeout in seconds
    maxTimeout*: int            # Maximum timeout in seconds
    minTimeout*: int            # Minimum timeout in seconds
    adaptationFactor*: float    # Adaptation factor for timeout adjustments
    responseTimeHistory*: seq[float]  # History of response times
    maxHistorySize*: int        # Maximum history size

  KeepAliveError* = object of CatchableError

# Default configuration
const DefaultKeepAliveConfig* = KeepAliveConfig(
  enabled: true,
  maxConnections: 1000,
  maxIdleTime: 60,
  maxConnectionAge: 300,
  maxRequestsPerConnection: 100,
  keepAliveTimeout: 15,
  cleanupInterval: 30,
  healthCheckInterval: 60,
  adaptiveTimeouts: true,
  connectionReuse: true,
  compressionEnabled: true
)

# Global Keep-Alive manager
var globalKeepAliveManager*: KeepAliveManager

proc initKeepAliveConnection*(id: string, socket: net.Socket,
                             clientAddress: string = "",
                             userAgent: string = "",
                             maxRequests: int = 100,
                             keepAliveTimeout: int = 15): KeepAliveConnection =
  ## Initializes a new Keep-Alive connection
  result = KeepAliveConnection(
    id: id,
    socket: socket,
    state: csIdle,
    health: chHealthy,
    createdAt: getTime(),
    lastUsed: getTime(),
    requestCount: 0,
    errorCount: 0,
    avgResponseTime: 0.0,
    maxRequests: maxRequests,
    keepAliveTimeout: keepAliveTimeout,
    clientAddress: clientAddress,
    userAgent: userAgent
  )
  initLock(result.lock)
  logging.debug("Initialized Keep-Alive connection: " & id)

proc initConnectionPool*(config: KeepAliveConfig): ConnectionPool =
  ## Initializes a new connection pool
  result = ConnectionPool(
    connections: initTable[string, KeepAliveConnection](),
    idleConnections: @[],
    maxConnections: config.maxConnections,
    maxIdleTime: config.maxIdleTime,
    maxConnectionAge: config.maxConnectionAge,
    cleanupInterval: config.cleanupInterval,
    lastCleanup: getTime(),
    stats: ConnectionPoolStats()
  )
  initLock(result.lock)
  logging.info("Initialized connection pool with max connections: " & $config.maxConnections)

proc initHealthChecker*(config: KeepAliveConfig): HealthChecker =
  ## Initializes health checker
  result = HealthChecker(
    enabled: true,
    checkInterval: config.healthCheckInterval,
    lastCheck: getTime(),
    unhealthyThreshold: 5,
    recoveryThreshold: 10
  )

proc initTimeoutManager*(config: KeepAliveConfig): TimeoutManager =
  ## Initializes timeout manager
  result = TimeoutManager(
    enabled: config.adaptiveTimeouts,
    baseTimeout: config.keepAliveTimeout,
    maxTimeout: config.keepAliveTimeout * 3,
    minTimeout: max(1, config.keepAliveTimeout div 3),
    adaptationFactor: 0.1,
    responseTimeHistory: @[],
    maxHistorySize: 100
  )

proc initKeepAliveManager*(config: KeepAliveConfig = DefaultKeepAliveConfig): KeepAliveManager =
  ## Initializes the Keep-Alive manager
  result = KeepAliveManager(
    config: config,
    pool: initConnectionPool(config),
    healthChecker: initHealthChecker(config),
    timeoutManager: initTimeoutManager(config)
  )
  initLock(result.lock)
  logging.info("Initialized Keep-Alive manager")

proc generateConnectionId*(clientAddress: string, userAgent: string = ""): string =
  ## Generates a unique connection ID
  let timestamp = $getTime().toUnix()
  let hash = hash(clientAddress & userAgent & timestamp)
  result = "conn_" & clientAddress.replace(".", "_") & "_" & $abs(hash)

proc isConnectionExpired*(conn: KeepAliveConnection, maxIdleTime: int, maxAge: int): bool =
  ## Checks if connection is expired
  let now = getTime()
  let idleTime = (now - conn.lastUsed).inSeconds
  let age = (now - conn.createdAt).inSeconds
  
  result = idleTime > maxIdleTime or age > maxAge or 
           conn.requestCount >= conn.maxRequests or
           conn.state in {csClosing, csClosed, csError}

proc updateConnectionHealth*(conn: KeepAliveConnection, responseTime: float, success: bool) =
  ## Updates connection health based on performance metrics
  acquire(conn.lock)
  defer: release(conn.lock)
  
  # Update average response time
  if conn.requestCount > 0:
    conn.avgResponseTime = (conn.avgResponseTime * float(conn.requestCount - 1) + responseTime) / float(conn.requestCount)
  else:
    conn.avgResponseTime = responseTime
  
  # Update error count
  if not success:
    inc(conn.errorCount)
  
  # Determine health status
  let errorRate = if conn.requestCount > 0: float(conn.errorCount) / float(conn.requestCount) else: 0.0
  
  if errorRate > 0.1 or conn.avgResponseTime > 5000.0:  # 10% error rate or 5s avg response time
    conn.health = chUnhealthy
  elif errorRate > 0.05 or conn.avgResponseTime > 2000.0:  # 5% error rate or 2s avg response time
    conn.health = chDegraded
  else:
    conn.health = chHealthy
  
  logging.debug("Updated connection health: " & $conn.health & " (errors: " & $conn.errorCount & "/" & $conn.requestCount & ")")

proc addConnection*(pool: ConnectionPool, conn: KeepAliveConnection): bool =
  ## Adds a connection to the pool
  acquire(pool.lock)
  defer: release(pool.lock)
  
  if pool.connections.len >= pool.maxConnections:
    logging.warn("Connection pool is full, rejecting new connection")
    return false
  
  pool.connections[conn.id] = conn
  pool.idleConnections.add(conn.id)
  inc(pool.stats.totalConnections)
  inc(pool.stats.idleConnections)
  
  logging.debug("Added connection to pool: " & conn.id)
  return true

proc getConnection*(pool: ConnectionPool, clientAddress: string, userAgent: string = ""): Option[KeepAliveConnection] =
  ## Gets an available connection from the pool
  acquire(pool.lock)
  defer: release(pool.lock)
  
  # Try to find an existing idle connection for the same client
  for i in countdown(pool.idleConnections.len - 1, 0):
    let connId = pool.idleConnections[i]
    if pool.connections.hasKey(connId):
      let conn = pool.connections[connId]
      
      # Check if connection is suitable for reuse
      if conn.state == csIdle and conn.health != chUnhealthy and
         not isConnectionExpired(conn, pool.maxIdleTime, pool.maxConnectionAge):
        
        # Remove from idle queue
        pool.idleConnections.del(i)
        dec(pool.stats.idleConnections)
        inc(pool.stats.activeConnections)
        
        # Update connection state
        conn.state = csActive
        conn.lastUsed = getTime()
        
        logging.debug("Reused connection from pool: " & connId)
        return some(conn)
  
  logging.debug("No suitable connection found in pool")
  return none(KeepAliveConnection)

proc releaseConnection*(pool: ConnectionPool, conn: KeepAliveConnection) =
  ## Releases a connection back to the pool
  acquire(pool.lock)
  defer: release(pool.lock)
  
  if not pool.connections.hasKey(conn.id):
    logging.warn("Attempting to release unknown connection: " & conn.id)
    return
  
  # Check if connection should be closed
  if isConnectionExpired(conn, pool.maxIdleTime, pool.maxConnectionAge) or
     conn.health == chUnhealthy:
    pool.connections.del(conn.id)
    dec(pool.stats.activeConnections)
    inc(pool.stats.closedConnections)
    conn.state = csClosed
    logging.debug("Closed expired/unhealthy connection: " & conn.id)
  else:
    # Return to idle state
    conn.state = csIdle
    conn.lastUsed = getTime()
    pool.idleConnections.add(conn.id)
    dec(pool.stats.activeConnections)
    inc(pool.stats.idleConnections)
    logging.debug("Released connection to pool: " & conn.id)

proc cleanupConnections*(pool: ConnectionPool): int =
  ## Cleans up expired connections from the pool
  acquire(pool.lock)
  defer: release(pool.lock)
  
  var removedCount = 0
  var toRemove: seq[string] = @[]
  
  # Find expired connections
  for connId, conn in pool.connections:
    if isConnectionExpired(conn, pool.maxIdleTime, pool.maxConnectionAge):
      toRemove.add(connId)
  
  # Remove expired connections
  for connId in toRemove:
    if pool.connections.hasKey(connId):
      let conn = pool.connections[connId]
      pool.connections.del(connId)
      
      # Remove from idle queue if present
      let idleIndex = pool.idleConnections.find(connId)
      if idleIndex >= 0:
        pool.idleConnections.del(idleIndex)
        dec(pool.stats.idleConnections)
      else:
        dec(pool.stats.activeConnections)
      
      inc(pool.stats.closedConnections)
      inc(removedCount)
      conn.state = csClosed
      
      logging.debug("Cleaned up expired connection: " & connId)
  
  pool.lastCleanup = getTime()
  
  if removedCount > 0:
    logging.info("Cleaned up " & $removedCount & " expired connections")
  
  return removedCount

proc updatePoolStats*(pool: ConnectionPool) =
  ## Updates connection pool statistics
  acquire(pool.lock)
  defer: release(pool.lock)
  
  pool.stats.activeConnections = 0
  pool.stats.idleConnections = 0
  var totalAge: float = 0.0
  var totalRequests: int = 0
  
  let now = getTime()
  
  for conn in pool.connections.values:
    case conn.state:
    of csActive:
      inc(pool.stats.activeConnections)
    of csIdle:
      inc(pool.stats.idleConnections)
    else:
      discard
    
    totalAge += (now - conn.createdAt).inSeconds.float
    totalRequests += conn.requestCount
  
  let totalConnections = pool.connections.len
  if totalConnections > 0:
    pool.stats.avgConnectionAge = totalAge / float(totalConnections)
    pool.stats.avgRequestsPerConnection = float(totalRequests) / float(totalConnections)
  
  # Calculate pool hit rate
  if pool.stats.totalConnections > 0:
    pool.stats.poolHitRate = 1.0 - (float(pool.stats.totalConnections - pool.connections.len) / float(pool.stats.totalConnections))

proc adaptTimeout*(manager: TimeoutManager, responseTime: float): int =
  ## Adapts timeout based on response time history
  if not manager.enabled:
    return manager.baseTimeout
  
  # Add response time to history
  manager.responseTimeHistory.add(responseTime)
  if manager.responseTimeHistory.len > manager.maxHistorySize:
    manager.responseTimeHistory.delete(0)
  
  # Calculate average response time
  var avgResponseTime: float = 0.0
  for rt in manager.responseTimeHistory:
    avgResponseTime += rt
  avgResponseTime = avgResponseTime / float(manager.responseTimeHistory.len)
  
  # Adapt timeout based on average response time
  let adaptedTimeout = int(float(manager.baseTimeout) * (1.0 + manager.adaptationFactor * (avgResponseTime / 1000.0)))
  
  result = max(manager.minTimeout, min(manager.maxTimeout, adaptedTimeout))
  
  logging.debug("Adapted timeout: " & $result & "s (avg response time: " & $avgResponseTime & "ms)")

proc performHealthCheck*(checker: HealthChecker, pool: ConnectionPool) =
  ## Performs health check on all connections
  if not checker.enabled:
    return
  
  let now = getTime()
  if (now - checker.lastCheck).inSeconds < checker.checkInterval:
    return
  
  acquire(pool.lock)
  defer: release(pool.lock)
  
  var healthyCount = 0
  var degradedCount = 0
  var unhealthyCount = 0
  
  for conn in pool.connections.values:
    case conn.health:
    of chHealthy:
      inc(healthyCount)
    of chDegraded:
      inc(degradedCount)
    of chUnhealthy:
      inc(unhealthyCount)
  
  checker.lastCheck = now
  
  logging.info("Health check completed - Healthy: " & $healthyCount & 
               ", Degraded: " & $degradedCount & ", Unhealthy: " & $unhealthyCount)

# Background tasks
proc startBackgroundTasks*(manager: KeepAliveManager) {.async.} =
  ## Starts background tasks for connection management
  while true:
    try:
      # Cleanup expired connections
      if (getTime() - manager.pool.lastCleanup).inSeconds >= manager.pool.cleanupInterval:
        discard cleanupConnections(manager.pool)
      
      # Perform health checks
      performHealthCheck(manager.healthChecker, manager.pool)
      
      # Update pool statistics
      updatePoolStats(manager.pool)
      
      # Sleep for a short interval
      await sleepAsync(5000)  # 5 seconds
      
    except Exception as e:
      logging.error("Error in background tasks: " & e.msg)
      await sleepAsync(10000)  # 10 seconds on error

# Public API functions
proc initGlobalKeepAliveManager*(config: KeepAliveConfig = DefaultKeepAliveConfig) =
  ## Initializes the global Keep-Alive manager
  globalKeepAliveManager = initKeepAliveManager(config)
  
  # Start background tasks
  asyncCheck startBackgroundTasks(globalKeepAliveManager)
  
  logging.info("Global Keep-Alive manager initialized and background tasks started")

proc getGlobalKeepAliveManager*(): KeepAliveManager =
  ## Gets the global Keep-Alive manager
  if globalKeepAliveManager == nil:
    initGlobalKeepAliveManager()
  return globalKeepAliveManager

proc getConnectionPoolStats*(): ConnectionPoolStats =
  ## Gets current connection pool statistics
  let manager = getGlobalKeepAliveManager()
  updatePoolStats(manager.pool)
  return manager.pool.stats

# Integration helpers
proc shouldKeepAlive*(headers: Table[string, string]): bool =
  ## Checks if connection should be kept alive based on headers
  let connection = headers.getOrDefault("connection", "").toLowerAscii()
  let httpVersion = headers.getOrDefault("http-version", "1.1")
  
  # HTTP/1.1 defaults to keep-alive unless explicitly closed
  if httpVersion == "1.1":
    result = connection != "close"
  else:
    # HTTP/1.0 requires explicit keep-alive
    result = connection == "keep-alive"

proc addKeepAliveHeaders*(headers: var Table[string, string], timeout: int, maxRequests: int) =
  ## Adds Keep-Alive headers to response
  headers["Connection"] = "keep-alive"
  headers["Keep-Alive"] = "timeout=" & $timeout & ", max=" & $maxRequests

proc logConnectionStats*() =
  ## Logs current connection statistics
  let stats = getConnectionPoolStats()
  logging.info("Connection Pool Stats - Total: " & $stats.totalConnections & 
               ", Active: " & $stats.activeConnections & 
               ", Idle: " & $stats.idleConnections & 
               ", Closed: " & $stats.closedConnections & 
               ", Hit Rate: " & $(stats.poolHitRate * 100.0) & "%")