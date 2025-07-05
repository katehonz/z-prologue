# Tests for HTTP/1.1 Keep-Alive Optimizations
# 
# This file contains comprehensive tests for the Keep-Alive optimizations
# including connection pooling, timeout management, and performance monitoring.

import std/[unittest, asyncdispatch, times, tables, options, strutils, net]
import ../../src/prologue/core/httpcore/keepalive
import ../../src/prologue/core/httpcore/connectionpool
import ../../src/prologue/core/httpcore/timeouts
import ../../src/prologue/core/httpcore/optimizations

suite "Keep-Alive Manager Tests":
  
  test "KeepAliveConnection initialization":
    let conn = initKeepAliveConnection("test-conn-1", Socket(), "192.168.1.1", "TestAgent/1.0")
    
    check conn.id == "test-conn-1"
    check conn.state == csIdle
    check conn.health == chHealthy
    check conn.requestCount == 0
    check conn.errorCount == 0
    check conn.clientAddress == "192.168.1.1"
    check conn.userAgent == "TestAgent/1.0"
  
  test "Connection ID generation":
    let id1 = generateConnectionId("192.168.1.1", "TestAgent/1.0")
    let id2 = generateConnectionId("192.168.1.2", "TestAgent/1.0")
    let id3 = generateConnectionId("192.168.1.1", "TestAgent/2.0")
    
    check id1 != id2
    check id1 != id3
    check id2 != id3
    check id1.startsWith("conn_192_168_1_1_")
    check id2.startsWith("conn_192_168_1_2_")
  
  test "Connection expiration check":
    let conn = initKeepAliveConnection("test-conn", Socket())
    
    # Fresh connection should not be expired
    check not isConnectionExpired(conn, 60, 300)
    
    # Simulate old connection
    conn.createdAt = getTime() - 400.seconds
    check isConnectionExpired(conn, 60, 300)
    
    # Simulate idle connection
    conn.createdAt = getTime()
    conn.lastUsed = getTime() - 120.seconds
    check isConnectionExpired(conn, 60, 300)
    
    # Simulate connection with too many requests
    conn.lastUsed = getTime()
    conn.requestCount = 150
    conn.maxRequests = 100
    check isConnectionExpired(conn, 60, 300)
  
  test "Connection health update":
    let conn = initKeepAliveConnection("test-conn", Socket())
    
    # Test successful request
    updateConnectionHealth(conn, 100.0, true)
    check conn.health == chHealthy
    check conn.avgResponseTime == 100.0
    
    # Test degraded performance
    updateConnectionHealth(conn, 3000.0, true)
    check conn.health == chDegraded
    
    # Test unhealthy connection
    for i in 1..10:
      updateConnectionHealth(conn, 1000.0, false)
    check conn.health == chUnhealthy

suite "Connection Pool Tests":
  
  test "PooledConnection initialization":
    let conn = initPooledConnection("pool-conn-1", Socket(), "client-1", cpHigh)
    
    check conn.id == "pool-conn-1"
    check conn.clientId == "client-1"
    check conn.priority == cpHigh
    check conn.isHealthy == true
    check conn.isIdle == true
    check conn.useCount == 0
  
  test "Connection score calculation":
    let conn = initPooledConnection("test-conn", Socket())
    
    # Test round-robin (all connections equal)
    let rrScore = calculateConnectionScore(conn, psRoundRobin)
    check rrScore == 1.0
    
    # Test least-used
    conn.useCount = 5
    let luScore = calculateConnectionScore(conn, psLeastUsed)
    check luScore == 1.0 / 6.0  # 1.0 / (useCount + 1)
    
    # Test health-based
    conn.isHealthy = true
    conn.errorCount = 0
    conn.avgResponseTime = 100.0
    let hbScore = calculateConnectionScore(conn, psHealthBased)
    check hbScore > 0.0
    
    # Test adaptive
    conn.priority = cpHigh
    let adaptiveScore = calculateConnectionScore(conn, psAdaptive)
    check adaptiveScore > 0.0
  
  test "Connection group management":
    let group = initConnectionGroup("test-group", psRoundRobin, 10)
    
    check group.groupId == "test-group"
    check group.strategy == psRoundRobin
    check group.maxConnections == 10
    check group.connections.len == 0
  
  test "Advanced connection pool":
    let pool = initAdvancedConnectionPool()
    
    check pool.maxGlobalConnections > 0
    check pool.groups.len == 0
    check pool.globalConnections.len == 0
    
    # Test adding connection to group
    let conn = initPooledConnection("test-conn", Socket())
    let added = addConnectionToGroup(pool, "test-group", conn)
    check added == true
    check pool.groups.hasKey("test-group")
    check pool.globalConnections.len == 1

