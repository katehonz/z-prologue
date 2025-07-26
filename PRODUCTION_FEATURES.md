# Production-Ready Features

## 🚀 New Production Features in Z-Prologue

### 1. Rate Limiting
Protect your API from abuse with flexible rate limiting strategies:
- **Fixed Window**: Traditional rate limiting
- **Sliding Window**: More accurate rate limiting
- **Token Bucket**: Smooth rate limiting with burst capacity

```nim
import prologue/middlewares

# Simple IP-based rate limiting
app.use(rateLimitByIP(maxRequests = 100, windowSeconds = 60))

# Custom rate limiting
let limiter = newRateLimiter(
  maxRequests = 1000,
  windowSeconds = 3600,
  strategy = TokenBucket
)
app.use(rateLimitMiddleware(limiter))
```

### 2. Structured Logging
Professional logging with JSON output and request tracking:

```nim
import prologue/logging

# Initialize structured logging
initDefaultLogger(
  format = JSON,
  output = Both,  # Both stdout and file
  minLevel = Info,
  filepath = "app.log"
)

# Log with structured fields
info("User login", 
  field("user_id", userId),
  field("ip", ctx.request.ip)
)
```

### 3. Health Checks & Monitoring
Kubernetes-ready health endpoints:

```nim
import prologue/middlewares/health

# Add custom health checks
addHealthCheck("database", checkDatabase)
addHealthCheck("disk_space", checkDiskSpace("/", minFreeGB = 1.0))

# Register endpoints
app.registerHealthEndpoints()
# Creates: /health, /health/live, /health/ready, /metrics
```

### 4. Response Compression
Automatic gzip/deflate compression:

```nim
app.use(compressionMiddleware(
  minSize = 1024,
  level = 6,
  algorithms = {Gzip, Deflate}
))
```

### 5. Security Headers
Comprehensive security headers middleware:

```nim
app.use(securityHeadersMiddleware(
  hsts = true,
  xFrameOptions = "DENY",
  contentSecurityPolicy = defaultCSP()
))
```

### 6. Graceful Shutdown
Zero-downtime deployments:

```nim
app.initGracefulShutdown(maxDrainTime = 30.0)

# Register cleanup handlers
onShutdown(proc() {.async.} =
  await closeDatabase()
  await saveCache()
)
```

### 7. Advanced Configuration
Environment-based configuration with validation:

```nim
import prologue/config

let config = newAdvancedConfig()
config.load()  # Loads from env vars and config files

let dbHost = config.getString("database.host", "localhost")
let poolSize = config.getInt("database.pool_size", 10)
```

### 8. Request ID Tracking
Trace requests across your system:

```nim
app.use(requestIDMiddleware())

# Access in handlers
let requestId = ctx.ctxData["request_id"]
```

## 📋 Complete Production Example

```nim
import prologue
import prologue/middlewares
import prologue/logging
import prologue/config

proc createProductionApp(): Prologue =
  # Load configuration
  let config = newAdvancedConfig()
  config.load()
  
  # Setup logging
  initDefaultLogger(
    format = JSON,
    minLevel = Info,
    asyncMode = true
  )
  
  # Create app
  let app = newApp(
    newSettings(
      debug = false,
      port = Port(config.getInt("port", 8080))
    )
  )
  
  # Middleware stack (order matters!)
  app.use(requestIDMiddleware())
  app.use(loggingMiddleware())
  app.use(rateLimitByIP(100, 60))
  app.use(compressionMiddleware())
  app.use(securityHeadersMiddleware())
  
  # Health checks
  addHealthCheck("database", checkDatabase)
  app.registerHealthEndpoints()
  
  # Graceful shutdown
  app.initGracefulShutdown(30.0)
  
  return app

when isMainModule:
  let app = createProductionApp()
  app.run()
```

## 🔧 Environment Variables

```bash
# Application
APP_NAME=my-app
APP_PORT=8080
APP_DEBUG=false
APP_SECRET_KEY=your-secret-key

# Logging
APP_LOG_LEVEL=info
APP_LOG_FORMAT=json
APP_LOG_FILE=logs/app.log

# Rate Limiting
APP_RATE_LIMIT_MAX=100
APP_RATE_LIMIT_WINDOW=60

# Database
APP_DATABASE_HOST=localhost
APP_DATABASE_PORT=5432
APP_DATABASE_NAME=myapp
APP_DATABASE_POOL_SIZE=10
```

## 📊 Monitoring Integration

The `/metrics` endpoint provides Prometheus-compatible metrics:

```
# HELP app_uptime_seconds Application uptime in seconds
# TYPE app_uptime_seconds gauge
app_uptime_seconds 3600

# HELP app_health_check Health check status
# TYPE app_health_check gauge
app_health_check{name="database"} 1
app_health_check{name="disk_space"} 1
```

## 🛡️ Security Best Practices

1. **Always use HTTPS in production** (terminate TLS at load balancer)
2. **Set secure headers** with `securityHeadersMiddleware`
3. **Enable rate limiting** to prevent abuse
4. **Use structured logging** for security auditing
5. **Implement health checks** for monitoring
6. **Configure graceful shutdown** for zero-downtime deployments

## 🚀 Performance Tips

1. **Enable compression** for text responses
2. **Use connection pooling** for databases
3. **Configure appropriate rate limits**
4. **Use async logging** to avoid blocking
5. **Monitor with `/metrics` endpoint**

## 📦 Deployment Ready

Z-Prologue is now ready for:
- ✅ Docker containers
- ✅ Kubernetes deployments
- ✅ Cloud platforms (AWS, GCP, Azure)
- ✅ Hetzner VPS
- ✅ Load balanced environments
- ✅ Auto-scaling setups