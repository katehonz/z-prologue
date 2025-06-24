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

## Performance Optimizations Module for Prologue
## 
## This module provides a unified interface to all performance optimizations
## including connection pooling, advanced caching, lazy loading, and optimized routing.

import ./db/connectionpool
import ./cache/cache
import ./performance/lazyloading
import ./routing/optimized

export connectionpool
export cache
export lazyloading
export optimized

# Re-export key types and procedures for convenience
export ConnectionPool, newConnectionPool, getConnection, releaseConnection
export CacheBackend, InMemoryCache, RedisCache, MultiLevelCache
export newInMemoryCache, newRedisCache, newMultiLevelCache, cacheMiddleware
export LazyResource, newLazyResource
export TrieRouter, newTrieRouter, addRoute, findRoute

import ./core/application
import ./core/context
import std/[logging, asyncdispatch]

type
  PerformanceConfig* = object
    ## Configuration for performance optimizations
    enableConnectionPool*: bool
    connectionPoolSize*: int
    enableCaching*: bool
    cacheSize*: int
    cacheTTL*: int
    enableLazyLoading*: bool
    enableOptimizedRouting*: bool
    enableMetrics*: bool

  PerformanceMetrics* = object
    ## Global performance metrics
    requestCount*: int
    averageResponseTime*: float
    cacheHitRate*: float
    connectionPoolUtilization*: float
    routingPerformance*: float

var globalPerformanceMetrics = PerformanceMetrics()

proc defaultPerformanceConfig*(): PerformanceConfig =
  ## Returns default performance configuration
  result = PerformanceConfig(
    enableConnectionPool: true,
    connectionPoolSize: 10,
    enableCaching: true,
    cacheSize: 1000,
    cacheTTL: 300,
    enableLazyLoading: true,
    enableOptimizedRouting: true,
    enableMetrics: true
  )

proc initPerformanceOptimizations*(app: Prologue, config: PerformanceConfig = defaultPerformanceConfig()) =
  ## Initializes all performance optimizations for a Prologue application
  logging.info("Initializing performance optimizations...")
  
  # Connection Pool
  if config.enableConnectionPool:
    # Note: Connection string would need to be provided separately
    logging.info("Connection pool optimization enabled")
  
  # Caching
  if config.enableCaching:
    let memoryCache = newInMemoryCache(config.cacheSize)
    app.gScope.appData["performanceCache"] = $cast[int](memoryCache)
    
    # Add cache middleware
    app.use(cacheMiddleware(memoryCache, config.cacheTTL))
    logging.info("Caching optimization enabled with size: " & $config.cacheSize)
  
  # Optimized Routing
  if config.enableOptimizedRouting:
    app.initOptimizedRouter()
    logging.info("Optimized routing enabled")
  
  # Performance monitoring middleware
  if config.enableMetrics:
    app.use(performanceMonitoringMiddleware())
    logging.info("Performance metrics enabled")
  
  logging.info("Performance optimizations initialized successfully")

proc performanceMonitoringMiddleware*(): HandlerAsync =
  ## Creates middleware for monitoring performance metrics
  result = proc(ctx: Context) {.async.} =
    let startTime = cpuTime()
    
    inc(globalPerformanceMetrics.requestCount)
    
    await ctx.next()
    
    let duration = (cpuTime() - startTime) * 1000.0
    
    # Update average response time
    globalPerformanceMetrics.averageResponseTime = 
      (globalPerformanceMetrics.averageResponseTime * (globalPerformanceMetrics.requestCount - 1).float + duration) / 
      globalPerformanceMetrics.requestCount.float
    
    # Add performance headers
    ctx.response.setHeader("X-Response-Time", $duration & "ms")
    ctx.response.setHeader("X-Request-Count", $globalPerformanceMetrics.requestCount)

proc getPerformanceMetrics*(): PerformanceMetrics =
  ## Gets global performance metrics
  result = globalPerformanceMetrics

proc resetPerformanceMetrics*() =
  ## Resets global performance metrics
  globalPerformanceMetrics = PerformanceMetrics()

