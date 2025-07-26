import prologue
import ./graphql

when isMainModule:
  var app = newApp()
  app.post("/graphql", graphqlHandler)
  app.run()
