# GraphQL

GraphQL is a powerful query language for APIs that provides a flexible and efficient way to work with data. Prologue offers built-in GraphQL support through the `graphql` module.

## Installation

The GraphQL module is part of z-prologue and requires no additional installation.

```nim
import prologue
import graphql
```

## Core Concepts

### GraphQL Context

The context contains information about the current request and user:

```nim
type
  GraphQLContext* = ref object
    request*: Request
    user*: Option[JsonNode]  # Current user
```

### Pagination Types

Relay-style pagination is supported:

```nim
type
  PageInfo* = object
    hasNextPage*: bool
    hasPreviousPage*: bool
    startCursor*: string
    endCursor*: string
    
  Connection*[T] = object
    edges*: seq[Edge[T]]
    pageInfo*: PageInfo
    totalCount*: int
    
  Edge*[T] = object
    node*: T
    cursor*: string
```

## Quick Start

### Simple GraphQL Server

```nim
import prologue
import graphql

proc main() =
  let app = newApp()
  
  # Add CORS middleware
  app.use(graphqlCorsMiddleware())
  
  # GraphQL endpoint
  app.post("/graphql", graphqlHandler)
  
  # GraphQL Playground (development only)
  when not defined(release):
    app.get("/graphql", graphqlPlaygroundHandler)
  
  app.run()

when isMainModule:
  main()
```

### Defining Schema

```nim
# Define types
type
  User* = object
    id*: int
    username*: string
    email*: string
    createdAt*: string
    
  Post* = object
    id*: int
    title*: string
    content*: string
    authorId*: int
    author*: User
    createdAt*: string
```

### Creating Resolvers

```nim
# Query resolver
proc resolveUser*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let id = args{"id"}.getInt
  # Fetch user from database
  result = %* {
    "id": id,
    "username": "user" & $id,
    "email": "user" & $id & "@example.com",
    "createdAt": $now()
  }

# Mutation resolver
proc resolveCreateUser*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let input = args{"input"}
  let username = input{"username"}.getStr
  let email = input{"email"}.getStr
  let password = input{"password"}.getStr
  
  # Validation
  if not validateEmail(email):
    raise newException(ValueError, "Invalid email address")
  
  if not validatePassword(password):
    raise newException(ValueError, "Password must be at least 8 characters")
  
  # Create user
  result = %* {
    "id": rand(1000),
    "username": username,
    "email": email,
    "createdAt": $now()
  }
```

## Pagination

Use the built-in pagination types:

```nim
proc resolveUsers*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let first = args{"first"}.getInt(10)
  let after = args{"after"}.getStr("")
  
  # Decode cursor
  let offset = if after.len > 0: decodeCursor(after) else: 0
  
  # Fetch users
  var users: seq[JsonNode] = @[]
  # ... database fetch code ...
  
  # Create edges
  var edges: seq[JsonNode] = @[]
  for user in users:
    edges.add(%* {
      "node": user,
      "cursor": encodeCursor(user{"id"}.getInt)
    })
  
  result = %* {
    "edges": edges,
    "pageInfo": {
      "hasNextPage": hasMore,
      "hasPreviousPage": offset > 0,
      "startCursor": if edges.len > 0: edges[0]{"cursor"}.getStr else: "",
      "endCursor": if edges.len > 0: edges[^1]{"cursor"}.getStr else: ""
    },
    "totalCount": totalCount
  }
```

## Authentication and Authorization

### Extracting Token

```nim
proc graphqlHandler*(ctx: Context) {.async.} =
  # Create context
  let graphqlCtx = GraphQLContext(
    request: ctx.request,
    user: none(JsonNode)
  )
  
  # Extract token from header
  let authHeader = ctx.request.getHeader("Authorization")
  if authHeader.startsWith("Bearer "):
    let token = authHeader[7..^1]
    # Validate token
    let user = await validateToken(token)
    graphqlCtx.user = some(user)
```

### Protected Resolvers

