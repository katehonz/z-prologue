# HTTP/1.1 Keep-Alive Optimizations Example for Prologue
# 
# This example demonstrates how to use the advanced Keep-Alive optimizations
# including connection pooling, persistent connections management, and timeout optimizations.

import std/[asyncdispatch, times, logging, strformat, json]
import ../../src/prologue
import ../../src/prologue/core/httpcore/optimizations

# Configure logging
addHandler(newConsoleLogger())
setLogFilter(lvlDebug)

proc healthCheck(ctx: Context) {.async.} =
  ## Health check endpoint that shows optimization status
  let optimizer = getGlobalHttpOptimizer()
  let status = getOptimizerStatus(optimizer)
  
  resp status, Http200, {"Content-Type": "application/json"}

proc apiEndpoint(ctx: Context) {.async.} =
  ## Sample API endpoint that benefits from Keep-Alive optimizations
  let startTime = getTime()
  
  # Simulate some processing time
  await sleepAsync(50)
  
  let responseTime = (getTime() - startTime).inMilliseconds.float
  let clientId = ctx.request.hostName()
  
  # Record metrics for optimization
  recordRequestMetrics(clientId, responseTime, true, true)
  
  let response = %*{
    "message": "Hello from optimized Prologue!",
    "responseTime": responseTime,
    "clientId": clientId,
    "timestamp": $getTime()
  }
  
  resp $response, Http200, {"Content-Type": "application/json"}

proc stressTest(ctx: Context) {.async.} =
  ## Endpoint for stress testing Keep-Alive optimizations
  let iterations = ctx.getQueryParams("iterations", "10").parseInt()
  let delay = ctx.getQueryParams("delay", "10").parseInt()
  
  let startTime = getTime()
  
  for i in 1..iterations:
    await sleepAsync(delay)
  
  let totalTime = (getTime() - startTime).inMilliseconds.float
  let clientId = ctx.request.hostName()
  
  recordRequestMetrics(clientId, totalTime, true, true)
  
  let response = %*{
    "iterations": iterations,
    "delay": delay,
    "totalTime": totalTime,
    "avgTimePerIteration": totalTime / float(iterations)
  }
  
  resp $response, Http200, {"Content-Type": "application/json"}

proc connectionInfo(ctx: Context) {.async.} =
  ## Shows connection pool information
  let optimizer = getGlobalHttpOptimizer()
  
  var info = %*{
    "optimizer": {
      "enabled": optimizer.enabled,
      "level": $optimizer.level
    }
  }
  
  if optimizer.keepAliveManager != nil:
    let stats = getConnectionPoolStats()
    info["keepAlive"] = %*{
      "totalConnections": stats.totalConnections,
      "activeConnections": stats.activeConnections,
      "idleConnections": stats.idleConnections,
      "poolHitRate": stats.poolHitRate,
      "avgConnectionAge": stats.avgConnectionAge
    }
  
  if optimizer.connectionPool != nil:
    let poolStats = getPoolStatistics(optimizer.connectionPool)
    info["connectionPool"] = %*{
      "totalConnections": poolStats.totalConnections,
      "activeConnections": poolStats.activeConnections,
      "groupCount": poolStats.groupCount,
      "avgResponseTime": poolStats.avgResponseTime,
      "utilizationRate": poolStats.utilizationRate
    }
  
  resp $info, Http200, {"Content-Type": "application/json"}

proc optimizationMetrics(ctx: Context) {.async.} =
  ## Shows detailed optimization metrics
  let optimizer = getGlobalHttpOptimizer()
  updateMetrics(optimizer)
  
  let profile = analyzePerformance(optimizer)
  let recommendations = generateRecommendations(optimizer, profile)
  
  let metrics = %*{
    "performance": {
      "avgResponseTime": profile.avgResponseTime,
      "p95ResponseTime": profile.p95ResponseTime,
      "p99ResponseTime": profile.p99ResponseTime,
      "errorRate": profile.errorRate,
      "connectionUtilization": profile.connectionUtilization
    },
    "recommendations": []
  }
  
  for rec in recommendations:
    metrics["recommendations"].add(%*{
      "component": rec.component,
      "parameter": rec.parameter,
      "currentValue": rec.currentValue,
      "recommendedValue": rec.recommendedValue,
      "expectedImprovement": rec.expectedImprovement,
      "confidence": rec.confidence
    })
  
  resp $metrics, Http200, {"Content-Type": "application/json"}

