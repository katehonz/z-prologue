import ../src/prologue
import ../src/prologue/middlewares/[ratelimit, compression, securityheaders, health, 
                              requestid, loggingmiddleware, gracefulshutdown]
import ../src/prologue/logging/structured
import ../src/prologue/config/advanced
import std/[os, times, json]

proc configureApp(): Prologue =
  # Initialize logging
  initDefaultLogger(
    format = JSON,
    output = Stdout,
    minLevel = Info,
    asyncMode = false
  )
  
  # Create settings
  let settings = newSettings(
    appName = "Simple Production App",
    debug = false,
    port = Port(8080),
    secretKey = "change-me-in-production"
  )
  
  result = newApp(settings)
  
  # Add middlewares
  result.use(requestIDMiddleware())
  result.use(loggingMiddleware())
  result.use(rateLimitByIP(maxRequests = 100, windowSeconds = 60))
  result.use(compressionMiddleware())
  result.use(securityHeadersMiddleware())
  
  # Initialize graceful shutdown
  result.initGracefulShutdown(maxDrainTime = 10.0)
  
  # Add simple health checks
  addHealthCheck("app", proc(): Future[tuple[status: HealthStatus, message: string]] {.async.} =
    result = (Healthy, "Application is running")
  )
  
  # Register health endpoints
  result.registerHealthEndpoints()

proc hello(ctx: Context) {.async.} =
  resp jsonResponse(%*{
    "message": "Hello from production-ready Prologue!",
    "request_id": if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: "",
    "timestamp": now().format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz")
  })

proc apiData(ctx: Context) {.async.} =
  # Simulate some processing
  await sleepAsync(100)
  
  resp jsonResponse(%*{
    "data": [1, 2, 3, 4, 5],
    "processed": true,
    "request_id": if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: ""
  })

when isMainModule:
  let app = configureApp()
  
  # Routes
  app.get("/", hello)
  app.get("/api/data", apiData)
  
  # Error handlers
  app.registerErrorHandler(Http404, proc(ctx: Context) {.async.} =
    resp jsonResponse(%*{
      "error": "Not Found",
      "path": ctx.request.path,
      "request_id": if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: ""
    }, Http404)
  )
  
  app.registerErrorHandler({Http500..Http599}, proc(ctx: Context) {.async.} =
    resp jsonResponse(%*{
      "error": "Internal Server Error",
      "request_id": if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: ""
    }, Http500)
  )
  
  info("Starting server on port 8080")
  app.run()