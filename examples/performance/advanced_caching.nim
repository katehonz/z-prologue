# Advanced Caching Example for Prologue
# 
# This example demonstrates advanced caching strategies including
# multi-level caching, cache invalidation, and performance monitoring.

import std/[asyncdispatch, logging, strformat, json, tables, times, hashes]
import ../../src/prologue
import ../../src/prologue/performance

# Configure logging
addHandler(newConsoleLogger())
setLogFilter(lvlInfo)

# Sample blog posts data
var blogPosts = @[
  %*{
    "id": 1,
    "title": "Getting Started with Prologue",
    "content": "Prologue is a powerful web framework for Nim...",
    "author": "Alice",
    "created": "2025-01-01T10:00:00Z",
    "views": 150
  },
  %*{
    "id": 2,
    "title": "Performance Optimization Tips",
    "content": "Here are some tips to optimize your web application...",
    "author": "Bob",
    "created": "2025-01-02T14:30:00Z",
    "views": 89
  },
  %*{
    "id": 3,
    "title": "Advanced Caching Strategies",
    "content": "Caching is crucial for high-performance applications...",
    "author": "Charlie",
    "created": "2025-01-03T09:15:00Z",
    "views": 234
  }
]

# Global cache instances
var memoryCache: InMemoryCache
var redisCache: RedisCache
var multiLevelCache: MultiLevelCache

proc initCaches() =
  ## Initialize different cache backends
  memoryCache = newInMemoryCache(maxSize = 50)
  redisCache = newRedisCache("redis://localhost:6379", "blog:")
  multiLevelCache = newMultiLevelCache(memoryCache, redisCache)
  
  logging.info("Advanced caching system initialized")

proc getBlogPost(ctx: Context) {.async.} =
  ## Get a blog post with multi-level caching
  let postId = ctx.getPathParams("id", "0")
  let cacheKey = "post:" & postId
  
  # Try to get from multi-level cache
  let cachedPost = await multiLevelCache.get(cacheKey)
  if cachedPost.isSome:
    ctx.response.setHeader("X-Cache", "HIT")
    ctx.response.setHeader("Content-Type", "application/json")
    resp cachedPost.get
    return
  
  # Simulate expensive database query
  await sleepAsync(50)  # 50ms delay
  
  let id = parseInt(postId)
  var post: JsonNode = nil
  
  for p in blogPosts:
    if p["id"].getInt() == id:
      post = p
      # Increment view count
      post["views"] = %(post["views"].getInt() + 1)
      break
  
  if post == nil:
    ctx.response.code = Http404
    resp "{\"error\": \"Post not found\"}"
    return
  
  let postJson = $post
  
  # Cache the result with 5 minute TTL
  discard await multiLevelCache.set(cacheKey, postJson, 300)
  
  ctx.response.setHeader("X-Cache", "MISS")
  ctx.response.setHeader("Content-Type", "application/json")
  resp postJson

proc getPopularPosts(ctx: Context) {.async.} =
  ## Get popular posts with aggressive caching
  let cacheKey = "popular_posts"
  
  # Check cache first
  let cached = await memoryCache.get(cacheKey)
  if cached.isSome:
    ctx.response.setHeader("X-Cache", "HIT")
    ctx.response.setHeader("Content-Type", "application/json")
    resp cached.get
    return
  
  # Simulate expensive aggregation query
  await sleepAsync(100)  # 100ms delay
  
  # Sort posts by views
  var sortedPosts = blogPosts
  sortedPosts.sort(proc(a, b: JsonNode): int =
    cmp(b["views"].getInt(), a["views"].getInt())
  )
  
  # Take top 5
  let popularPosts = sortedPosts[0..min(4, sortedPosts.len-1)]
  let result = $(%popularPosts)
  
  # Cache for 2 minutes (popular posts change frequently)
  discard await memoryCache.set(cacheKey, result, 120)
  
  ctx.response.setHeader("X-Cache", "MISS")
  ctx.response.setHeader("Content-Type", "application/json")
  resp result

proc searchPosts(ctx: Context) {.async.} =
  ## Search posts with query-based caching
  let query = ctx.getQueryParams("q", "")
  if query.len == 0:
    ctx.response.code = Http400
    resp "{\"error\": \"Query parameter 'q' is required\"}"
    return
  
  # Create cache key based on query hash
  let cacheKey = "search:" & $hash(query.toLowerAscii())
  
  # Check cache
  let cached = await memoryCache.get(cacheKey)
  if cached.isSome:
    ctx.response.setHeader("X-Cache", "HIT")
    ctx.response.setHeader("Content-Type", "application/json")
    resp cached.get
    return
  
  # Simulate search operation
  await sleepAsync(75)  # 75ms delay
  
  var results: seq[JsonNode] = @[]
  let queryLower = query.toLowerAscii()
  
  for post in blogPosts:
    let title = post["title"].getStr().toLowerAscii()
    let content = post["content"].getStr().toLowerAscii()
    
    if queryLower in title or queryLower in content:
      results.add(post)
  
  let searchResults = $(%results)
  
  # Cache search results for 10 minutes
  discard await memoryCache.set(cacheKey, searchResults, 600)
  
  ctx.response.setHeader("X-Cache", "MISS")
  ctx.response.setHeader("Content-Type", "application/json")
  resp searchResults

