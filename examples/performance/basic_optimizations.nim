# Basic Performance Optimizations Example for Prologue
# 
# This example demonstrates how to use the basic performance optimizations
# including caching, connection pooling, and optimized routing.

import std/[asyncdispatch, logging, json, strutils]
import ../../src/prologue
import ../../src/prologue/performance

# Configure logging
addHandler(newConsoleLogger())
setLogFilter(lvlInfo)

# Sample data for demonstration
var sampleUsers = @[
  %*{"id": 1, "name": "Alice", "email": "alice@example.com"},
  %*{"id": 2, "name": "Bob", "email": "bob@example.com"},
  %*{"id": 3, "name": "Charlie", "email": "charlie@example.com"}
]

proc getUserById(ctx: Context) {.async, gcsafe.} =
  ## Handler that demonstrates caching optimization
  let userId = ctx.getPathParams("id", "0")
  let cacheKey = "user:" & userId
  
  # Simulate expensive database operation
  await sleepAsync(100)  # 100ms delay
  
  let id = parseInt(userId)
  for user in sampleUsers:
    if user["id"].getInt() == id:
      ctx.response.setHeader("Content-Type", "application/json")
      resp $user
      return
  
  ctx.response.setHeader("Content-Type", "application/json")
  resp "{\"error\": \"User not found\"}"

proc getAllUsers(ctx: Context) {.async, gcsafe.} =
  ## Handler that demonstrates lazy loading
  # Simulate expensive operation to load all users
  await sleepAsync(200)
  let usersData = $(%sampleUsers)
  
  ctx.response.setHeader("Content-Type", "application/json")
  resp usersData

proc createUser(ctx: Context) {.async, gcsafe.} =
  ## Handler that demonstrates database operations with connection pooling
  try:
    let body = ctx.request.body
    let userData = parseJson(body)
    
    # In real application, would use connection pool here
    # await ctx.withConnection(proc(conn: DbConn) {.async.} =
    #   await conn.exec("INSERT INTO users ...", userData)
    # )
    
    # For demo, just add to our sample data
    let newId = sampleUsers.len + 1
    userData["id"] = %newId
    sampleUsers.add(userData)
    
    ctx.response.setHeader("Content-Type", "application/json")
    resp $userData
    
  except JsonParsingError:
    ctx.response.code = Http400
    resp "{\"error\": \"Invalid JSON\"}"

proc getStats(ctx: Context) {.async, gcsafe.} =
  ## Handler that shows performance metrics
  let metrics = getPerformanceMetrics()
  let stats = %*{
    "requestCount": metrics.requestCount,
    "averageResponseTime": metrics.averageResponseTime,
    "cacheHitRate": metrics.cacheHitRate
  }
  
  ctx.response.setHeader("Content-Type", "application/json")
  resp $stats

proc healthCheck(ctx: Context) {.async, gcsafe.} =
  ## Health check endpoint
  let isHealthy = await performanceHealthCheck(ctx.gScope.app)
  
  if isHealthy:
    resp "{\"status\": \"healthy\"}"
  else:
    ctx.response.code = Http503
    resp "{\"status\": \"unhealthy\"}"

proc main() {.async.} =
  # Create application with performance optimizations
  let settings = newSettings(
    appName = "Performance Demo",
    debug = true,
    port = Port(8080)
  )
  
  var app = newApp(settings)
  
  # Initialize performance optimizations
  let perfConfig = PerformanceConfig(
    enableConnectionPool: true,
    connectionPoolSize: 5,
    enableCaching: true,
    cacheSize: 100,
    cacheTTL: 300,
    enableLazyLoading: true,
    enableOptimizedRouting: true,
    enableMetrics: true
  )
  
  if not validatePerformanceConfig(perfConfig):
    echo "Invalid performance configuration!"
    return
  
  app.initPerformanceOptimizations(perfConfig)
  
  # Add routes
  app.get("/users/{id}", getUserById)
  app.get("/users", getAllUsers)
  app.post("/users", createUser)
  app.get("/stats", getStats)
  app.get("/health", healthCheck)
  
  # Add a simple home page
  app.get("/", proc(ctx: Context) {.async, gcsafe.} =
    resp """
    <h1>Prologue Performance Demo</h1>
    <p>Available endpoints:</p>
    <ul>
      <li><a href="/users">GET /users</a> - Get all users (lazy loading demo)</li>
      <li><a href="/users/1">GET /users/1</a> - Get user by ID (caching demo)</li>
      <li>POST /users - Create new user (connection pooling demo)</li>
      <li><a href="/stats">GET /stats</a> - Performance statistics</li>
      <li><a href="/health">GET /health</a> - Health check</li>
    </ul>
    """
  )
  
  echo "Starting Prologue with performance optimizations..."
  echo "Visit http://localhost:8080 to see the demo"
  
  app.run()

when isMainModule:
  waitFor main()