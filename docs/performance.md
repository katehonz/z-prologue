# Performance Optimizations for Prologue

This document describes the comprehensive performance optimization features available in Prologue, designed to significantly improve application performance and scalability.

## Overview

Prologue's performance optimization suite includes:

- **Connection Pooling** - Efficient database connection management
- **Advanced Caching** - Multi-level caching with various backends
- **Lazy Loading** - Deferred resource initialization
- **Optimized Routing** - High-performance trie-based route matching
- **Performance Monitoring** - Built-in metrics and profiling

## Quick Start

```nim
import prologue
import prologue/performance

# Create application with performance optimizations
let settings = newSettings(appName = "MyApp", port = Port(8080))
var app = newApp(settings)

# Initialize all performance optimizations
let perfConfig = defaultPerformanceConfig()
app.initPerformanceOptimizations(perfConfig)

# Your routes here
app.get("/", proc(ctx: Context) {.async.} =
  resp "Hello, optimized world!"
)

app.run()
```

## Connection Pooling

Connection pooling reduces database connection overhead by reusing existing connections.

### Basic Usage

```nim
import prologue/db/connectionpool

# Initialize connection pool
app.initConnectionPool("postgresql://user:pass@localhost/db", 
                      maxConnections = 20, minConnections = 5)

# Use in handlers
proc getUser(ctx: Context) {.async.} =
  await ctx.withConnection(proc(conn: DbConn) {.async.} =
    let userId = ctx.getPathParams("id")
    let userData = await conn.query("SELECT * FROM users WHERE id = ?", userId)
    resp $userData
  )
```

### Configuration Options

- `maxConnections`: Maximum number of connections in pool (default: 10)
- `minConnections`: Minimum number of connections to maintain (default: 2)
- `connectionTimeout`: Connection timeout in milliseconds (default: 30000)
- `validationInterval`: How often to validate connections in milliseconds (default: 30000)

### Benefits

- **Reduced Latency**: Eliminates connection establishment overhead
- **Better Resource Management**: Controls database server load
- **Connection Validation**: Automatically handles stale connections
- **Thread Safety**: Safe for concurrent access

## Advanced Caching

Prologue provides multiple caching strategies for different use cases.

### In-Memory Caching

```nim
import prologue/cache/cache

# Create in-memory cache
let cache = newInMemoryCache(maxSize = 1000)

# Use in handlers
proc getExpensiveData(ctx: Context) {.async.} =
  let cacheKey = "expensive_data:" & ctx.getPathParams("id")
  
  let cached = await cache.get(cacheKey)
  if cached.isSome:
    resp cached.get
    return
  
  # Generate expensive data
  let data = await generateExpensiveData()
  discard await cache.set(cacheKey, data, ttl = 300)  # 5 minutes
  resp data
```

### Multi-Level Caching

```nim
# Combine multiple cache backends
let memoryCache = newInMemoryCache(maxSize = 100)
let redisCache = newRedisCache("redis://localhost:6379")
let multiCache = newMultiLevelCache(memoryCache, redisCache)

# Use cache middleware
app.use(cacheMiddleware(multiCache, ttl = 60))
```

### Cache Middleware

```nim
# Automatic caching for GET requests
app.use(cacheMiddleware(cache, ttl = 300))

# Custom cache key generation
app.use(cacheMiddleware(cache, ttl = 300, 
  keyGenerator = proc(ctx: Context): string =
    return "api:" & $ctx.request.url & ":" & ctx.getQueryParams("version", "v1")
))
```

## Lazy Loading

Lazy loading defers resource initialization until needed, improving startup time.

### Basic Lazy Resources

```nim
import prologue/performance/lazyloading

# Create lazy resource
let expensiveResource = newLazyResource(proc(): Future[string] {.async.} =
  # This expensive operation only runs when first accessed
  await sleepAsync(1000)  # Simulate expensive operation
  return await loadConfigFromDatabase()
)

# Use in handlers
proc getConfig(ctx: Context) {.async.} =
  let config = await expensiveResource.get()  # Loads only once
  resp config
```

### Lazy File Loading

```nim
# Lazy load configuration files
let configResource = newLazyFileLoader("config/app.conf")

proc getAppConfig(ctx: Context) {.async.} =
  let config = await configResource.get()
  resp config
```

### Global Resource Management

```nim
# Register resources globally
registerGlobalResource("database_config", dbConfigResource)
registerGlobalResource("api_keys", apiKeysResource)

# Access from anywhere
proc someHandler(ctx: Context) {.async.} =
  let dbConfig = getGlobalResource("database_config", string)
  let config = await dbConfig.get()
  # Use config...
```

## Optimized Routing

High-performance trie-based routing for applications with many routes.

### Basic Usage

```nim
import prologue/routing/optimized

# Initialize optimized router
app.initOptimizedRouter()

# Routes are automatically optimized
app.get("/users/{id}", getUserHandler)
app.get("/posts/{id}/comments/{commentId}", getCommentHandler)
app.get("/static/*", staticFileHandler)
```

### Performance Benefits

- **O(k) Lookup Time**: Where k is the path length, not number of routes
- **Memory Efficient**: Shared prefixes reduce memory usage
- **Parameter Extraction**: Fast parameter parsing
- **Wildcard Support**: Efficient wildcard matching

### Route Statistics

```nim
let router = app.getOptimizedRouter()
let stats = router.getRouteStats()
echo "Total routes: ", stats.totalRoutes
echo "Max depth: ", stats.maxDepth
echo "GET routes: ", stats.methodCounts[HttpGet]
```