proc createPost(ctx: Context) {.async.} =
  ## Create a new post and invalidate related caches
  try:
    let body = await ctx.request.body()
    let postData = parseJson(body)
    
    # Add metadata
    let newId = blogPosts.len + 1
    postData["id"] = %newId
    postData["created"] = %($now())
    postData["views"] = %0
    
    # Add to our data store
    blogPosts.add(postData)
    
    # Invalidate related caches
    discard await multiLevelCache.delete("popular_posts")
    
    # Clear search cache (simplified - in real app would be more targeted)
    await memoryCache.clear()
    
    logging.info("Created new post and invalidated caches")
    
    ctx.response.setHeader("Content-Type", "application/json")
    resp $postData
    
  except JsonParsingError:
    ctx.response.code = Http400
    resp "{\"error\": \"Invalid JSON\"}"

proc getCacheStats(ctx: Context) {.async.} =
  ## Get detailed cache statistics
  let memoryStats = await memoryCache.getStats()
  let multiStats = await multiLevelCache.getStats()
  
  let stats = %*{
    "memory_cache": {
      "hits": memoryStats.hits,
      "misses": memoryStats.misses,
      "size": memoryStats.size,
      "sets": memoryStats.sets
    },
    "multi_level_cache": {
      "size": multiStats.size
    },
    "performance_metrics": getPerformanceMetrics()
  }
  
  ctx.response.setHeader("Content-Type", "application/json")
  resp $stats

proc clearCache(ctx: Context) {.async.} =
  ## Clear all caches (admin endpoint)
  let cleared = await multiLevelCache.clear()
  
  if cleared:
    resp "{\"message\": \"All caches cleared successfully\"}"
  else:
    ctx.response.code = Http500
    resp "{\"error\": \"Failed to clear caches\"}"

proc warmupCache(ctx: Context) {.async.} =
  ## Warm up cache with frequently accessed data
  logging.info("Starting cache warmup...")
  
  # Pre-load popular posts
  for i, post in blogPosts:
    let cacheKey = "post:" & $post["id"].getInt()
    discard await multiLevelCache.set(cacheKey, $post, 300)
  
  # Pre-load popular posts list
  let popularCacheKey = "popular_posts"
  var sortedPosts = blogPosts
  sortedPosts.sort(proc(a, b: JsonNode): int =
    cmp(b["views"].getInt(), a["views"].getInt())
  )
  let popularPosts = sortedPosts[0..min(4, sortedPosts.len-1)]
  discard await memoryCache.set(popularCacheKey, $(%popularPosts), 120)
  
  logging.info("Cache warmup completed")
  resp "{\"message\": \"Cache warmup completed\"}"

proc main() {.async.} =
  # Create application
  let settings = newSettings(
    appName = "Advanced Caching Demo",
    debug = true,
    port = Port(8081)
  )
  
  var app = newApp(settings)
  
  # Initialize caches
  initCaches()
  
  # Initialize performance optimizations
  let perfConfig = PerformanceConfig(
    enableCaching: true,
    cacheSize: 100,
    cacheTTL: 300,
    enableMetrics: true
  )
  
  app.initPerformanceOptimizations(perfConfig)
  
  # Add routes
  app.get("/posts/{id}", getBlogPost)
  app.get("/posts/popular", getPopularPosts)
  app.get("/posts/search", searchPosts)
  app.post("/posts", createPost)
  app.get("/cache/stats", getCacheStats)
  app.delete("/cache", clearCache)
  app.post("/cache/warmup", warmupCache)
  
  # Home page
  app.get("/", proc(ctx: Context) {.async.} =
    resp """
    <h1>Advanced Caching Demo</h1>
    <p>This demo shows multi-level caching strategies:</p>
    <ul>
      <li><a href="/posts/1">GET /posts/1</a> - Get post with multi-level caching</li>
      <li><a href="/posts/popular">GET /posts/popular</a> - Popular posts (memory cache)</li>
      <li><a href="/posts/search?q=performance">GET /posts/search?q=performance</a> - Search with query caching</li>
      <li>POST /posts - Create post (invalidates caches)</li>
      <li><a href="/cache/stats">GET /cache/stats</a> - Cache statistics</li>
      <li>POST /cache/warmup - Warm up cache</li>
      <li>DELETE /cache - Clear all caches</li>
    </ul>
    <p>Try accessing the same endpoints multiple times to see caching in action!</p>
    """
  )
  
  echo "Starting Advanced Caching Demo..."
  echo "Visit http://localhost:8081 to see the demo"
  
  app.run()

when isMainModule:
  waitFor main()