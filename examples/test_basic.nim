import ../src/prologue
import ../src/prologue/middlewares/[ratelimit, health]
import std/[json, times]

proc hello(ctx: Context) {.async.} =
  resp jsonResponse(%*{
    "message": "Hello from Z-Prologue!",
    "timestamp": now().format("yyyy-MM-dd'T'HH:mm:ss")
  })

when isMainModule:
  let app = newApp()
  
  # Add rate limiting
  app.use(rateLimitByIP(maxRequests = 5, windowSeconds = 10))
  
  # Add basic health check
  addHealthCheck("basic", proc(): Future[tuple[status: HealthStatus, message: string]] {.async.} =
    result = (Healthy, "App is running")
  )
  
  app.registerHealthEndpoints()
  
  app.get("/", hello)
  
  echo "Starting Z-Prologue test server on port 8080"
  echo "Test endpoints:"
  echo "  GET /         - Hello message"
  echo "  GET /health   - Health check"
  echo "  GET /metrics  - Metrics"
  
  app.run()