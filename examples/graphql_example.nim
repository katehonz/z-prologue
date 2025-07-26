import ../src/prologue
import ../src/graphql

proc main() =
  # Създаване на приложение
  let app = newApp()
  
  # Добавяне на CORS middleware
  app.use(graphqlCorsMiddleware())
  
  # GraphQL ендпойнт
  app.post("/graphql", graphqlHandler)
  
  # GraphQL Playground (само в development)
  when not defined(release):
    app.get("/graphql", graphqlPlaygroundHandler)
  
  # Стартиране на сървъра
  app.run()

when isMainModule:
  echo "Starting GraphQL server on http://localhost:8080"
  echo "GraphQL endpoint: http://localhost:8080/graphql"
  echo "GraphQL Playground: http://localhost:8080/graphql"
  main()