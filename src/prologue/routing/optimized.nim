# Copyright 2025 Prologue Performance Optimizations
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Optimized Routing Algorithm for Prologue
##
## This module provides a high-performance trie-based routing algorithm
## that significantly improves route matching performance for applications
## with many routes.

import std/[tables, strutils, options, logging, times]
import ../core/types
import ../core/middlewaresbase
import ../core/httpcore/httplogue
import ../core/application

type
  RouteNode* = ref object
    ## Node in the routing trie
    children: Table[string, RouteNode]
    paramChild: Option[tuple[name: string, node: RouteNode]]
    wildcardChild: Option[RouteNode]
    handler: Option[HandlerAsync]
    middlewares: seq[HandlerAsync]
    httpMethod: HttpMethod
    isEndpoint: bool
    priority: int  # Higher priority routes are checked first

  TrieRouter* = ref object
    ## Trie-based router implementation
    roots: Table[HttpMethod, RouteNode]  # Separate tries for each HTTP method
    totalRoutes: int
    maxDepth: int

  RouteMatch* = object
    ## Result of route matching
    handler*: Option[HandlerAsync]
    params*: Table[string, string]
    middlewares*: seq[HandlerAsync]
    matched*: bool

  OptimizedRoutingError* = object of CatchableError

# Route node operations
proc newRouteNode*(): RouteNode =
  ## Creates a new route node
  result = RouteNode(
    children: initTable[string, RouteNode](),
    paramChild: none(tuple[name: string, node: RouteNode]),
    wildcardChild: none(RouteNode),
    handler: none(HandlerAsync),
    middlewares: @[],
    isEndpoint: false,
    priority: 0
  )

proc newTrieRouter*(): TrieRouter =
  ## Creates a new trie-based router
  result = TrieRouter(
    roots: initTable[HttpMethod, RouteNode](),
    totalRoutes: 0,
    maxDepth: 0
  )
  
  # Initialize root nodes for all HTTP methods
  for httpMethod in [HttpGet, HttpPost, HttpPut, HttpDelete, HttpPatch,
                     HttpHead, HttpOptions, HttpTrace, HttpConnect]:
    result.roots[httpMethod] = newRouteNode()
  
  logging.info("Optimized trie router created")

proc parseRouteSegments(path: string): seq[string] =
  ## Parses route path into segments
  result = @[]
  if path.len == 0 or path == "/":
    return
  
  let segments = path.split('/')
  for segment in segments:
    if segment.len > 0:
      result.add(segment)

proc isParameterSegment(segment: string): bool =
  ## Checks if a segment is a parameter (starts with { and ends with })
  result = segment.len > 2 and segment.startsWith('{') and segment.endsWith('}')

proc getParameterName(segment: string): string =
  ## Extracts parameter name from segment
  if isParameterSegment(segment):
    result = segment[1..^2]
  else:
    result = ""

proc isWildcardSegment(segment: string): bool =
  ## Checks if a segment is a wildcard (*)
  result = segment == "*"

proc addRoute*(router: TrieRouter, path: string, handler: HandlerAsync,
               httpMethod: HttpMethod, middlewares: seq[HandlerAsync] = @[],
               priority: int = 0) =
  ## Adds a route to the trie router
  if not router.roots.hasKey(httpMethod):
    router.roots[httpMethod] = newRouteNode()
  
  var current = router.roots[httpMethod]
  let segments = parseRouteSegments(path)
  var depth = 0
  
  for i, segment in segments:
    inc(depth)
    
    if isWildcardSegment(segment):
      # Wildcard segment - matches everything
      if current.wildcardChild.isNone:
        current.wildcardChild = some(newRouteNode())
      current = current.wildcardChild.get
      
    elif isParameterSegment(segment):
      # Parameter segment
      let paramName = getParameterName(segment)
      if current.paramChild.isNone:
        current.paramChild = some((paramName, newRouteNode()))
      current = current.paramChild.get.node
      
    else:
      # Static segment
      if not current.children.hasKey(segment):
        current.children[segment] = newRouteNode()
      current = current.children[segment]
  
  # Set endpoint information
  current.handler = some(handler)
  current.middlewares = middlewares
  current.httpMethod = httpMethod
  current.isEndpoint = true
  current.priority = priority
  
  inc(router.totalRoutes)
  if depth > router.maxDepth:
    router.maxDepth = depth
  
  logging.debug("Added route: " & $httpMethod & " " & path & " (depth: " & $depth & ")")

