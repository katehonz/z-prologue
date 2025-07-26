# Copyright 2025 Prologue HTTP Connection Pooling Optimizations
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

## Advanced HTTP Connection Pooling for Prologue
##
## This module provides sophisticated HTTP connection pooling with:
## - Intelligent connection reuse strategies
## - Load balancing across connections
## - Connection health monitoring
## - Adaptive pool sizing
## - Connection lifecycle management

import std/[asyncdispatch, times, tables, options, logging, strutils, math]
import std/locks
import std/hashes
import std/net

type
  PoolStrategy* = enum
    ## Connection pool strategy
    psRoundRobin = "round_robin"     # Round-robin selection
    psLeastUsed = "least_used"       # Least used connection first
    psHealthBased = "health_based"   # Health-based selection
    psAdaptive = "adaptive"          # Adaptive strategy based on metrics

  ConnectionPriority* = enum
    ## Connection priority levels
    cpLow = "low"
    cpNormal = "normal"
    cpHigh = "high"
    cpCritical = "critical"

  PooledConnection* = ref object
    ## Enhanced pooled connection with metrics
    id*: string
    socket*: net.Socket
    createdAt*: Time
    lastUsed*: Time
    useCount*: int
    errorCount*: int
    avgResponseTime*: float
    priority*: ConnectionPriority
    clientId*: string
    isHealthy*: bool
    isIdle*: bool
    lock*: Lock
    metadata*: Table[string, string]

  ConnectionGroup* = ref object
    ## Group of connections for specific client/purpose
    groupId*: string
    connections*: seq[PooledConnection]
    strategy*: PoolStrategy
    maxConnections*: int
    currentIndex*: int  # For round-robin
    lock*: Lock

  HttpConnectionPool* = ref object
    ## Advanced connection pool with grouping and strategies
    groups*: Table[string, ConnectionGroup]
    globalConnections*: seq[PooledConnection]
    maxGlobalConnections*: int
    defaultStrategy*: PoolStrategy
    adaptiveThresholds*: AdaptiveThresholds
    metrics*: PoolMetrics
    config*: PoolConfig
    lock*: Lock

  AdaptiveThresholds* = object
    ## Thresholds for adaptive behavior
    responseTimeThreshold*: float    # ms
    errorRateThreshold*: float       # percentage
    utilizationThreshold*: float     # percentage
    healthCheckInterval*: int        # seconds

  PoolMetrics* = object
    ## Comprehensive pool metrics
    totalConnections*: int
    activeConnections*: int
    idleConnections*: int
    groupCount*: int
    avgResponseTime*: float
    errorRate*: float
    utilizationRate*: float
    hitRate*: float
    missRate*: float
    lastMetricsUpdate*: Time

  PoolConfig* = object
    ## Pool configuration
    maxGlobalConnections*: int
    maxGroupConnections*: int
    defaultStrategy*: PoolStrategy
    enableAdaptive*: bool
    enableHealthChecks*: bool
    enableMetrics*: bool
    cleanupInterval*: int
    metricsInterval*: int
    connectionTimeout*: int
    idleTimeout*: int

  PoolError* = object of CatchableError

# Default configuration
const DefaultPoolConfig* = PoolConfig(
  maxGlobalConnections: 2000,
  maxGroupConnections: 100,
  defaultStrategy: psAdaptive,
  enableAdaptive: true,
  enableHealthChecks: true,
  enableMetrics: true,
  cleanupInterval: 30,
  metricsInterval: 10,
  connectionTimeout: 30,
  idleTimeout: 300
)

proc initPooledConnection*(id: string, socket: net.Socket,
                          clientId: string = "",
                          priority: ConnectionPriority = cpNormal): PooledConnection =
  ## Initializes a new pooled connection
  result = PooledConnection(
    id: id,
    socket: socket,
    createdAt: getTime(),
    lastUsed: getTime(),
    useCount: 0,
    errorCount: 0,
    avgResponseTime: 0.0,
    priority: priority,
    clientId: clientId,
    isHealthy: true,
    isIdle: true,
    metadata: initTable[string, string]()
  )
  initLock(result.lock)
  logging.debug("Initialized pooled connection: " & id)

proc initConnectionGroup*(groupId: string, strategy: PoolStrategy = psRoundRobin,
                         maxConnections: int = 50): ConnectionGroup =
  ## Initializes a new connection group
  result = ConnectionGroup(
    groupId: groupId,
    connections: @[],
    strategy: strategy,
    maxConnections: maxConnections,
    currentIndex: 0
  )
  initLock(result.lock)
  logging.debug("Initialized connection group: " & groupId)

