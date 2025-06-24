# Performance Optimizations Tests for Prologue
# 
# This file contains comprehensive tests for all performance optimization features
# including connection pooling, caching, lazy loading, and optimized routing.

import std/[unittest, asyncdispatch, times, tables, strutils, json]
import ../../src/prologue
import ../../src/prologue/performance

suite "Connection Pool Tests":
  test "Connection pool creation":
    let pool = newConnectionPool("test://localhost", maxConnections = 5, minConnections = 2)
    check pool.maxConnections == 5
    check pool.minConnections == 2
    check pool.availableConnections == 2
    check pool.connections.len == 2

  test "Connection acquisition and release":
    proc testConnectionFlow() {.async.} =
      let pool = newConnectionPool("test://localhost", maxConnections = 3, minConnections = 1)
      
      # Get a connection
      let conn1 = await pool.getConnection()
      check conn1 != nil
      check conn1.inUse == true
      check pool.availableConnections == 0
      
      # Release the connection
      await pool.releaseConnection(conn1)
      check conn1.inUse == false
      check pool.availableConnections == 1
    
    waitFor testConnectionFlow()

  test "Connection pool statistics":
    let pool = newConnectionPool("test://localhost", maxConnections = 5, minConnections = 2)
    let stats = pool.getStats()
    check stats.total == 2
    check stats.available == 2
    check stats.inUse == 0

suite "Cache Tests":
  test "In-memory cache basic operations":
    proc testInMemoryCache() {.async.} =
      let cache = newInMemoryCache(maxSize = 10)
      
      # Test set and get
      let setResult = await cache.set("key1", "value1", 60)
      check setResult == true
      
      let getValue = await cache.get("key1")
      check getValue.isSome
      check getValue.get == "value1"
      
      # Test non-existent key
      let noValue = await cache.get("nonexistent")
      check noValue.isNone
    
    waitFor testInMemoryCache()

  test "Cache expiration":
    proc testCacheExpiration() {.async.} =
      let cache = newInMemoryCache(maxSize = 10)
      
      # Set with 1 second TTL
      discard await cache.set("expiring_key", "expiring_value", 1)
      
      # Should be available immediately
      let value1 = await cache.get("expiring_key")
      check value1.isSome
      check value1.get == "expiring_value"
      
      # Wait for expiration
      await sleepAsync(1100)  # 1.1 seconds
      
      # Should be expired now
      let value2 = await cache.get("expiring_key")
      check value2.isNone
    
    waitFor testCacheExpiration()

  test "Multi-level cache":
    proc testMultiLevelCache() {.async.} =
      let memCache = newInMemoryCache(maxSize = 5)
      let redisCache = newRedisCache("redis://localhost:6379")
      let multiCache = newMultiLevelCache(memCache, redisCache)
      
      # Set in multi-level cache
      let setResult = await multiCache.set("multi_key", "multi_value", 60)
      check setResult == true
      
      # Get should work
      let getValue = await multiCache.get("multi_key")
      check getValue.isSome
      check getValue.get == "multi_value"
    
    waitFor testMultiLevelCache()

suite "Lazy Loading Tests":
  test "Basic lazy resource":
    proc testLazyResource() {.async.} =
      var loadCount = 0
      
      let lazyRes = newLazyResource(proc(): Future[string] {.async.} =
        inc(loadCount)
        await sleepAsync(10)  # Simulate loading time
        return "loaded_value"
      )
      
      # Should not be loaded initially
      check not lazyRes.isLoaded()
      check loadCount == 0
      
      # First access should load
      let value1 = await lazyRes.get()
      check value1 == "loaded_value"
      check lazyRes.isLoaded()
      check loadCount == 1
      
      # Second access should use cached value
      let value2 = await lazyRes.get()
      check value2 == "loaded_value"
      check loadCount == 1  # Should not increment
    
    waitFor testLazyResource()

  test "Lazy resource statistics":
    proc testLazyStats() {.async.} =
      let lazyRes = newLazyResource(proc(): Future[int] {.async.} =
        await sleepAsync(50)
        return 42
      )
      
      # Get initial stats
      let stats1 = lazyRes.getStats()
      check stats1.loaded == false
      check stats1.accessCount == 0
      
      # Load the resource
      let value = await lazyRes.get()
      check value == 42
      
      # Check stats after loading
      let stats2 = lazyRes.getStats()
      check stats2.loaded == true
      check stats2.accessCount == 1
      check stats2.loadTime > 0
    
    waitFor testLazyStats()

