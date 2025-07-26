import prologue
import json

# Simple GraphQL handler for testing
proc graphqlHandler*(ctx: Context) {.async.} =
  ## Basic GraphQL handler
  let body = ctx.request.body
  let jsonBody = parseJson(body)
  
  let query = jsonBody{"query"}.getStr
  
  if query.len == 0:
    ctx.response.code = Http400
    ctx.response.body = $ %* {
      "errors": [{
        "message": "Missing query"
      }]
    }
    return
  
  # Simple response for testing
  ctx.response.body = $ %* {
    "data": {
      "hello": "Hello from GraphQL!"
    }
  }
  ctx.response.addHeader("Content-Type", "application/json")

proc main() =
  let app = newApp()
  
  app.post("/graphql", graphqlHandler)
  
  app.run()

when isMainModule:
  echo "Starting simple GraphQL test server on http://localhost:8080"
  echo "GraphQL endpoint: http://localhost:8080/graphql"
  echo "Test with: curl -X POST http://localhost:8080/graphql -H 'Content-Type: application/json' -d '{\"query\": \"{ hello }\"}'"
  main()