proc initHttpConnectionPool*(config: PoolConfig = DefaultPoolConfig): HttpConnectionPool =
  ## Initializes HTTP connection pool
  result = HttpConnectionPool(
    groups: initTable[string, ConnectionGroup](),
    globalConnections: @[],
    maxGlobalConnections: config.maxGlobalConnections,
    defaultStrategy: config.defaultStrategy,
    adaptiveThresholds: AdaptiveThresholds(
      responseTimeThreshold: 1000.0,
      errorRateThreshold: 0.05,
      utilizationThreshold: 0.8,
      healthCheckInterval: 60
    ),
    metrics: PoolMetrics(lastMetricsUpdate: getTime()),
    config: config
  )
  initLock(result.lock)
  logging.info("Initialized advanced connection pool")

proc calculateConnectionScore*(conn: PooledConnection, strategy: PoolStrategy): float =
  ## Calculates connection score for selection
  case strategy:
  of psRoundRobin:
    result = 1.0  # All connections equal for round-robin
  of psLeastUsed:
    result = 1.0 / (float(conn.useCount) + 1.0)
  of psHealthBased:
    let healthScore = if conn.isHealthy: 1.0 else: 0.1
    let errorScore = 1.0 / (float(conn.errorCount) + 1.0)
    let responseScore = 1.0 / (conn.avgResponseTime + 1.0)
    result = healthScore * errorScore * responseScore
  of psAdaptive:
    # Combine multiple factors
    let healthFactor = if conn.isHealthy: 1.0 else: 0.2
    let usageFactor = 1.0 / (float(conn.useCount) + 1.0)
    let errorFactor = 1.0 / (float(conn.errorCount) + 1.0)
    let responseFactor = 1000.0 / (conn.avgResponseTime + 1000.0)
    let priorityFactor = case conn.priority:
      of cpCritical: 2.0
      of cpHigh: 1.5
      of cpNormal: 1.0
      of cpLow: 0.5
    
    result = healthFactor * usageFactor * errorFactor * responseFactor * priorityFactor

proc selectConnectionFromGroup*(group: ConnectionGroup): Option[PooledConnection] =
  ## Selects best connection from group based on strategy
  acquire(group.lock)
  defer: release(group.lock)
  
  if group.connections.len == 0:
    return none(PooledConnection)
  
  # Filter healthy and idle connections
  var availableConnections: seq[PooledConnection] = @[]
  for conn in group.connections:
    if conn.isHealthy and conn.isIdle:
      availableConnections.add(conn)
  
  if availableConnections.len == 0:
    return none(PooledConnection)
  
  case group.strategy:
  of psRoundRobin:
    let index = group.currentIndex mod availableConnections.len
    group.currentIndex = (group.currentIndex + 1) mod availableConnections.len
    result = some(availableConnections[index])
  
  of psLeastUsed:
    var bestConn = availableConnections[0]
    for conn in availableConnections[1..^1]:
      if conn.useCount < bestConn.useCount:
        bestConn = conn
    result = some(bestConn)
  
  of psHealthBased, psAdaptive:
    var bestConn = availableConnections[0]
    var bestScore = calculateConnectionScore(bestConn, group.strategy)
    
    for conn in availableConnections[1..^1]:
      let score = calculateConnectionScore(conn, group.strategy)
      if score > bestScore:
        bestScore = score
        bestConn = conn
    
    result = some(bestConn)

proc addConnectionToGroup*(pool: HttpConnectionPool, groupId: string,
                          conn: PooledConnection): bool =
  ## Adds connection to specific group
  acquire(pool.lock)
  defer: release(pool.lock)
  
  if not pool.groups.hasKey(groupId):
    pool.groups[groupId] = initConnectionGroup(groupId, pool.defaultStrategy)
  
  let group = pool.groups[groupId]
  
  acquire(group.lock)
  defer: release(group.lock)
  
  if group.connections.len >= group.maxConnections:
    logging.warn("Connection group is full: " & groupId)
    return false
  
  group.connections.add(conn)
  pool.globalConnections.add(conn)
  
  logging.debug("Added connection to group " & groupId & ": " & conn.id)
  return true

