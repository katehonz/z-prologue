import prologue
import prologue/middlewares/[ratelimit, compression, securityheaders, health, 
                              requestid, loggingmiddleware, gracefulshutdown]
import prologue/logging/structured
import prologue/config/advanced

proc configureApp(): Prologue =
  let config = newAdvancedConfig()
  config.load()
  
  initDefaultLogger(
    format = if config.getString("log_format", "json") == "json": JSON else: Pretty,
    output = if config.getString("log_output", "stdout") == "stdout": Stdout else: File,
    minLevel = case config.getString("log_level", "info")
      of "debug": Debug
      of "warn": Warn
      of "error": Error
      else: Info,
    filepath = config.getString("log_file", "app.log"),
    asyncMode = config.getBool("log_async", true)
  )
  
  let settings = newSettings(
    appName = config.getString("app_name", "Production App"),
    debug = config.getBool("debug", false),
    port = Port(config.getInt("port", 8080)),
    secretKey = config.getString("secret_key", "change-me-in-production"),
    bufSize = config.getInt("buffer_size", 40960),
    reusePort = config.getBool("reuse_port", true)
  )
  
  result = newApp(settings)
  
  result.use(requestIDMiddleware())
  
  result.use(loggingMiddleware(
    skipPaths = config.getSeq("log_skip_paths"),
    includeHeaders = @["X-Real-IP", "X-Forwarded-For", "User-Agent"]
  ))
  
  let rateLimiter = newRateLimiter(
    maxRequests = config.getInt("rate_limit_max", 100),
    windowSeconds = config.getFloat("rate_limit_window", 60.0),
    strategy = case config.getString("rate_limit_strategy", "fixed")
      of "sliding": SlidingWindow
      of "token": TokenBucket
      else: FixedWindow
  )
  result.use(rateLimitMiddleware(rateLimiter))
  
  result.use(compressionMiddleware(
    minSize = config.getInt("compression_min_size", 1024),
    level = config.getInt("compression_level", 6)
  ))
  
  result.use(securityHeadersMiddleware(
    hsts = config.getBool("security_hsts", true),
    contentSecurityPolicy = config.getString("security_csp", ""),
    xFrameOptions = config.getString("security_x_frame", "DENY")
  ))
  
  result.initGracefulShutdown(
    maxDrainTime = config.getFloat("shutdown_timeout", 30.0)
  )
  
  addHealthCheck("database", checkDatabase)
  addHealthCheck("disk_space", checkDiskSpace("/", 1.0))
  addHealthCheck("memory", checkMemory(90.0))
  
  result.registerHealthEndpoints()
  
  onShutdown(proc() {.async.} =
    info("Saving application state...")
  )
  
  onShutdown(proc() {.async.} =
    info("Closing external connections...")
  )

proc hello(ctx: Context) {.async.} =
  resp jsonResponse(%*{
    "message": "Hello from production-ready Prologue!",
    "request_id": ctx.ctxData.getOrDefault("request_id", ""),
    "version": getEnv("APP_VERSION", "1.0.0")
  })

proc apiEndpoint(ctx: Context) {.async.} =
  let data = %*{
    "data": [1, 2, 3, 4, 5],
    "timestamp": now().format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz")
  }
  resp jsonResponse(data)

proc errorExample(ctx: Context) {.async.} =
  raise newException(ValueError, "This is an example error")

when isMainModule:
  let app = configureApp()
  
  app.get("/", hello)
  app.get("/api/data", apiEndpoint)
  app.get("/error", errorExample)
  
  app.errorHandler(Http404, proc(ctx: Context) {.async.} =
    resp jsonResponse(%*{
      "error": "Not Found",
      "message": "The requested resource was not found",
      "request_id": ctx.ctxData.getOrDefault("request_id", "")
    }, Http404)
  )
  
  app.errorHandler({Http500..Http599}, proc(ctx: Context) {.async.} =
    error("Internal server error",
      field("path", ctx.request.path),
      field("method", ctx.request.reqMethod),
      field("error", getCurrentExceptionMsg())
    )
    
    resp jsonResponse(%*{
      "error": "Internal Server Error",
      "message": "An unexpected error occurred",
      "request_id": ctx.ctxData.getOrDefault("request_id", "")
    }, Http500)
  )
  
  info("Starting production server",
    field("port", app.gScope.settings.port.int),
    field("debug", app.gScope.settings.debug)
  )
  
  app.run()