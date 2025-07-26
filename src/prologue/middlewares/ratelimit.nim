import std/[times, tables, asyncdispatch, options, httpcore]
import ../core/[context, middlewaresbase, httpexception, response]
import ../cache/lrucache

type
  RateLimitStrategy* = enum
    FixedWindow
    SlidingWindow
    TokenBucket

  RateLimitConfig* = object
    maxRequests*: int
    windowSeconds*: float
    strategy*: RateLimitStrategy
    keyExtractor*: proc(ctx: Context): string
    skipCondition*: proc(ctx: Context): bool
    onLimitExceeded*: proc(ctx: Context): Future[void]

  TokenBucketData = object
    tokens: float
    lastRefill: float

  RateLimiter* = ref object
    config: RateLimitConfig
    fixedWindowCache: LRUCache[string, tuple[count: int, resetTime: float]]
    slidingWindowCache: LRUCache[string, seq[float]]
    tokenBucketCache: LRUCache[string, TokenBucketData]

proc defaultKeyExtractor(ctx: Context): string =
  result = $ctx.request.reqMethod & ":" & ctx.request.path
  if ctx.request.headers.hasKey("X-Forwarded-For"):
    result &= ":" & ctx.request.headers["X-Forwarded-For"]
  elif ctx.request.headers.hasKey("X-Real-IP"):
    result &= ":" & ctx.request.headers["X-Real-IP"]
  else:
    result &= ":" & ctx.request.ip

proc defaultOnLimitExceeded(ctx: Context) {.async.} =
  ctx.response.code = Http429
  ctx.response.headers["Retry-After"] = "60"
  ctx.response.headers["X-RateLimit-Limit"] = $ctx.ctxData.getOrDefault("ratelimit.limit", "0")
  ctx.response.headers["X-RateLimit-Remaining"] = "0"
  ctx.response.headers["X-RateLimit-Reset"] = $ctx.ctxData.getOrDefault("ratelimit.reset", "0")
  resp jsonResponse(%*{
    "error": "Too Many Requests",
    "message": "Rate limit exceeded. Please try again later.",
    "retryAfter": 60
  }, Http429)

proc newRateLimiter*(
  maxRequests = 100,
  windowSeconds = 60.0,
  strategy = FixedWindow,
  keyExtractor: proc(ctx: Context): string = nil,
  skipCondition: proc(ctx: Context): bool = nil,
  onLimitExceeded: proc(ctx: Context): Future[void] = nil
): RateLimiter =
  new(result)
  result.config = RateLimitConfig(
    maxRequests: maxRequests,
    windowSeconds: windowSeconds,
    strategy: strategy,
    keyExtractor: if keyExtractor.isNil: defaultKeyExtractor else: keyExtractor,
    skipCondition: skipCondition,
    onLimitExceeded: if onLimitExceeded.isNil: defaultOnLimitExceeded else: onLimitExceeded
  )
  
  case strategy
  of FixedWindow:
    result.fixedWindowCache = newLRUCache[string, tuple[count: int, resetTime: float]](1000)
  of SlidingWindow:
    result.slidingWindowCache = newLRUCache[string, seq[float]](1000)
  of TokenBucket:
    result.tokenBucketCache = newLRUCache[string, TokenBucketData](1000)

proc checkFixedWindow(limiter: RateLimiter, key: string, now: float): tuple[allowed: bool, remaining: int, resetTime: float] =
  let data = limiter.fixedWindowCache.get(key)
  
  if data.isSome:
    let (count, resetTime) = data.get()
    if now >= resetTime:
      limiter.fixedWindowCache.put(key, (1, now + limiter.config.windowSeconds))
      return (true, limiter.config.maxRequests - 1, now + limiter.config.windowSeconds)
    elif count < limiter.config.maxRequests:
      limiter.fixedWindowCache.put(key, (count + 1, resetTime))
      return (true, limiter.config.maxRequests - count - 1, resetTime)
    else:
      return (false, 0, resetTime)
  else:
    limiter.fixedWindowCache.put(key, (1, now + limiter.config.windowSeconds))
    return (true, limiter.config.maxRequests - 1, now + limiter.config.windowSeconds)