## Performance Monitoring

Built-in performance monitoring and metrics collection.

### Automatic Metrics

```nim
# Enable performance monitoring
let perfConfig = PerformanceConfig(enableMetrics: true)
app.initPerformanceOptimizations(perfConfig)

# Metrics are automatically collected
proc getMetrics(ctx: Context) {.async.} =
  let metrics = getPerformanceMetrics()
  resp $(%*{
    "requestCount": metrics.requestCount,
    "averageResponseTime": metrics.averageResponseTime,
    "cacheHitRate": metrics.cacheHitRate
  })
```

### Custom Performance Monitoring

```nim
# Add performance monitoring middleware
app.use(performanceMonitoringMiddleware())

# Custom route performance monitoring
app.use(routePerformanceMiddleware())
```

### Health Checks

```nim
proc healthCheck(ctx: Context) {.async.} =
  let isHealthy = await performanceHealthCheck(ctx.gScope.app)
  if isHealthy:
    resp "{\"status\": \"healthy\"}"
  else:
    ctx.response.code = Http503
    resp "{\"status\": \"unhealthy\"}"
```

## Configuration

### Performance Configuration

```nim
let perfConfig = PerformanceConfig(
  enableConnectionPool: true,
  connectionPoolSize: 20,
  enableCaching: true,
  cacheSize: 1000,
  cacheTTL: 300,
  enableLazyLoading: true,
  enableOptimizedRouting: true,
  enableMetrics: true
)

# Validate configuration
if not validatePerformanceConfig(perfConfig):
  echo "Invalid configuration!"
  quit(1)

app.initPerformanceOptimizations(perfConfig)
```

### Environment-Based Configuration

```nim
# Load configuration from environment
let perfConfig = PerformanceConfig(
  connectionPoolSize: getEnv("DB_POOL_SIZE", "10").parseInt(),
  cacheSize: getEnv("CACHE_SIZE", "1000").parseInt(),
  cacheTTL: getEnv("CACHE_TTL", "300").parseInt()
)
```

## Best Practices

### Connection Pooling

1. **Size the pool appropriately**: Too small = bottleneck, too large = resource waste
2. **Monitor pool utilization**: Use `getStats()` to track usage
3. **Handle connection errors**: Always use try/finally blocks
4. **Validate connections**: Enable automatic validation for long-running apps

### Caching

1. **Choose appropriate TTL**: Balance freshness vs performance
2. **Use cache hierarchies**: Fast local cache + persistent distributed cache
3. **Cache invalidation**: Implement proper cache invalidation strategies
4. **Monitor cache hit rates**: Aim for >80% hit rate for frequently accessed data

### Lazy Loading

1. **Identify expensive resources**: Profile to find initialization bottlenecks
2. **Handle loading errors**: Implement retry logic for critical resources
3. **Consider thread safety**: Use locks for shared lazy resources
4. **Monitor resource usage**: Track which resources are actually used

### Routing

1. **Use specific routes first**: More specific routes should have higher priority
2. **Minimize route depth**: Deeply nested routes are slower to match
3. **Group related routes**: Use route groups for better organization
4. **Monitor routing performance**: Use routing metrics to identify slow routes

## Benchmarking

### Built-in Benchmarks

```nim
# Benchmark specific routes
let (avgTime, minTime, maxTime) = await app.benchmarkRoute("/api/users", iterations = 1000)
echo "Average response time: ", avgTime, "ms"

# Run performance tests
import tests/performance/test_performance_optimizations
runTests()
```

### Custom Benchmarks

```nim
proc benchmarkMyFeature() {.async.} =
  let startTime = cpuTime()
  
  # Your code here
  for i in 1..1000:
    await someOperation()
  
  let duration = (cpuTime() - startTime) * 1000.0
  echo "Benchmark completed in: ", duration, "ms"
```

## Examples

See the `examples/performance/` directory for complete working examples:

- [`basic_optimizations.nim`](../examples/performance/basic_optimizations.nim) - Basic usage of all optimization features
- [`advanced_caching.nim`](../examples/performance/advanced_caching.nim) - Advanced caching strategies and patterns

## Testing

Run the performance optimization tests:

```bash
nim c -r tests/performance/test_performance_optimizations.nim
```

## Troubleshooting

### Common Issues

1. **High memory usage**: Reduce cache sizes or implement better eviction policies
2. **Connection pool exhaustion**: Increase pool size or reduce connection hold time
3. **Cache misses**: Review cache keys and TTL settings
4. **Slow routing**: Check for route conflicts or overly complex patterns

### Debugging

```nim
# Enable debug logging
setLogFilter(lvlDebug)

# Monitor performance metrics
let metrics = getPerformanceMetrics()
echo "Current performance: ", metrics

# Check cache statistics
let cacheStats = await cache.getStats()
echo "Cache hit rate: ", cacheStats.hits / (cacheStats.hits + cacheStats.misses)
```

## Performance Tips

1. **Profile first**: Use profiling tools to identify actual bottlenecks
2. **Measure everything**: Use metrics to validate optimization effectiveness
3. **Start simple**: Begin with basic optimizations before advanced techniques
4. **Monitor in production**: Performance characteristics can differ between environments
5. **Regular maintenance**: Clean up expired cache entries and validate connections

## API Reference

For detailed API documentation, see:

- [Connection Pool API](connectionpool.md)
- [Cache API](cache.md)
- [Lazy Loading API](lazyloading.md)
- [Optimized Routing API](routing.md)