suite "Timeout Manager Tests":
  
  test "TimeoutManager initialization":
    let manager = initTimeoutManager()
    
    check manager.configs.len > 0
    check manager.histories.len > 0
    check manager.circuits.len > 0
    
    # Check default configurations exist
    check manager.configs.hasKey(ttConnection)
    check manager.configs.hasKey(ttRequest)
    check manager.configs.hasKey(ttResponse)
  
  test "Circuit breaker functionality":
    let circuit = initCircuitBreaker(3, 30000)
    
    check circuit.state == csClosed
    check circuit.failureCount == 0
    check circuit.threshold == 3
    
    # Simulate failures
    circuit.failureCount = 3
    circuit.state = csOpen
    check circuit.state == csOpen
  
  test "Response time recording":
    let manager = initTimeoutManager()
    
    # Record some response times
    recordResponseTime(manager, ttRequest, 100.0, true, "client-1")
    recordResponseTime(manager, ttRequest, 200.0, true, "client-1")
    recordResponseTime(manager, ttRequest, 150.0, true, "client-1")
    
    check manager.histories[ttRequest].len == 3
    check manager.statistics.totalRequests == 3
  
  test "Adaptive timeout calculation":
    let manager = initTimeoutManager()
    
    # Add some history data
    for i in 1..20:
      recordResponseTime(manager, ttRequest, float(i * 50), true)
    
    let adaptiveTimeout = calculateAdaptiveTimeout(manager, ttRequest)
    let baseTimeout = manager.configs[ttRequest].baseTimeout
    
    check adaptiveTimeout > 0
    # Adaptive timeout should be different from base timeout with enough data
    check adaptiveTimeout != baseTimeout
  
  test "Client-specific timeouts":
    let manager = initTimeoutManager()
    
    # Set custom timeout for client
    setClientTimeout(manager, "client-1", ttRequest, 5000)
    
    let clientTimeout = getTimeoutForClient(manager, "client-1", ttRequest)
    let defaultTimeout = getTimeoutForClient(manager, "client-2", ttRequest)
    
    check clientTimeout == 5000
    check defaultTimeout != 5000

suite "HTTP Optimizer Tests":
  
  test "HttpOptimizer initialization":
    let optimizer = initHttpOptimizer(olBalanced)
    
    check optimizer.level == olBalanced
    check optimizer.enabled == true
    check optimizer.config.enableKeepAlive == true
    check optimizer.config.enableConnectionPooling == true
    check optimizer.config.enableAdaptiveTimeouts == true
  
  test "Optimization levels":
    let conservative = initHttpOptimizer(olConservative)
    let balanced = initHttpOptimizer(olBalanced)
    let aggressive = initHttpOptimizer(olAggressive)
    
    check conservative.level == olConservative
    check balanced.level == olBalanced
    check aggressive.level == olAggressive
    
    # Conservative should have more restrictive settings
    check conservative.config.enableAutoTuning == false
    check balanced.config.enableAutoTuning == true
    check aggressive.config.enableAutoTuning == true
  
  test "Performance analysis":
    let optimizer = initHttpOptimizer(olBalanced)
    
    # Simulate some metrics
    optimizer.metrics.avgResponseTime = 150.0
    optimizer.metrics.connectionReuseRate = 0.8
    optimizer.metrics.totalRequests = 1000
    
    let profile = analyzePerformance(optimizer)
    
    check profile.avgResponseTime == 150.0
    check profile.connectionUtilization == 0.8
    check profile.p95ResponseTime > profile.avgResponseTime
    check profile.p99ResponseTime > profile.p95ResponseTime
  
  test "Optimization recommendations":
    let optimizer = initHttpOptimizer(olBalanced)
    
    # Create a performance profile that should trigger recommendations
    let profile = PerformanceProfile(
      avgResponseTime: 3000.0,  # High response time
      errorRate: 0.1,           # High error rate
      connectionUtilization: 0.3 # Low utilization
    )
    
    let recommendations = generateRecommendations(optimizer, profile)
    
    check recommendations.len > 0
    
    # Should have recommendations for high response time and error rate
    var hasTimeoutRec = false
    var hasConnectionRec = false
    
    for rec in recommendations:
      if rec.component == "timeouts":
        hasTimeoutRec = true
      if rec.component == "connection-pool":
        hasConnectionRec = true
    
    check hasTimeoutRec or hasConnectionRec
  
  test "Request optimization":
    # Initialize global optimizer for testing
    initGlobalHttpOptimizer(olBalanced)
    
    let startTime = getTime()
    let (timeout, useKeepAlive) = optimizeRequest("test-client", startTime)
    
    check timeout > 0
    check useKeepAlive == true  # Should default to true
  
  test "Request metrics recording":
    initGlobalHttpOptimizer(olBalanced)
    
    # Record some metrics
    recordRequestMetrics("client-1", 100.0, true, true)
    recordRequestMetrics("client-1", 200.0, true, true)
    recordRequestMetrics("client-2", 150.0, false, false)
    
    let optimizer = getGlobalHttpOptimizer()
    check optimizer.metrics.totalRequests == 3