```nim
proc requireAuth(ctx: GraphQLContext): Future[JsonNode] {.async.} =
  if ctx.user.isNone:
    raise newException(GraphQLError, "Authentication required")
  result = ctx.user.get

proc resolveMe*(ctx: GraphQLContext): Future[JsonNode] {.async.} =
  let user = await requireAuth(ctx)
  # Return current user
  result = user
```

## Error Handling

The GraphQL module provides structured error handling:

```nim
type
  GraphQLError* = object
    message*: string
    extensions*: JsonNode
    path*: seq[string]
    
  GraphQLResult* = object
    data*: JsonNode
    errors*: seq[GraphQLError]
```

Example handling:

```nim
try:
  let result = await executeGraphQL(schema, query, variables, ctx)
  # ...
except ValueError as e:
  ctx.response.body = $ %* {
    "errors": [{
      "message": e.msg,
      "extensions": {
        "code": "VALIDATION_ERROR"
      }
    }]
  }
```

## GraphQL Playground

In development mode, GraphQL Playground is available at `/graphql`:

```nim
when not defined(release):
  app.get("/graphql", graphqlPlaygroundHandler)
```

Playground provides:
- Interactive query editor
- Schema documentation
- Query history
- Variables and headers

## CORS Support

For cross-origin requests, use the built-in CORS middleware:

```nim
app.use(graphqlCorsMiddleware())
```

## Testing

### Testing with curl

```bash
# Valid query
curl -X POST http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{"query": "{ user(id: 1) { username email } }"}'

# Query with variables
curl -X POST http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "query GetUser($id: ID!) { user(id: $id) { username } }",
    "variables": { "id": "1" }
  }'

# Mutation
curl -X POST http://localhost:8080/graphql \
  -H 'Content-Type: application/json' \
  -d '{
    "query": "mutation CreateUser($input: CreateUserInput!) { createUser(input: $input) { id username } }",
    "variables": {
      "input": {
        "username": "newuser",
        "email": "newuser@example.com",
        "password": "securepass123"
      }
    }
  }'
```

### Unit Tests

```nim
import unittest
import asyncdispatch
import json

suite "GraphQL Tests":
  test "Valid query returns data":
    let ctx = GraphQLContext(user: none(JsonNode))
    let args = %* {"id": 1}
    let result = waitFor resolveUser(ctx, args)
    
    check result{"id"}.getInt == 1
    check result.hasKey("username")
    check result.hasKey("email")
  
  test "Invalid email validation":
    let ctx = GraphQLContext(user: none(JsonNode))
    let args = %* {
      "input": {
        "username": "test",
        "email": "invalid",
        "password": "password123"
      }
    }
    
    expect ValueError:
      discard waitFor resolveCreateUser(ctx, args)
```

## ORM Integration

The GraphQL module can be integrated with Bormin ORM:

```nim
import prologue/db/bormin/models

proc resolveUser*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let id = args{"id"}.getInt
  let orm = getORM()
  
  let sql = "SELECT * FROM users WHERE id = ?"
  let rows = await orm.conn.fastRows(sql, id)
  
  if rows.len > 0:
    result = rowToJson(rows[0])
  else:
    result = newJNull()
```

## Performance

To optimize performance:

1. **Use DataLoader** for batch queries
2. **Cache results** with the built-in cache system
3. **Limit query depth**
4. **Use pagination** for large lists

## Example Schema

```graphql
type Query {
  user(id: ID!): User
  users(first: Int, after: String): UserConnection!
  me: User
  
  post(id: ID!): Post
  posts(first: Int, after: String, authorId: ID): PostConnection!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!
  
  login(username: String!, password: String!): AuthPayload!
  logout: Boolean!
}

type User {
  id: ID!
  username: String!
  email: String!
  posts(first: Int, after: String): PostConnection!
  createdAt: String!
}

type Post {
  id: ID!
  title: String!
  content: String!
  author: User!
  createdAt: String!
}

type AuthPayload {
  token: String!
  user: User!
}
```

## Conclusion

The GraphQL module in Prologue provides all the necessary tools to create powerful and flexible APIs. With built-in support for pagination, authentication, and error handling, you can quickly create a production-ready GraphQL server.