suite "Optimized Routing Tests":
  test "Trie router creation":
    let router = newTrieRouter()
    check router.totalRoutes == 0
    check router.maxDepth == 0

  test "Static route matching":
    let router = newTrieRouter()
    
    proc testHandler(ctx: Context) {.async.} =
      resp "test"
    
    router.addRoute("/users", testHandler, HttpGet)
    router.addRoute("/posts", testHandler, HttpPost)
    
    let match1 = router.findRoute("/users", HttpGet)
    check match1.matched == true
    check match1.params.len == 0
    
    let match2 = router.findRoute("/posts", HttpPost)
    check match2.matched == true
    
    let match3 = router.findRoute("/nonexistent", HttpGet)
    check match3.matched == false

  test "Parameter route matching":
    let router = newTrieRouter()
    
    proc testHandler(ctx: Context) {.async.} =
      resp "test"
    
    router.addRoute("/users/{id}", testHandler, HttpGet)
    router.addRoute("/posts/{id}/comments/{commentId}", testHandler, HttpGet)
    
    let match1 = router.findRoute("/users/123", HttpGet)
    check match1.matched == true
    check match1.params.hasKey("id")
    check match1.params["id"] == "123"
    
    let match2 = router.findRoute("/posts/456/comments/789", HttpGet)
    check match2.matched == true
    check match2.params.hasKey("id")
    check match2.params.hasKey("commentId")
    check match2.params["id"] == "456"
    check match2.params["commentId"] == "789"

  test "Wildcard route matching":
    let router = newTrieRouter()
    
    proc testHandler(ctx: Context) {.async.} =
      resp "test"
    
    router.addRoute("/static/*", testHandler, HttpGet)
    
    let match1 = router.findRoute("/static/css/style.css", HttpGet)
    check match1.matched == true
    
    let match2 = router.findRoute("/static/js/app.js", HttpGet)
    check match2.matched == true

  test "Router statistics":
    let router = newTrieRouter()
    
    proc testHandler(ctx: Context) {.async.} =
      resp "test"
    
    router.addRoute("/", testHandler, HttpGet)
    router.addRoute("/users", testHandler, HttpGet)
    router.addRoute("/users/{id}", testHandler, HttpGet)
    router.addRoute("/posts", testHandler, HttpPost)
    
    let stats = router.getRouteStats()
    check stats.totalRoutes == 4
    check stats.maxDepth > 0
    check stats.methodCounts.hasKey(HttpGet)
    check stats.methodCounts.hasKey(HttpPost)

suite "Performance Integration Tests":
  test "Performance configuration validation":
    let validConfig = PerformanceConfig(
      enableConnectionPool: true,
      connectionPoolSize: 10,
      enableCaching: true,
      cacheSize: 100,
      cacheTTL: 300,
      enableLazyLoading: true,
      enableOptimizedRouting: true,
      enableMetrics: true
    )
    
    check validatePerformanceConfig(validConfig) == true
    
    let invalidConfig = PerformanceConfig(
      connectionPoolSize: -1,  # Invalid
      cacheSize: 0,           # Invalid
      cacheTTL: -10           # Invalid
    )
    
    check validatePerformanceConfig(invalidConfig) == false

  test "Performance metrics":
    resetPerformanceMetrics()
    
    let initialMetrics = getPerformanceMetrics()
    check initialMetrics.requestCount == 0
    check initialMetrics.averageResponseTime == 0.0

  test "Cache key generation":
    let key1 = generateCacheKey("user", "123", "profile")
    check key1 == "user:123:profile"
    
    let key2 = generateCacheKey("post", "456")
    check key2 == "post:456"

suite "Performance Benchmarks":
  test "Route matching performance":
    proc benchmarkRouting() {.async.} =
      let router = newTrieRouter()
      
      proc dummyHandler(ctx: Context) {.async.} =
        resp "ok"
      
      # Add many routes
      for i in 1..100:  # Reduced for faster testing
        router.addRoute("/api/v1/users/" & $i, dummyHandler, HttpGet)
        router.addRoute("/api/v1/posts/" & $i, dummyHandler, HttpGet)
      
      # Benchmark route matching
      let startTime = cpuTime()
      for i in 1..100:
        let match = router.findRoute("/api/v1/users/" & $i, HttpGet)
        check match.matched == true
      
      let duration = (cpuTime() - startTime) * 1000.0
      echo "Route matching benchmark: ", duration, "ms for 100 lookups"
      
      # Should be reasonably fast
      check duration < 50.0
    
    waitFor benchmarkRouting()

  test "Cache performance":
    proc benchmarkCache() {.async.} =
      let cache = newInMemoryCache(maxSize = 100)
      
      # Benchmark cache operations
      let startTime = cpuTime()
      
      # Set 100 items
      for i in 1..100:
        discard await cache.set("key" & $i, "value" & $i, 300)
      
      # Get 100 items
      for i in 1..100:
        let value = await cache.get("key" & $i)
        check value.isSome
      
      let duration = (cpuTime() - startTime) * 1000.0
      echo "Cache benchmark: ", duration, "ms for 200 operations"
      
      # Should be very fast
      check duration < 100.0
    
    waitFor benchmarkCache()

when isMainModule:
  # Run all tests
  echo "Running Performance Optimization Tests..."
  
  # Initialize test environment
  addHandler(newConsoleLogger())
  setLogFilter(lvlError)  # Reduce log noise during tests
  
  # Run the test suites
  runTests()
  
  echo "All performance tests completed!"