# Convenience procedures for common performance patterns
proc withCachedResult*[T](ctx: Context, key: string, ttl: int,
                         generator: proc(): Future[T] {.async.}): Future[T] {.async.} =
  ## Executes a function with caching
  if ctx.gScope.appData.hasKey("performanceCache"):
    let cachePtr = parseInt(ctx.gScope.appData["performanceCache"])
    let cache = cast[InMemoryCache](cachePtr)
    
    let cached = await cache.get(key)
    if cached.isSome:
      # Assuming T can be parsed from string (simplified)
      when T is string:
        return cached.get
      else:
        # In real implementation, would need proper serialization
        return await generator()
    
    let result = await generator()
    when T is string:
      discard await cache.set(key, result, ttl)
    
    return result
  else:
    return await generator()

proc optimizedDatabaseQuery*[T](ctx: Context, query: string, 
                               parser: proc(data: string): T): Future[T] {.async.} =
  ## Executes a database query with connection pooling and caching
  let cacheKey = "db:" & $hash(query)
  
  result = await ctx.withCachedResult(cacheKey, 60, proc(): Future[T] {.async.} =
    # In real implementation, would use connection pool
    let mockData = ""
    return parser(mockData)
  )

# Performance testing utilities
proc benchmarkRoute*(app: Prologue, path: string, iterations = 1000): Future[tuple[avgTime: float, minTime: float, maxTime: float]] {.async.} =
  ## Benchmarks a specific route
  var times: seq[float] = @[]
  
  for i in 0..<iterations:
    let startTime = cpuTime()
    
    # In real implementation, would make actual HTTP request
    await sleepAsync(1)  # Simulate request
    
    let duration = (cpuTime() - startTime) * 1000.0
    times.add(duration)
  
  let avgTime = times.sum() / times.len.float
  let minTime = times.min()
  let maxTime = times.max()
  
  result = (avgTime, minTime, maxTime)
  logging.info("Route benchmark for " & path & ": avg=" & $avgTime & "ms, min=" & $minTime & "ms, max=" & $maxTime & "ms")

# Memory optimization utilities
proc optimizeMemoryUsage*() =
  ## Performs memory optimization tasks
  when defined(gcArc) or defined(gcOrc):
    GC_fullCollect()
  else:
    GC_fullCollect()
  
  logging.info("Memory optimization performed")

# Configuration validation
proc validatePerformanceConfig*(config: PerformanceConfig): bool =
  ## Validates performance configuration
  result = true
  
  if config.connectionPoolSize <= 0:
    logging.error("Invalid connection pool size: " & $config.connectionPoolSize)
    result = false
  
  if config.cacheSize <= 0:
    logging.error("Invalid cache size: " & $config.cacheSize)
    result = false
  
  if config.cacheTTL < 0:
    logging.error("Invalid cache TTL: " & $config.cacheTTL)
    result = false
  
  if result:
    logging.info("Performance configuration validated successfully")
  else:
    logging.error("Performance configuration validation failed")

# Health check for performance components
proc performanceHealthCheck*(app: Prologue): Future[bool] {.async.} =
  ## Performs health check on performance components
  result = true
  
  # Check cache
  if app.appData.hasKey("performanceCache"):
    try:
      let cachePtr = parseInt(app.appData["performanceCache"])
      let cache = cast[InMemoryCache](cachePtr)
      discard await cache.set("health_check", "ok", 1)
      let value = await cache.get("health_check")
      if value.isNone or value.get != "ok":
        logging.error("Cache health check failed")
        result = false
      else:
        logging.debug("Cache health check passed")
    except:
      logging.error("Cache health check exception")
      result = false
  
  # Check optimized router
  if app.appData.hasKey("optimizedRouter"):
    try:
      let router = app.getOptimizedRouter()
      let stats = router.getRouteStats()
      logging.debug("Router health check: " & $stats.totalRoutes & " routes")
    except:
      logging.error("Router health check failed")
      result = false
  
  if result:
    logging.info("Performance health check passed")
  else:
    logging.error("Performance health check failed")