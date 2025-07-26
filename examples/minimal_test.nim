import ../src/prologue
import std/json

proc hello(ctx: Context) {.async.} =
  resp jsonResponse(%*{"message": "Hello from Z-Prologue!"})

when isMainModule:
  let app = newApp()
  app.get("/", hello)
  echo "Minimal test server starting..."
  app.run()