proc checkSlidingWindow(limiter: RateLimiter, key: string, now: float): tuple[allowed: bool, remaining: int, resetTime: float] =
  let windowStart = now - limiter.config.windowSeconds
  var timestamps = limiter.slidingWindowCache.get(key).get(@[])
  
  timestamps = timestamps.filterIt(it > windowStart)
  
  if timestamps.len < limiter.config.maxRequests:
    timestamps.add(now)
    limiter.slidingWindowCache.put(key, timestamps)
    return (true, limiter.config.maxRequests - timestamps.len, now + limiter.config.windowSeconds)
  else:
    return (false, 0, timestamps[0] + limiter.config.windowSeconds)

proc checkTokenBucket(limiter: RateLimiter, key: string, now: float): tuple[allowed: bool, remaining: int, resetTime: float] =
  let refillRate = limiter.config.maxRequests.float / limiter.config.windowSeconds
  var data = limiter.tokenBucketCache.get(key).get(
    TokenBucketData(tokens: limiter.config.maxRequests.float, lastRefill: now)
  )
  
  let timePassed = now - data.lastRefill
  let tokensToAdd = timePassed * refillRate
  data.tokens = min(data.tokens + tokensToAdd, limiter.config.maxRequests.float)
  data.lastRefill = now
  
  if data.tokens >= 1.0:
    data.tokens -= 1.0
    limiter.tokenBucketCache.put(key, data)
    return (true, data.tokens.int, now + (1.0 / refillRate))
  else:
    limiter.tokenBucketCache.put(key, data)
    let timeToNextToken = (1.0 - data.tokens) / refillRate
    return (false, 0, now + timeToNextToken)

proc rateLimitMiddleware*(limiter: RateLimiter): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if not limiter.config.skipCondition.isNil and limiter.config.skipCondition(ctx):
      await switch(ctx)
      return
    
    let key = limiter.config.keyExtractor(ctx)
    let now = epochTime()
    
    let (allowed, remaining, resetTime) = case limiter.config.strategy
      of FixedWindow: limiter.checkFixedWindow(key, now)
      of SlidingWindow: limiter.checkSlidingWindow(key, now)
      of TokenBucket: limiter.checkTokenBucket(key, now)
    
    ctx.ctxData["ratelimit.limit"] = $limiter.config.maxRequests
    ctx.ctxData["ratelimit.remaining"] = $remaining
    ctx.ctxData["ratelimit.reset"] = $resetTime.int
    
    ctx.response.headers["X-RateLimit-Limit"] = $limiter.config.maxRequests
    ctx.response.headers["X-RateLimit-Remaining"] = $remaining
    ctx.response.headers["X-RateLimit-Reset"] = $resetTime.int
    
    if allowed:
      await switch(ctx)
    else:
      await limiter.config.onLimitExceeded(ctx)

proc rateLimitByIP*(maxRequests = 100, windowSeconds = 60.0, strategy = FixedWindow): HandlerAsync =
  let limiter = newRateLimiter(maxRequests, windowSeconds, strategy)
  return rateLimitMiddleware(limiter)

proc rateLimitByUser*(
  maxRequests = 100, 
  windowSeconds = 60.0, 
  strategy = FixedWindow,
  userIdExtractor: proc(ctx: Context): string
): HandlerAsync =
  let limiter = newRateLimiter(
    maxRequests, 
    windowSeconds, 
    strategy,
    keyExtractor = userIdExtractor
  )
  return rateLimitMiddleware(limiter)

proc rateLimitByEndpoint*(
  endpoints: Table[string, tuple[maxRequests: int, windowSeconds: float]],
  strategy = FixedWindow
): HandlerAsync =
  var limiters = initTable[string, RateLimiter]()
  
  for endpoint, config in endpoints:
    limiters[endpoint] = newRateLimiter(
      config.maxRequests,
      config.windowSeconds,
      strategy,
      keyExtractor = proc(ctx: Context): string = 
        $ctx.request.reqMethod & ":" & endpoint & ":" & ctx.request.ip
    )
  
  result = proc(ctx: Context) {.async.} =
    let path = ctx.request.path
    for endpoint, limiter in limiters:
      if path.startsWith(endpoint):
        await rateLimitMiddleware(limiter)(ctx)
        return
    
    await switch(ctx)