proc getConnectionFromGroup*(pool: HttpConnectionPool, groupId: string): Option[PooledConnection] =
  ## Gets connection from specific group
  acquire(pool.lock)
  defer: release(pool.lock)
  
  if not pool.groups.hasKey(groupId):
    return none(PooledConnection)
  
  let group = pool.groups[groupId]
  let connOpt = selectConnectionFromGroup(group)
  
  if connOpt.isSome:
    let conn = connOpt.get
    acquire(conn.lock)
    defer: release(conn.lock)
    
    conn.isIdle = false
    conn.lastUsed = getTime()
    inc(conn.useCount)
    
    logging.debug("Retrieved connection from group " & groupId & ": " & conn.id)
  
  return connOpt

proc releaseConnectionToGroup*(pool: HttpConnectionPool, conn: PooledConnection,
                              responseTime: float = 0.0, success: bool = true) =
  ## Releases connection back to its group
  acquire(conn.lock)
  defer: release(conn.lock)
  
  conn.isIdle = true
  conn.lastUsed = getTime()
  
  # Update metrics
  if responseTime > 0.0:
    if conn.useCount > 1:
      conn.avgResponseTime = (conn.avgResponseTime * float(conn.useCount - 1) + responseTime) / float(conn.useCount)
    else:
      conn.avgResponseTime = responseTime
  
  if not success:
    inc(conn.errorCount)
    
    # Check if connection should be marked unhealthy
    let errorRate = float(conn.errorCount) / float(conn.useCount)
    if errorRate > pool.adaptiveThresholds.errorRateThreshold or
       conn.avgResponseTime > pool.adaptiveThresholds.responseTimeThreshold:
      conn.isHealthy = false
      logging.warn("Connection marked unhealthy: " & conn.id)
  
  logging.debug("Released connection: " & conn.id)

proc cleanupUnhealthyConnections*(pool: HttpConnectionPool): int =
  ## Removes unhealthy connections from pool
  acquire(pool.lock)
  defer: release(pool.lock)
  
  var removedCount = 0
  let now = getTime()
  
  # Clean up from groups
  for groupId, group in pool.groups.mpairs:
    acquire(group.lock)
    defer: release(group.lock)
    
    var i = 0
    while i < group.connections.len:
      let conn = group.connections[i]
      let age = (now - conn.createdAt).inSeconds
      let idleTime = (now - conn.lastUsed).inSeconds
      
      if not conn.isHealthy or age > pool.config.connectionTimeout or
         idleTime > pool.config.idleTimeout:
        group.connections.del(i)
        inc(removedCount)
        logging.debug("Removed unhealthy/expired connection: " & conn.id)
      else:
        inc(i)
  
  # Clean up global connections list
  var i = 0
  while i < pool.globalConnections.len:
    let conn = pool.globalConnections[i]
    if not conn.isHealthy:
      pool.globalConnections.del(i)
    else:
      inc(i)
  
  if removedCount > 0:
    logging.info("Cleaned up " & $removedCount & " unhealthy connections")
  
  return removedCount

proc updatePoolMetrics*(pool: HttpConnectionPool) =
  ## Updates pool metrics
  acquire(pool.lock)
  defer: release(pool.lock)
  
  var totalConnections = 0
  var activeConnections = 0
  var idleConnections = 0
  var totalResponseTime: float = 0.0
  var totalErrors = 0
  var totalRequests = 0
  
  for conn in pool.globalConnections:
    inc(totalConnections)
    if conn.isIdle:
      inc(idleConnections)
    else:
      inc(activeConnections)
    
    totalResponseTime += conn.avgResponseTime
    totalErrors += conn.errorCount
    totalRequests += conn.useCount
  
  pool.metrics.totalConnections = totalConnections
  pool.metrics.activeConnections = activeConnections
  pool.metrics.idleConnections = idleConnections
  pool.metrics.groupCount = pool.groups.len
  
  if totalConnections > 0:
    pool.metrics.avgResponseTime = totalResponseTime / float(totalConnections)
    pool.metrics.utilizationRate = float(activeConnections) / float(totalConnections)
  
  if totalRequests > 0:
    pool.metrics.errorRate = float(totalErrors) / float(totalRequests)
  
  pool.metrics.lastMetricsUpdate = getTime()

