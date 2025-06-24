## Опростени оптимизации на производителността за Prologue
## Този модул предоставя основни функции за подобряване на производителността

import std/[tables, times, json, asyncdispatch, strutils, logging]
import prologue

type
  # Прост кеш за съхранение на данни в паметта
  SimpleCache* = ref object
    data*: Table[string, string]
    timestamps*: Table[string, float]
    ttl*: float

  # Основни метрики за производителност
  PerformanceMetrics* = object
    requestCount*: int
    totalTime*: float
    averageTime*: float

# Глобални променливи
var
  globalCache* = SimpleCache(data: initTable[string, string](), 
                            timestamps: initTable[string, float](), 
                            ttl: 300.0) # 5 минути TTL
  performanceMetrics* = PerformanceMetrics()

# === КЕШИРАНЕ ===

proc newSimpleCache*(ttl: float = 300.0): SimpleCache =
  ## Създава нов прост кеш с указано време на живот
  result = SimpleCache(
    data: initTable[string, string](),
    timestamps: initTable[string, float](),
    ttl: ttl
  )

proc isExpired(cache: SimpleCache, key: string): bool =
  ## Проверява дали ключът е изтекъл
  if key notin cache.timestamps:
    return true
  let now = epochTime()
  let timestamp = cache.timestamps[key]
  return (now - timestamp) > cache.ttl

proc set*(cache: SimpleCache, key: string, value: string) =
  ## Задава стойност в кеша
  cache.data[key] = value
  cache.timestamps[key] = epochTime()

proc get*(cache: SimpleCache, key: string): string =
  ## Получава стойност от кеша
  if key in cache.data and not cache.isExpired(key):
    return cache.data[key]
  else:
    # Премахва изтеклите записи
    if key in cache.data:
      cache.data.del(key)
      cache.timestamps.del(key)
    return ""

proc has*(cache: SimpleCache, key: string): bool =
  ## Проверява дали ключът съществува и не е изтекъл
  return key in cache.data and not cache.isExpired(key)

proc clear*(cache: SimpleCache) =
  ## Изчиства целия кеш
  cache.data.clear()
  cache.timestamps.clear()

proc cleanup*(cache: SimpleCache) =
  ## Премахва изтеклите записи
  let now = epochTime()
  var keysToRemove: seq[string] = @[]
  
  for key, timestamp in cache.timestamps:
    if (now - timestamp) > cache.ttl:
      keysToRemove.add(key)
  
  for key in keysToRemove:
    cache.data.del(key)
    cache.timestamps.del(key)

# === MIDDLEWARE ЗА КЕШИРАНЕ ===

proc cacheMiddleware*(cache: SimpleCache = globalCache): HandlerAsync =
  ## Middleware за автоматично кеширане на GET заявки
  result = proc (ctx: Context) {.async.} =
    if ctx.request.reqMethod == HttpGet:
      let cacheKey = $ctx.request.url
      let cachedResponse = cache.get(cacheKey)
      
      if cachedResponse != "":
        # Кеширан отговор намерен
        ctx.response.body = cachedResponse
        ctx.response.headers["X-Cache"] = "HIT"
        debug("Cache HIT for: " & cacheKey)
        return
      
      # Продължава към следващия middleware/handler
      await switch(ctx)
      
      # Кешира отговора ако е успешен
      if ctx.response.code == Http200 and ctx.response.body.len > 0:
        cache.set(cacheKey, ctx.response.body)
        ctx.response.headers["X-Cache"] = "MISS"
        debug("Cache MISS for: " & cacheKey)
    else:
      # Не кешира не-GET заявки
      await switch(ctx)

# === МОНИТОРИНГ НА ПРОИЗВОДИТЕЛНОСТТА ===

proc performanceMiddleware*(): HandlerAsync =
  ## Middleware за мониторинг на производителността
  result = proc (ctx: Context) {.async.} =
    let startTime = epochTime()
    
    # Продължава към следващия middleware/handler
    await switch(ctx)
    
    let endTime = epochTime()
    let requestTime = endTime - startTime
    
    # Обновява метриките
    performanceMetrics.requestCount += 1
    performanceMetrics.totalTime += requestTime
    performanceMetrics.averageTime = performanceMetrics.totalTime / performanceMetrics.requestCount.float
    
    # Добавя header с времето за обработка
    ctx.response.headers["X-Response-Time"] = $(requestTime * 1000) & "ms"
    
    debug("Request processed in: " & $(requestTime * 1000) & "ms")

# === ПОМОЩНИ ФУНКЦИИ ===

proc getMetrics*(): PerformanceMetrics =
  ## Връща текущите метрики за производителност
  return performanceMetrics

proc resetMetrics*() =
  ## Нулира метриките за производителност
  performanceMetrics = PerformanceMetrics()

proc getCacheStats*(cache: SimpleCache = globalCache): JsonNode =
  ## Връща статистики за кеша
  cache.cleanup() # Почиства изтеклите записи преди статистиките
  
  return %*{
    "total_keys": cache.data.len,
    "ttl_seconds": cache.ttl,
    "cache_type": "simple_memory"
  }

# === КОНФИГУРАЦИЯ ===

type
  PerformanceConfig* = object
    enableCaching*: bool
    cacheTTL*: float
    enableMetrics*: bool
    logLevel*: Level

proc defaultPerformanceConfig*(): PerformanceConfig =
  ## Връща конфигурация по подразбиране
  result = PerformanceConfig(
    enableCaching: true,
    cacheTTL: 300.0, # 5 минути
    enableMetrics: true,
    logLevel: lvlInfo
  )

proc applyPerformanceOptimizations*(app: var Prologue, config: PerformanceConfig = defaultPerformanceConfig()) =
  ## Прилага оптимизациите за производителност към приложението
  
  # Настройва TTL на глобалния кеш
  globalCache.ttl = config.cacheTTL
  
  # Добавя middleware за производителност
  if config.enableMetrics:
    app.use(performanceMiddleware())
  
  # Добавя middleware за кеширане
  if config.enableCaching:
    app.use(cacheMiddleware(globalCache))
  
  # Настройва логирането
  addHandler(newConsoleLogger(config.logLevel))
  
  info("Performance optimizations applied successfully")