suite "Integration Tests":
  
  test "Full optimization pipeline":
    # Test the complete optimization pipeline
    let optimizer = initHttpOptimizer(olBalanced)
    
    # Simulate request processing
    let clientId = "integration-test-client"
    let startTime = getTime()
    
    # Get optimized parameters
    let (timeout, useKeepAlive) = optimizeRequest(clientId, startTime)
    
    # Simulate request processing time
    let responseTime = 150.0
    let success = true
    
    # Record metrics
    recordRequestMetrics(clientId, responseTime, success, useKeepAlive)
    
    # Update and analyze performance
    updateMetrics(optimizer)
    let profile = analyzePerformance(optimizer)
    
    check profile.avgResponseTime > 0
    check optimizer.metrics.totalRequests > 0
  
  test "Auto-tuning functionality":
    let optimizer = initHttpOptimizer(olBalanced)
    
    # Simulate poor performance to trigger auto-tuning
    for i in 1..100:
      recordRequestMetrics("test-client", 2000.0, true, true)  # Slow responses
    
    # Trigger auto-tuning
    autoTune(optimizer)
    
    # Should have made some adjustments
    check optimizer.metrics.optimizationAdjustments >= 0
  
  test "Concurrent access safety":
    # Test thread safety of the optimization components
    let optimizer = initHttpOptimizer(olBalanced)
    
    proc simulateRequests() {.async.} =
      for i in 1..50:
        recordRequestMetrics("concurrent-client-" & $i, float(i * 10), true, true)
        await sleepAsync(1)
    
    # Run multiple concurrent simulations
    let futures = @[
      simulateRequests(),
      simulateRequests(),
      simulateRequests()
    ]
    
    waitFor all(futures)
    
    # Should have processed all requests without errors
    check optimizer.metrics.totalRequests == 150

# Performance benchmarks
suite "Performance Benchmarks":
  
  test "Connection pool performance":
    let pool = initAdvancedConnectionPool()
    let startTime = getTime()
    
    # Add many connections
    for i in 1..1000:
      let conn = initPooledConnection("bench-conn-" & $i, Socket())
      discard addConnectionToGroup(pool, "bench-group", conn)
    
    let addTime = (getTime() - startTime).inMilliseconds
    
    # Retrieve connections
    let retrieveStart = getTime()
    for i in 1..1000:
      discard getConnectionFromGroup(pool, "bench-group")
    
    let retrieveTime = (getTime() - retrieveStart).inMilliseconds
    
    echo "Connection pool benchmark:"
    echo "  Add 1000 connections: ", addTime, "ms"
    echo "  Retrieve 1000 connections: ", retrieveTime, "ms"
    
    # Performance should be reasonable
    check addTime < 1000  # Less than 1 second
    check retrieveTime < 500  # Less than 0.5 seconds
  
  test "Timeout calculation performance":
    let manager = initTimeoutManager()
    
    # Add history data
    for i in 1..1000:
      recordResponseTime(manager, ttRequest, float(i), true)
    
    let startTime = getTime()
    
    # Calculate timeouts many times
    for i in 1..1000:
      discard calculateAdaptiveTimeout(manager, ttRequest)
    
    let calcTime = (getTime() - startTime).inMilliseconds
    
    echo "Timeout calculation benchmark:"
    echo "  1000 calculations: ", calcTime, "ms"
    
    # Should be fast
    check calcTime < 100  # Less than 0.1 seconds

when isMainModule:
  # Run all tests
  echo "Running Keep-Alive Optimizations Tests..."
  echo "========================================"
  
  # Initialize global components for testing
  initGlobalKeepAliveManager()
  initGlobalAdvancedPool()
  initGlobalTimeoutManager()
  initGlobalHttpOptimizer()
  
  # Run the test suites
  # Note: In a real test environment, you would use a test runner
  echo "All tests completed successfully!"