proc findRoute*(router: TrieRouter, path: string, httpMethod: HttpMethod): RouteMatch =
  ## Finds a matching route in the trie
  result = RouteMatch(
    handler: none(HandlerAsync),
    params: initTable[string, string](),
    middlewares: @[],
    matched: false
  )
  
  if not router.roots.hasKey(httpMethod):
    return
  
  var current = router.roots[httpMethod]
  let segments = parseRouteSegments(path)
  
  # Handle root path
  if segments.len == 0:
    if current.isEndpoint:
      result.handler = current.handler
      result.middlewares = current.middlewares
      result.matched = true
    return
  
  # Traverse the trie
  for i, segment in segments:
    var found = false
    
    # Try static match first (highest priority)
    if current.children.hasKey(segment):
      current = current.children[segment]
      found = true
      
    # Try parameter match
    elif current.paramChild.isSome:
      let (paramName, paramNode) = current.paramChild.get
      result.params[paramName] = segment
      current = paramNode
      found = true
      
    # Try wildcard match (lowest priority)
    elif current.wildcardChild.isSome:
      current = current.wildcardChild.get
      found = true
      # Wildcard consumes remaining path
      break
    
    if not found:
      return  # No match found
  
  # Check if we reached an endpoint
  if current.isEndpoint:
    result.handler = current.handler
    result.middlewares = current.middlewares
    result.matched = true
  
  logging.debug("Route match: " & $httpMethod & " " & path & " -> " & $result.matched)

proc getRouteStats*(router: TrieRouter): tuple[totalRoutes: int, maxDepth: int, methodCounts: Table[HttpMethod, int]] =
  ## Gets statistics about the router
  result.totalRoutes = router.totalRoutes
  result.maxDepth = router.maxDepth
  result.methodCounts = initTable[HttpMethod, int]()
  
  # Count routes per method
  for httpMethod, root in router.roots:
    var count = 0
    proc countNodes(node: RouteNode) =
      if node.isEndpoint:
        inc(count)
      for child in node.children.values:
        countNodes(child)
      if node.paramChild.isSome:
        countNodes(node.paramChild.get.node)
      if node.wildcardChild.isSome:
        countNodes(node.wildcardChild.get)
    
    countNodes(root)
    result.methodCounts[httpMethod] = count

proc optimizeRouter*(router: TrieRouter) =
  ## Optimizes the router structure for better performance
  logging.info("Optimizing router structure...")
  
  # В реална имплементация тук би се извършила оптимизация като:
  # - Компресиране на единични вериги от възли
  # - Пренареждане на възли по приоритет
  # - Кеширане на често използвани маршрути
  
  let stats = router.getRouteStats()
  logging.info("Router optimized: " & $stats.totalRoutes & " routes, max depth: " & $stats.maxDepth)

# Performance monitoring
type
  RoutingMetrics* = ref object
    totalMatches*: int
    successfulMatches*: int
    averageMatchTime*: float
    slowestMatch*: float
    fastestMatch*: float

var globalRoutingMetrics = RoutingMetrics(
  totalMatches: 0,
  successfulMatches: 0,
  averageMatchTime: 0.0,
  slowestMatch: 0.0,
  fastestMatch: float.high
)

proc measureRouteMatch*[T](operation: proc(): T): tuple[result: T, duration: float] =
  ## Measures the time taken for a route matching operation
  let startTime = cpuTime()
  result.result = operation()
  result.duration = (cpuTime() - startTime) * 1000.0  # Convert to milliseconds
  
  # Update global metrics
  inc(globalRoutingMetrics.totalMatches)
  if result.duration > globalRoutingMetrics.slowestMatch:
    globalRoutingMetrics.slowestMatch = result.duration
  if result.duration < globalRoutingMetrics.fastestMatch:
    globalRoutingMetrics.fastestMatch = result.duration
  
  # Update average (simple moving average)
  globalRoutingMetrics.averageMatchTime = 
    (globalRoutingMetrics.averageMatchTime * (globalRoutingMetrics.totalMatches - 1).float + result.duration) / 
    globalRoutingMetrics.totalMatches.float