proc configureOptimizations(level: OptimizationLevel) =
  ## Configures HTTP optimizations based on level
  echo fmt"Configuring HTTP optimizations with level: {level}"
  
  case level:
  of olConservative:
    echo "Using conservative optimizations - safe for production"
  of olBalanced:
    echo "Using balanced optimizations - recommended for most applications"
  of olAggressive:
    echo "Using aggressive optimizations - maximum performance"
  of olCustom:
    echo "Using custom optimizations"
  
  # Initialize global optimizer with specified level
  initGlobalHttpOptimizer(level)
  
  echo "HTTP optimizations configured successfully!"

proc main() =
  echo "Starting Prologue with HTTP/1.1 Keep-Alive Optimizations"
  echo "========================================================="
  
  # Configure optimizations (can be changed via command line argument)
  let optimizationLevel = olBalanced  # Change this to test different levels
  configureOptimizations(optimizationLevel)
  
  # Create Prologue app
  let settings = newSettings(
    appName = "Keep-Alive Optimizations Demo",
    debug = true,
    port = Port(8080),
    address = "0.0.0.0"
  )
  
  var app = newApp(settings = settings)
  
  # Add routes
  app.get("/", proc(ctx: Context) {.async.} =
    let html = """
<!DOCTYPE html>
<html>
<head>
    <title>Prologue Keep-Alive Optimizations Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .endpoint { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .method { color: #007bff; font-weight: bold; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>Prologue Keep-Alive Optimizations Demo</h1>
    <p>This demo showcases HTTP/1.1 Keep-Alive optimizations including connection pooling, 
       persistent connections management, and adaptive timeout optimizations.</p>
    
    <h2>Available Endpoints:</h2>
    
    <div class="endpoint">
        <div class="method">GET /health</div>
        <p>Shows the current status of HTTP optimizations</p>
    </div>
    
    <div class="endpoint">
        <div class="method">GET /api</div>
        <p>Sample API endpoint that demonstrates Keep-Alive benefits</p>
    </div>
    
    <div class="endpoint">
        <div class="method">GET /stress?iterations=N&delay=M</div>
        <p>Stress test endpoint for testing optimization performance</p>
    </div>
    
    <div class="endpoint">
        <div class="method">GET /connections</div>
        <p>Shows connection pool information and statistics</p>
    </div>
    
    <div class="endpoint">
        <div class="method">GET /metrics</div>
        <p>Shows detailed optimization metrics and recommendations</p>
    </div>
    
    <h2>Testing Keep-Alive:</h2>
    <p>To test Keep-Alive optimizations, use curl with multiple requests:</p>
    <pre>
# Test with Keep-Alive (HTTP/1.1 default)
curl -v http://localhost:8080/api
curl -v http://localhost:8080/api

# Test without Keep-Alive
curl -v -H "Connection: close" http://localhost:8080/api

# Stress test
curl "http://localhost:8080/stress?iterations=100&delay=5"

# Check metrics
curl http://localhost:8080/metrics | jq
    </pre>
    
    <h2>Optimization Level:</h2>
    <p>Current optimization level: <strong>""" & $optimizationLevel & """</strong></p>
    <p>Available levels: Conservative, Balanced, Aggressive, Custom</p>
</body>
</html>
    """
    resp html, Http200, {"Content-Type": "text/html"}
  )
  
  app.get("/health", healthCheck)
  app.get("/api", apiEndpoint)
  app.get("/stress", stressTest)
  app.get("/connections", connectionInfo)
  app.get("/metrics", optimizationMetrics)
  
  echo fmt"Server starting on http://localhost:8080"
  echo "Visit http://localhost:8080 for documentation and testing endpoints"
  echo ""
  echo "Optimization Features Enabled:"
  let optimizer = getGlobalHttpOptimizer()
  echo fmt"  - Keep-Alive Manager: {optimizer.keepAliveManager != nil}"
  echo fmt"  - Connection Pooling: {optimizer.connectionPool != nil}"
  echo fmt"  - Adaptive Timeouts: {optimizer.timeoutManager != nil}"
  echo fmt"  - Auto-tuning: {optimizer.config.enableAutoTuning}"
  echo ""
  
  # Start the server
  app.run()

when isMainModule:
  main()