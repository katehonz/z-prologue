import ../src/prologue
import ../src/prologue/middlewares/ratelimit
import std/json

proc hello(ctx: Context) {.async.} =
  resp jsonResponse(%*{"message": "Rate limited endpoint!"})

when isMainModule:
  let app = newApp()
  
  # Add rate limiting
  app.use(rateLimitByIP(maxRequests = 3, windowSeconds = 10))
  
  app.get("/", hello)
  
  echo "Rate limit test server starting..."
  echo "Try accessing http://localhost:8080 multiple times quickly"
  app.run()