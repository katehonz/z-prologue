# Enhanced GraphQL Module

A production-ready GraphQL implementation for Prologue that addresses common alpha version issues found in early GraphQL implementations. This module provides comprehensive features including proper type systems, DataLoader patterns, caching, rate limiting, and security enhancements.

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Schema Definition](#schema-definition)
- [DataLoader Pattern](#dataloader-pattern)
- [Caching System](#caching-system)
- [Rate Limiting](#rate-limiting)
- [Query Complexity Analysis](#query-complexity-analysis)
- [Error Handling](#error-handling)
- [ORM Integration](#orm-integration)
- [Security Features](#security-features)
- [Performance Optimization](#performance-optimization)
- [Testing](#testing)
- [Production Deployment](#production-deployment)

## Overview

The Enhanced GraphQL module addresses critical issues commonly found in alpha version GraphQL implementations:

- **String-based routing** → **Proper type system with schema validation**
- **N+1 query problems** → **DataLoader pattern for batch loading**
- **No caching** → **Built-in caching with TTL support**
- **Security vulnerabilities** → **Rate limiting and complexity analysis**
- **Poor error handling** → **GraphQL spec-compliant error responses**
- **No production features** → **Complete production-ready implementation**

## Key Features

### 🎯 Core GraphQL Features
- Complete GraphQL type system (Scalar, Object, List, Non-null)
- Proper GraphQL query parser and validator
- Schema introspection support
- Fragment support (inline and named)
- Variable support with type validation
- Directive support for schema extensions

### ⚡ Performance Optimizations
- **DataLoader**: Batch and cache database requests
- **Query Caching**: TTL-based result caching
- **Connection Pooling**: Efficient database connections
- **Lazy Loading**: On-demand field resolution

### 🔒 Security Features
- **Rate Limiting**: Prevent API abuse
- **Query Complexity Analysis**: Prevent expensive queries
- **Query Depth Limiting**: Prevent deeply nested queries
- **Authentication/Authorization**: Token-based security
- **CORS Protection**: Cross-origin request handling

### 🏗️ Developer Experience
- **GraphQL Playground**: Interactive query interface
- **Schema Validation**: Compile-time schema checking
- **Enhanced Error Messages**: Detailed debugging information
- **Hot Reloading**: Development-friendly updates

## Installation

The Enhanced GraphQL module is included with z-prologue:

```nim
import prologue
import graphql_enhanced
```

## Quick Start

### Basic Server Setup

```nim
import prologue
import graphql_enhanced

proc main() =
  let app = newApp()
  
  # Create schema
  let schema = createExampleSchema()
  
  # Add security middleware
  app.use(enhancedGraphQLCorsMiddleware())
  
  # Create production-ready handler with all features
  let rateLimiter = newRateLimiter(windowSize = 60, maxRequests = 100)
  let complexityAnalyzer = newQueryComplexityAnalyzer(maxDepth = 10, maxComplexity = 1000)
  
  # GraphQL endpoint with full feature set
  app.post("/graphql", enhancedGraphQLHandler(schema, rateLimiter, complexityAnalyzer))
  
  # Development playground
  when not defined(release):
    app.get("/graphql", enhancedGraphQLPlaygroundHandler("My GraphQL API"))
  
  app.run()

when isMainModule:
  main()
```

### Simple Schema Creation

```nim
proc createExampleSchema(): GraphQLSchema =
  let schema = newGraphQLSchema()
  
  # Create User type
  let userType = newGraphQLObjectType("User", "A user in the system")
  
  # Add fields with resolvers
  proc userIdResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
    result = source{"id"}
  
  userType.addField(newGraphQLField("id", createIdType(), userIdResolver))
  userType.addField(newGraphQLField("username", createStringType(), userIdResolver))
  
  # Create Query type
  let queryType = newGraphQLObjectType("Query", "Root query")
  
  proc userResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
    let id = args{"id"}.getStr
    # Use DataLoader for efficient loading
    result = await context.dataLoader.load("users", id)
  
  let userField = newGraphQLField("user", userType, userResolver)
  userField.addArgument(newGraphQLArgument("id", createIdType()))
  queryType.addField(userField)
  
  schema.setQueryType(queryType)
  schema.addType(userType)
  
  return schema
```

## Schema Definition

### Type System

The enhanced module provides a complete GraphQL type system:

```nim
# Scalar Types
let stringType = createStringType()
let intType = createIntType()
let floatType = createFloatType()
let booleanType = createBooleanType()
let idType = createIdType()

# Object Types
let userType = newGraphQLObjectType("User", "User entity")

# Fields with arguments
let userField = newGraphQLField("user", userType, userResolver, "Get user by ID")
userField.addArgument(newGraphQLArgument("id", idType, none(JsonNode), "User ID"))
```

### Schema Builder Pattern

```nim
proc buildUserSchema(): GraphQLSchema =
  let schema = newGraphQLSchema()
  
  # Define types
  let userType = defineUserType()
  let postType = definePostType()
  let commentType = defineCommentType()
  
  # Define root types
  let queryType = defineQueryType(userType, postType)
  let mutationType = defineMutationType(userType, postType)
  let subscriptionType = defineSubscriptionType()
  
  # Build schema
  schema.setQueryType(queryType)
  schema.setMutationType(mutationType)
  schema.setSubscriptionType(subscriptionType)
  
  return schema
```

### Custom Scalar Types

```nim
proc createDateTimeType(): GraphQLScalarType =
  GraphQLScalarType(
    name: "DateTime",
    description: "ISO 8601 date-time string",
    serialize: proc(value: JsonNode): JsonNode = 
      %value.getStr,
    parseValue: proc(value: JsonNode): JsonNode = 
      # Validate ISO 8601 format
      let dateStr = value.getStr
      if not isValidISODate(dateStr):
        raise newException(ValueError, "Invalid DateTime format")
      %dateStr,
    parseLiteral: proc(ast: JsonNode): JsonNode = 
      parseValue(ast)
  )
```

## DataLoader Pattern

The DataLoader pattern solves the N+1 query problem by batching database requests:

### Basic DataLoader Usage

```nim
# Create DataLoader
let dataLoader = newDataLoader()

# Register batch loader
proc userBatchLoader(ids: seq[string]): Future[seq[JsonNode]] {.async.} =
  # Single database query for all IDs
  let users = await db.getUsers(ids)
  return users.map(userToJson)

dataLoader.registerBatchLoader("users", userBatchLoader)

# Use in resolvers
proc resolveUser(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  let userId = args{"id"}.getStr
  result = await context.dataLoader.load("users", userId)

# Batch loading multiple items
let userIds = @["1", "2", "3", "4", "5"]
let users = await dataLoader.loadMany("users", userIds)
```

### Advanced DataLoader with Relationships

```nim
# Posts by author loader
proc postsByAuthorLoader(authorIds: seq[string]): Future[seq[JsonNode]] {.async.} =
  let posts = await db.getPostsByAuthors(authorIds)
  
  # Group posts by author ID
  var result: seq[JsonNode] = @[]
  for authorId in authorIds:
    let authorPosts = posts.filter(p => p.authorId == authorId)
    result.add(%authorPosts)
  
  return result

dataLoader.registerBatchLoader("posts_by_author", postsByAuthorLoader)

# Use in field resolver
proc resolveUserPosts(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  let userId = source{"id"}.getStr
  let posts = await context.dataLoader.load("posts_by_author", userId)
  
  # Apply pagination
  let first = args{"first"}.getInt(10)
  result = createConnection(posts, first, ...)
```

## Caching System

Built-in caching with TTL support for query results:

### Basic Caching

```nim
# Create cache
let cache = newGraphQLCache(maxSize = 1000, defaultTTL = 300)

# Manual caching
cache.set("user:123", userData, ttl = 600)
let cached = cache.get("user:123")

# Automatic query caching
let cacheKey = generateCacheKey(query, variables, operationName)
let cachedResult = context.cache.get(cacheKey)

if cachedResult.isSome:
  return cachedResult.get
else:
  let result = await executeQuery(...)
  context.cache.set(cacheKey, result)
  return result
```

### Cache Strategies

```nim
# Field-level caching
proc cachedUserResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  let userId = args{"id"}.getStr
  let cacheKey = "user:" & userId
  
  let cached = context.cache.get(cacheKey)
  if cached.isSome:
    return cached.get
  
  let user = await loadUserFromDB(userId)
  context.cache.set(cacheKey, user, ttl = 3600)  # Cache for 1 hour
  return user

# Query result caching with invalidation
proc invalidateUserCache(userId: string, context: GraphQLContext) =
  context.cache.clear("user:" & userId)
  context.cache.clear("users_list:*")  # Invalidate lists
```

## Rate Limiting

Protect your API from abuse with flexible rate limiting:

### Basic Rate Limiting

```nim
# Create rate limiter
let rateLimiter = newRateLimiter(
  windowSize = 60,    # 60 seconds
  maxRequests = 100   # 100 requests per minute
)

# Check rate limit
let clientId = getClientId(request)  # IP, user ID, or API key
if not rateLimiter.checkRateLimit(clientId):
  return rateLimitError()
```

### Advanced Rate Limiting

```nim
# Different limits for different operations
proc createAdaptiveRateLimiter(): RateLimiter =
  let limiter = newRateLimiter(windowSize = 60, maxRequests = 1000)
  
  # Custom logic for different operations
  proc checkLimit(clientId: string, operation: string): bool =
    case operation:
    of "query": 
      return limiter.checkRateLimit(clientId & ":query")
    of "mutation":
      return limiter.checkRateLimit(clientId & ":mutation", maxRequests = 10)
    of "subscription":
      return limiter.checkRateLimit(clientId & ":subscription", maxRequests = 5)
    else:
      return true
  
  return limiter
```

## Query Complexity Analysis

Prevent expensive queries with complexity analysis:

### Basic Complexity Analysis

```nim
# Create analyzer
let analyzer = newQueryComplexityAnalyzer(
  maxDepth = 10,
  maxComplexity = 1000,
  scalarCost = 1,
  objectCost = 2,
  listMultiplier = 10.0
)

# Analyze query before execution
let document = parseQuery(query)
if document.operations.len > 0:
  let complexity = analyzer.analyzeComplexity(document.operations[0].selectionSet)
  if complexity > analyzer.maxComplexity:
    return complexityError(complexity, analyzer.maxComplexity)
```

### Custom Complexity Rules

```nim
# Field-specific complexity rules
proc calculateFieldComplexity(fieldName: string, args: JsonNode): int =
  case fieldName:
  of "users":
    let first = args{"first"}.getInt(10)
    return first * 2  # Cost scales with pagination size
  of "searchUsers":
    return 50  # Search operations are expensive
  of "analytics":
    return 100  # Analytics queries are very expensive
  else:
    return 1
```

## Error Handling

GraphQL spec-compliant error handling with detailed debugging:

### Basic Error Handling

```nim
# Create GraphQL errors
let error = newGraphQLError(
  "User not found",
  locations = @[SourceLocation(line: 1, column: 5)],
  path = @["user"],
  extensions = %* {"code": "USER_NOT_FOUND", "userId": "123"}
)

# Format errors for response
let formattedErrors = formatErrors(@[error])
```

### Custom Error Types

```nim
type
  ValidationError = object of GraphQLError
  AuthenticationError = object of GraphQLError
  AuthorizationError = object of GraphQLError
  DatabaseError = object of GraphQLError

proc createValidationError(message: string, field: string): GraphQLError =
  newGraphQLError(
    message,
    extensions = %* {
      "code": "VALIDATION_ERROR",
      "field": field,
      "timestamp": $now()
    }
  )
```

### Error Recovery

```nim
proc safeResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  try:
    result = await riskyOperation(args)
  except DatabaseError as e:
    # Log error but return null
    echo "Database error in field ", info.fieldName, ": ", e.msg
    result = newJNull()
  except ValidationError as e:
    # Re-throw validation errors
    raise e
  except Exception as e:
    # Convert unexpected errors
    let gqlError = newGraphQLError(
      "Internal server error",
      extensions = %* {"code": "INTERNAL_ERROR", "originalError": e.msg}
    )
    raise newException(ValueError, $formatErrors(@[gqlError]))
```

## ORM Integration

Seamless integration with Bormin ORM:

### Model Definition

```nim
# Define ORM models
let userModel = newModelBuilder("users")
discard userModel.column("id", dbInt).primaryKey().autoIncrement()
discard userModel.column("username", dbVarchar, 50).notNull().unique()
discard userModel.column("email", dbVarchar, 100).notNull().unique()
discard userModel.column("created_at", dbTimestamp).notNull().defaultValue("CURRENT_TIMESTAMP")

let postModel = newModelBuilder("posts")
discard postModel.column("id", dbInt).primaryKey().autoIncrement()
discard postModel.column("title", dbVarchar, 200).notNull()
discard postModel.column("content", dbText).notNull()
discard postModel.column("author_id", dbInt).notNull()
discard postModel.foreignKey("author_id", "users", "id")
```

### ORM-Integrated Resolvers

```nim
proc ormUserResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  let id = args{"id"}.getInt
  let orm = getORM()
  
  # Use ORM for type-safe queries
  let user = await orm.findUser(id)
  if user.isSome:
    result = %* {
      "id": user.get.id,
      "username": user.get.username,
      "email": user.get.email,
      "createdAt": $user.get.createdAt
    }
  else:
    result = newJNull()

# Batch loader with ORM
proc createORMUserBatchLoader(orm: ORM): BatchLoadFn =
  return proc(ids: seq[string]): Future[seq[JsonNode]] {.async.} =
    let intIds = ids.map(parseInt)
    let users = await orm.findUsers(intIds)
    return users.map(userToJson)
```

### Relationship Loading

```nim
# Efficient relationship loading
proc resolveUserPosts(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  let userId = source{"id"}.getInt
  let first = args{"first"}.getInt(10)
  let after = args{"after"}.getStr("")
  
  let orm = getORM()
  let posts = await orm.getUserPosts(userId, limit = first, after = after)
  
  # Convert to GraphQL connection
  result = createConnection(posts, first, after)
```

## Security Features

### Authentication

```nim
proc authenticateUser(token: string): Future[Option[JsonNode]] {.async.} =
  try:
    let decoded = jwt.decode(token, secret)
    let userId = decoded.claims["user_id"].getStr
    let user = await loadUser(userId)
    return some(user)
  except JWTError:
    return none(JsonNode)

proc requireAuth(context: GraphQLContext): Future[JsonNode] {.async.} =
  if context.user.isNone:
    raise newException(GraphQLError, "Authentication required")
  return context.user.get
```

### Authorization

```nim
proc requireRole(context: GraphQLContext, role: string): Future[JsonNode] {.async.} =
  let user = await requireAuth(context)
  let userRole = user{"role"}.getStr
  if userRole != role:
    raise newException(GraphQLError, "Insufficient permissions")
  return user

# Use in resolvers
proc adminOnlyResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  discard await requireRole(context, "admin")
  # Execute admin operation
  result = await executeAdminOperation(args)
```

### Input Sanitization

```nim
proc sanitizeInput(input: JsonNode): JsonNode =
  # Remove potential XSS
  let sanitized = input.copy()
  for key, value in sanitized:
    if value.kind == JString:
      sanitized[key] = %escapeHtml(value.getStr)
  return sanitized
```

## Performance Optimization

### Query Optimization

```nim
# Field selection optimization
proc optimizeQuery(info: ResolveInfo): set[string] =
  var fields: set[string] = {}
  
  # Only load requested fields
  if info.selectionSet.isSome:
    for selection in info.selectionSet.get:
      if selection.kind == skField:
        fields.incl(selection.field.name)
  
  return fields

proc efficientUserResolver(source: JsonNode, args: JsonNode, context: GraphQLContext, info: ResolveInfo): Future[JsonNode] {.async.} =
  let requestedFields = optimizeQuery(info)
  let user = await loadUserOptimized(args{"id"}.getStr, requestedFields)
  return user
```

### Connection Optimization

```nim
# Efficient pagination
proc createConnection[T](items: seq[T], first: int, after: string, totalCount: int): JsonNode =
  var edges = newJArray()
  var startIndex = 0
  
  # Decode cursor
  if after.len > 0:
    startIndex = decodeCursor(after)
  
  # Create edges
  let endIndex = min(startIndex + first, items.len)
  for i in startIndex..<endIndex:
    edges.add(%* {
      "node": items[i],
      "cursor": encodeCursor(i)
    })
  
  return %* {
    "edges": edges,
    "pageInfo": {
      "hasNextPage": endIndex < totalCount,
      "hasPreviousPage": startIndex > 0,
      "startCursor": if edges.len > 0: edges[0]{"cursor"}.getStr else: "",
      "endCursor": if edges.len > 0: edges[^1]{"cursor"}.getStr else: ""
    },
    "totalCount": totalCount
  }
```

## Testing

### Unit Testing

```nim
import unittest
import asyncdispatch

suite "Enhanced GraphQL Tests":
  test "DataLoader batching":
    proc testDataLoader() {.async.} =
      let loader = newDataLoader()
      
      proc batchLoader(ids: seq[string]): Future[seq[JsonNode]] {.async.} =
        # Simulate database call
        return ids.map(id => %* {"id": id, "name": "User " & id})
      
      loader.registerBatchLoader("users", batchLoader)
      
      # Load multiple users - should batch
      let users = await loader.loadMany("users", @["1", "2", "3"])
      check users.len == 3
      check users[0]{"name"}.getStr == "User 1"
    
    waitFor testDataLoader()
  
  test "Caching system":
    let cache = newGraphQLCache(maxSize = 5, defaultTTL = 10)
    
    cache.set("test", %"value")
    let result = cache.get("test")
    check result.isSome
    check result.get.getStr == "value"
  
  test "Rate limiting":
    let limiter = newRateLimiter(windowSize = 1, maxRequests = 2)
    
    check limiter.checkRateLimit("client1") == true
    check limiter.checkRateLimit("client1") == true
    check limiter.checkRateLimit("client1") == false  # Exceeded
```

### Integration Testing

```nim
proc testCompleteFlow() {.async.} =
  let schema = createTestSchema()
  let context = newGraphQLContext(mockRequest)
  
  # Setup DataLoaders
  context.dataLoader.registerBatchLoader("users", createUserBatchLoader())
  
  # Test query execution
  let query = """
    query GetUser($id: ID!) {
      user(id: $id) {
        id
        username
        posts(first: 5) {
          edges {
            node {
              title
            }
          }
        }
      }
    }
  """
  
  let result = await execute(schema, query, context, %* {"id": "1"})
  check result.data.isSome
  check result.errors.len == 0
```

### Load Testing

```bash
# Using Artillery.js for load testing
artillery quick --count 100 --num 10 \
  --output report.json \
  http://localhost:8080/graphql \
  --payload '{"query": "{ users(first: 10) { edges { node { username } } } }"}'
```

## Production Deployment

### Environment Configuration

```nim
# Production configuration
when defined(release):
  const 
    RATE_LIMIT_WINDOW = 60
    RATE_LIMIT_MAX = 1000
    CACHE_SIZE = 10000
    CACHE_TTL = 3600
    MAX_QUERY_DEPTH = 15
    MAX_QUERY_COMPLEXITY = 10000
else:
  const
    RATE_LIMIT_WINDOW = 60
    RATE_LIMIT_MAX = 100
    CACHE_SIZE = 100
    CACHE_TTL = 300
    MAX_QUERY_DEPTH = 10
    MAX_QUERY_COMPLEXITY = 1000
```

### Docker Deployment

```dockerfile
FROM nimlang/nim:alpine

WORKDIR /app
COPY . .

RUN nimble install -d
RUN nim c -d:release --opt:speed src/main.nim

EXPOSE 8080
CMD ["./src/main"]
```

### Kubernetes Configuration

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: graphql-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: graphql-server
  template:
    metadata:
      labels:
        app: graphql-server
    spec:
      containers:
      - name: graphql-server
        image: myregistry/graphql-server:latest
        ports:
        - containerPort: 8080
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: url
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
```

### Monitoring

```nim
# Prometheus metrics
import prometheus

var
  queryCounter = newCounter("graphql_queries_total", "Total GraphQL queries")
  queryDuration = newHistogram("graphql_query_duration_seconds", "Query execution time")
  errorCounter = newCounter("graphql_errors_total", "Total GraphQL errors")

proc monitoredGraphQLHandler(schema: GraphQLSchema): HandlerAsync =
  return proc(ctx: Context) {.async.} =
    let startTime = epochTime()
    queryCounter.inc()
    
    try:
      await enhancedGraphQLHandler(schema)(ctx)
    except Exception as e:
      errorCounter.inc()
      raise e
    finally:
      let duration = epochTime() - startTime
      queryDuration.observe(duration)
```

## Example Schemas

### Blog Schema

```graphql
type Query {
  user(id: ID!): User
  users(first: Int, after: String, isActive: Boolean): UserConnection!
  post(id: ID!): Post
  posts(first: Int, after: String, authorId: ID): PostConnection!
  searchPosts(query: String!, first: Int): PostConnection!
}

type Mutation {
  createUser(input: CreateUserInput!): User!
  updateUser(id: ID!, input: UpdateUserInput!): User!
  deleteUser(id: ID!): Boolean!
  
  createPost(input: CreatePostInput!): Post!
  updatePost(id: ID!, input: UpdatePostInput!): Post!
  publishPost(id: ID!): Post!
  deletePost(id: ID!): Boolean!
  
  createComment(input: CreateCommentInput!): Comment!
}

type Subscription {
  postUpdated(authorId: ID): Post!
  commentAdded(postId: ID!): Comment!
  userStatusChanged: User!
}

type User {
  id: ID!
  username: String!
  email: String!
  firstName: String!
  lastName: String!
  isActive: Boolean!
  posts(first: Int, after: String): PostConnection!
  comments(first: Int, after: String): CommentConnection!
  createdAt: DateTime!
  updatedAt: DateTime!
}

type Post {
  id: ID!
  title: String!
  content: String!
  excerpt: String
  author: User!
  isPublished: Boolean!
  comments(first: Int, after: String): CommentConnection!
  tags: [String!]!
  createdAt: DateTime!
  updatedAt: DateTime!
  publishedAt: DateTime
}

type Comment {
  id: ID!
  content: String!
  author: User!
  post: Post!
  createdAt: DateTime!
}

# Connection types for pagination
type UserConnection {
  edges: [UserEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type UserEdge {
  node: User!
  cursor: String!
}

type PostConnection {
  edges: [PostEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type PostEdge {
  node: Post!
  cursor: String!
}

type CommentConnection {
  edges: [CommentEdge!]!
  pageInfo: PageInfo!
  totalCount: Int!
}

type CommentEdge {
  node: Comment!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  hasPreviousPage: Boolean!
  startCursor: String
  endCursor: String
}

# Input types
input CreateUserInput {
  username: String!
  email: String!
  firstName: String!
  lastName: String!
  password: String!
}

input UpdateUserInput {
  username: String
  email: String
  firstName: String
  lastName: String
  isActive: Boolean
}

input CreatePostInput {
  title: String!
  content: String!
  excerpt: String
  tags: [String!]
  isPublished: Boolean = false
}

input UpdatePostInput {
  title: String
  content: String
  excerpt: String
  tags: [String!]
  isPublished: Boolean
}

input CreateCommentInput {
  content: String!
  postId: ID!
}

# Custom scalar
scalar DateTime
```

## Conclusion

The Enhanced GraphQL module for Prologue provides a production-ready, secure, and performant GraphQL implementation that addresses all common issues found in alpha version GraphQL modules. With built-in DataLoader, caching, rate limiting, and comprehensive error handling, you can build robust GraphQL APIs that scale.

Key benefits over alpha implementations:
- ✅ **Type Safety**: Complete GraphQL type system with validation
- ✅ **Performance**: DataLoader and caching eliminate N+1 problems
- ✅ **Security**: Rate limiting, complexity analysis, and proper authentication
- ✅ **Production Ready**: Monitoring, logging, and deployment support
- ✅ **Developer Experience**: Enhanced playground and debugging tools

Ready for production use with PostgreSQL and other databases supported by Bormin ORM.