proc adaptPoolStrategy*(pool: HttpConnectionPool) =
  ## Adapts pool strategy based on current metrics
  if not pool.config.enableAdaptive:
    return
  
  updatePoolMetrics(pool)
  
  let metrics = pool.metrics
  let thresholds = pool.adaptiveThresholds
  
  # Determine if we should change strategy
  var newStrategy = pool.defaultStrategy
  
  if metrics.errorRate > thresholds.errorRateThreshold:
    newStrategy = psHealthBased
    logging.info("Switching to health-based strategy due to high error rate")
  elif metrics.avgResponseTime > thresholds.responseTimeThreshold:
    newStrategy = psLeastUsed
    logging.info("Switching to least-used strategy due to high response times")
  elif metrics.utilizationRate > thresholds.utilizationThreshold:
    newStrategy = psRoundRobin
    logging.info("Switching to round-robin strategy due to high utilization")
  else:
    newStrategy = psAdaptive
  
  # Apply new strategy to all groups
  if newStrategy != pool.defaultStrategy:
    acquire(pool.lock)
    defer: release(pool.lock)
    
    pool.defaultStrategy = newStrategy
    for group in pool.groups.values:
      acquire(group.lock)
      group.strategy = newStrategy
      release(group.lock)

proc performHealthChecks*(pool: HttpConnectionPool) =
  ## Performs health checks on all connections
  if not pool.config.enableHealthChecks:
    return
  
  acquire(pool.lock)
  defer: release(pool.lock)
  
  var healthyCount = 0
  var unhealthyCount = 0
  
  for conn in pool.globalConnections:
    acquire(conn.lock)
    
    # Simple health check based on error rate and response time
    let errorRate = if conn.useCount > 0: float(conn.errorCount) / float(conn.useCount) else: 0.0
    
    if errorRate <= pool.adaptiveThresholds.errorRateThreshold and
       conn.avgResponseTime <= pool.adaptiveThresholds.responseTimeThreshold:
      if not conn.isHealthy:
        conn.isHealthy = true
        logging.debug("Connection recovered: " & conn.id)
      inc(healthyCount)
    else:
      if conn.isHealthy:
        conn.isHealthy = false
        logging.warn("Connection marked unhealthy: " & conn.id)
      inc(unhealthyCount)
    
    release(conn.lock)
  
  logging.debug("Health check completed - Healthy: " & $healthyCount & ", Unhealthy: " & $unhealthyCount)

# Background maintenance tasks
proc startPoolMaintenance*(pool: HttpConnectionPool) {.async.} =
  ## Starts background maintenance tasks
  while true:
    try:
      # Update metrics
      if pool.config.enableMetrics:
        updatePoolMetrics(pool)
      
      # Perform health checks
      performHealthChecks(pool)
      
      # Adapt strategy if needed
      adaptPoolStrategy(pool)
      
      # Cleanup unhealthy connections
      discard cleanupUnhealthyConnections(pool)
      
      # Sleep for cleanup interval
      await sleepAsync(pool.config.cleanupInterval * 1000)
      
    except Exception as e:
      logging.error("Error in pool maintenance: " & e.msg)
      await sleepAsync(30000)  # 30 seconds on error

# Utility functions
proc getPoolStatistics*(pool: HttpConnectionPool): PoolMetrics =
  ## Gets current pool statistics
  updatePoolMetrics(pool)
  return pool.metrics

proc logPoolStatus*(pool: HttpConnectionPool) =
  ## Logs current pool status
  let metrics = getPoolStatistics(pool)
  logging.info("Pool Status - Total: " & $metrics.totalConnections & 
               ", Active: " & $metrics.activeConnections & 
               ", Idle: " & $metrics.idleConnections & 
               ", Groups: " & $metrics.groupCount & 
               ", Avg Response: " & $metrics.avgResponseTime & "ms" &
               ", Error Rate: " & $(metrics.errorRate * 100.0) & "%" &
               ", Utilization: " & $(metrics.utilizationRate * 100.0) & "%")

proc setConnectionMetadata*(conn: PooledConnection, key: string, value: string) =
  ## Sets metadata for connection
  acquire(conn.lock)
  defer: release(conn.lock)
  conn.metadata[key] = value

proc getConnectionMetadata*(conn: PooledConnection, key: string): string =
  ## Gets metadata from connection
  acquire(conn.lock)
  defer: release(conn.lock)
  return conn.metadata.getOrDefault(key, "")

# Global pool instance
var globalHttpPool*: HttpConnectionPool

proc initGlobalHttpPool*(config: PoolConfig = DefaultPoolConfig) =
  ## Initializes global HTTP connection pool
  globalHttpPool = initHttpConnectionPool(config)
  asyncCheck startPoolMaintenance(globalHttpPool)
  logging.info("Global HTTP connection pool initialized")

proc getGlobalHttpPool*(): HttpConnectionPool =
  ## Gets global HTTP connection pool
  if globalHttpPool == nil:
    initGlobalHttpPool()
  return globalHttpPool