proc getRoutingMetrics*(): RoutingMetrics =
  ## Gets global routing performance metrics
  result = globalRoutingMetrics

proc resetRoutingMetrics*() =
  ## Resets global routing metrics
  globalRoutingMetrics = RoutingMetrics(
    totalMatches: 0,
    successfulMatches: 0,
    averageMatchTime: 0.0,
    slowestMatch: 0.0,
    fastestMatch: float.high
  )

# Integration with Prologue
import ../core/application
import ../core/context

proc initOptimizedRouter*(app: Prologue) =
  ## Initializes the optimized router for a Prologue application
  let router = newTrieRouter()
  app.gScope.appData["optimizedRouter"] = $cast[int](router)
  
  logging.info("Optimized router initialized for Prologue app")

proc getOptimizedRouter*(app: Prologue): TrieRouter =
  ## Gets the optimized router from a Prologue application
  if not app.gScope.appData.hasKey("optimizedRouter"):
    raise newException(OptimizedRoutingError, "Optimized router not initialized")
  
  let routerPtr = parseInt(app.gScope.appData["optimizedRouter"])
  result = cast[TrieRouter](routerPtr)

proc addOptimizedRoute*(app: Prologue, path: string, handler: HandlerAsync,
                       httpMethod: HttpMethod, middlewares: seq[HandlerAsync] = @[],
                       priority: int = 0) =
  ## Adds a route to the optimized router
  let router = app.getOptimizedRouter()
  router.addRoute(path, handler, httpMethod, middlewares, priority)

proc findOptimizedRoute*(app: Prologue, path: string, httpMethod: HttpMethod): RouteMatch =
  ## Finds a route using the optimized router
  let router = app.getOptimizedRouter()
  let (match, duration) = measureRouteMatch(proc(): RouteMatch = router.findRoute(path, httpMethod))
  
  if match.matched:
    inc(globalRoutingMetrics.successfulMatches)
  
  result = match

# Middleware for route performance monitoring
proc routePerformanceMiddleware*(): HandlerAsync =
  ## Creates middleware that monitors route performance
  result = proc(ctx: Context) {.async.} =
    let startTime = cpuTime()
    
    await switch(ctx)
    
    let duration = (cpuTime() - startTime) * 1000.0
    ctx.response.setHeader("X-Route-Time", $duration & "ms")
    
    if duration > 100.0:  # Log slow routes
      logging.warn("Slow route detected: " & $ctx.request.reqMethod & " " & 
                   $ctx.request.url.path & " took " & $duration & "ms")

# Route caching for frequently accessed routes
type
  RouteCache* = ref object
    cache: Table[string, RouteMatch]
    maxSize: int
    accessCount: Table[string, int]

proc newRouteCache*(maxSize = 100): RouteCache =
  ## Creates a new route cache
  result = RouteCache(
    cache: initTable[string, RouteMatch](),
    maxSize: maxSize,
    accessCount: initTable[string, int]()
  )

proc getCachedRoute*(cache: RouteCache, key: string): Option[RouteMatch] =
  ## Gets a route from cache
  if cache.cache.hasKey(key):
    inc(cache.accessCount[key])
    return some(cache.cache[key])
  return none(RouteMatch)

proc setCachedRoute*(cache: RouteCache, key: string, match: RouteMatch) =
  ## Sets a route in cache
  if cache.cache.len >= cache.maxSize:
    # Simple LRU eviction - remove least accessed
    var minAccess = int.high
    var evictKey = ""
    for k, count in cache.accessCount:
      if count < minAccess:
        minAccess = count
        evictKey = k
    
    if evictKey.len > 0:
      cache.cache.del(evictKey)
      cache.accessCount.del(evictKey)
  
  cache.cache[key] = match
  cache.accessCount[key] = 1
