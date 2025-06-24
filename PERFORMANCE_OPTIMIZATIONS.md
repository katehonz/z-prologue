# Performance Optimizations for Prologue / Оптимизации на производителността за Prologue

## English

### Overview

Performance optimizations are crucial for modern web frameworks to handle high traffic and provide responsive user experiences. This document outlines key performance optimizations for the Prologue framework, focusing on connection pooling and advanced caching mechanisms.

### 1. Connection Pooling

Connection pooling is a technique used to maintain a cache of database connections that can be reused when future requests to the database are required. This significantly reduces the overhead of establishing a new connection for each database operation.

#### Benefits of Connection Pooling

1. **Reduced Connection Overhead**: Eliminates the need to establish a new connection for each database operation.
2. **Improved Response Time**: Reusing existing connections reduces latency in database operations.
3. **Better Resource Management**: Controls the maximum number of connections to prevent database server overload.
4. **Connection Validation**: Ensures connections in the pool are valid before use.

#### Implementation Strategy

##### 1. Connection Pool Interface

```nim
type
  ConnectionPool* = ref object
    maxConnections: int
    minConnections: int
    connectionTimeout: int
    validationInterval: int
    connections: seq[DbConn]
    availableConnections: int
    lock: AsyncLock

proc newConnectionPool*(maxConnections = 10, minConnections = 2, 
                       connectionTimeout = 30000, 
                       validationInterval = 30000): ConnectionPool =
  result = ConnectionPool(
    maxConnections: maxConnections,
    minConnections: minConnections,
    connectionTimeout: connectionTimeout,
    validationInterval: validationInterval,
    connections: @[],
    availableConnections: 0,
    lock: newAsyncLock()
  )
  # Initialize minimum connections
  for i in 0..<minConnections:
    result.connections.add(openConnection())
    inc(result.availableConnections)
```

##### 2. Connection Acquisition and Release

```nim
proc getConnection*(pool: ConnectionPool): Future[DbConn] {.async.} =
  await pool.lock.acquire()
  try:
    if pool.availableConnections > 0:
      dec(pool.availableConnections)
      for i, conn in pool.connections:
        if not conn.inUse:
          conn.inUse = true
          return conn
    elif pool.connections.len < pool.maxConnections:
      let conn = openConnection()
      conn.inUse = true
      pool.connections.add(conn)
      return conn
    else:
      # Wait for a connection to become available
      # Implement timeout logic here
  finally:
    pool.lock.release()

proc releaseConnection*(pool: ConnectionPool, conn: DbConn) {.async.} =
  await pool.lock.acquire()
  try:
    for i, c in pool.connections:
      if c == conn:
        c.inUse = false
        inc(pool.availableConnections)
        break
  finally:
    pool.lock.release()
```

##### 3. Connection Validation and Cleanup

```nim
proc validateConnections*(pool: ConnectionPool) {.async.} =
  await pool.lock.acquire()
  try:
    var i = 0
    while i < pool.connections.len:
      let conn = pool.connections[i]
      if not conn.inUse:
        if not isValid(conn):
          pool.connections.delete(i)
          dec(pool.availableConnections)
          continue
      inc(i)
    
    # Ensure minimum connections
    while pool.availableConnections < pool.minConnections:
      pool.connections.add(openConnection())
      inc(pool.availableConnections)
  finally:
    pool.lock.release()
```

##### 4. Integration with Prologue

```nim
proc initConnectionPool*(app: Prologue, connectionString: string, 
                        maxConnections = 10, minConnections = 2) =
  let pool = newConnectionPool(maxConnections, minConnections)
  app.settings["connectionPool"] = pool
  
  # Add shutdown hook to close connections
  app.shutdownManager.addHandler(proc() {.async.} =
    let pool = app.settings["connectionPool"].getConnectionPool()
    for conn in pool.connections:
      if not conn.inUse:
        closeConnection(conn)
  )

proc withConnection*(ctx: Context, handler: proc(conn: DbConn): Future[void]): Future[void] {.async.} =
  let pool = ctx.app.settings["connectionPool"].getConnectionPool()
  let conn = await pool.getConnection()
  try:
    await handler(conn)
  finally:
    await pool.releaseConnection(conn)
```

#### Example Usage

```nim
import prologue
import prologue/db/connectionpool

let settings = newSettings(appName = "ConnectionPoolExample")
var app = newApp(settings)

app.initConnectionPool("localhost:5432:mydb:user:password", maxConnections = 20)

proc getUserData(ctx: Context) {.async.} =
  await ctx.withConnection(proc(conn: DbConn) {.async.} =
    let userId = ctx.getPathParams("id")
    let userData = await conn.query("SELECT * FROM users WHERE id = ?", userId)
    resp $userData
  )

app.get("/users/{id}", getUserData)
app.run()
```

### 2. Advanced Caching Mechanisms

Caching is essential for reducing database load and improving response times. Prologue can implement various caching strategies to optimize performance.

#### Caching Strategies

1. **In-Memory Caching**: Fast but limited by available memory and not shared between instances.
2. **Distributed Caching**: Using Redis or Memcached for shared caching across multiple instances.
3. **Multi-Level Caching**: Combining different caching strategies for optimal performance.
4. **Cache Invalidation**: Strategies to ensure cache consistency.

#### Implementation Strategy

##### 1. Cache Interface

```nim
type
  CacheKey* = string
  CacheValue* = string
  CacheTTL* = int  # Time to live in seconds

  CacheBackend* = ref object of RootObj
    
  InMemoryCache* = ref object of CacheBackend
    data: Table[CacheKey, tuple[value: CacheValue, expiry: int64]]
    
  RedisCache* = ref object of CacheBackend
    client: RedisClient
    
  MemcachedCache* = ref object of CacheBackend
    client: MemcachedClient

proc get*(cache: CacheBackend, key: CacheKey): Future[Option[CacheValue]] {.async, base.}
proc set*(cache: CacheBackend, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async, base.}
proc delete*(cache: CacheBackend, key: CacheKey): Future[bool] {.async, base.}
proc clear*(cache: CacheBackend): Future[bool] {.async, base.}
```

##### 2. In-Memory Cache Implementation

```nim
proc newInMemoryCache*(): InMemoryCache =
  result = InMemoryCache(
    data: initTable[CacheKey, tuple[value: CacheValue, expiry: int64]]()
  )

proc get*(cache: InMemoryCache, key: CacheKey): Future[Option[CacheValue]] {.async.} =
  if cache.data.hasKey(key):
    let (value, expiry) = cache.data[key]
    let now = getTime().toUnix()
    if expiry == 0 or expiry > now:
      return some(value)
    else:
      # Expired
      cache.data.del(key)
  return none(CacheValue)

proc set*(cache: InMemoryCache, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async.} =
  let expiry = if ttl > 0: getTime().toUnix() + ttl.int64 else: 0.int64
  cache.data[key] = (value, expiry)
  return true
```

##### 3. Redis Cache Implementation

```nim
proc newRedisCache*(url: string): RedisCache =
  result = RedisCache(
    client: newRedisClient(url)
  )

proc get*(cache: RedisCache, key: CacheKey): Future[Option[CacheValue]] {.async.} =
  try:
    let value = await cache.client.get(key)
    if value.len > 0:
      return some(value)
  except:
    # Handle Redis errors
    discard
  return none(CacheValue)

proc set*(cache: RedisCache, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async.} =
  try:
    if ttl > 0:
      return await cache.client.setex(key, ttl, value)
    else:
      return await cache.client.set(key, value)
  except:
    # Handle Redis errors
    return false
```

##### 4. Multi-Level Cache

```nim
type
  MultiLevelCache* = ref object of CacheBackend
    levels: seq[CacheBackend]

proc newMultiLevelCache*(levels: varargs[CacheBackend]): MultiLevelCache =
  result = MultiLevelCache(
    levels: @[]
  )
  for level in levels:
    result.levels.add(level)

proc get*(cache: MultiLevelCache, key: CacheKey): Future[Option[CacheValue]] {.async.} =
  for i, level in cache.levels:
    let value = await level.get(key)
    if value.isSome:
      # Propagate to higher levels
      for j in 0..<i:
        discard await cache.levels[j].set(key, value.get)
      return value
  return none(CacheValue)

proc set*(cache: MultiLevelCache, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async.} =
  var success = true
  for level in cache.levels:
    success = success and await level.set(key, value, ttl)
  return success
```

##### 5. Cache Middleware

```nim
proc cacheMiddleware*(backend: CacheBackend, ttl: CacheTTL = 300): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    # Only cache GET requests
    if ctx.request.reqMethod == HttpGet:
      let cacheKey = $ctx.request.url
      
      # Try to get from cache
      let cachedResponse = await backend.get(cacheKey)
      if cachedResponse.isSome:
        ctx.response.body = cachedResponse.get
        return
      
      # Process the request
      await ctx.next()
      
      # Cache the response
      if ctx.response.code == Http200:
        discard await backend.set(cacheKey, ctx.response.body, ttl)
    else:
      await ctx.next()
```

#### Example Usage

```nim
import prologue
import prologue/cache

let settings = newSettings(appName = "CachingExample")
var app = newApp(settings)

# Create cache backends
let memoryCache = newInMemoryCache()
let redisCache = newRedisCache("redis://localhost:6379")
let multiCache = newMultiLevelCache(memoryCache, redisCache)

# Apply caching middleware
app.use(cacheMiddleware(multiCache, ttl = 60))  # Cache for 60 seconds

proc getExpensiveData(ctx: Context) {.async.} =
  # This expensive operation will be cached
  let data = await performExpensiveOperation()
  resp data

app.get("/data", getExpensiveData)
app.run()
```

### 3. Lazy Loading

Lazy loading is a design pattern that defers the initialization of resources until they are actually needed. This can significantly improve the initial load time of applications.

#### Implementation Strategy

```nim
type
  LazyResource[T] = ref object
    loader: proc(): Future[T] {.async.}
    value: Option[T]
    initialized: bool

proc newLazyResource[T](loader: proc(): Future[T] {.async.}): LazyResource[T] =
  result = LazyResource[T](
    loader: loader,
    value: none(T),
    initialized: false
  )

proc get[T](resource: LazyResource[T]): Future[T] {.async.} =
  if not resource.initialized:
    let value = await resource.loader()
    resource.value = some(value)
    resource.initialized = true
  return resource.value.get
```

#### Example Usage

```nim
import prologue
import prologue/lazyloading

let settings = newSettings(appName = "LazyLoadingExample")
var app = newApp(settings)

# Create a lazy-loaded resource
let expensiveResource = newLazyResource(proc(): Future[string] {.async.} =
  # This would only be called when the resource is first accessed
  return await loadExpensiveResource()
)

proc getData(ctx: Context) {.async.} =
  # The resource is only loaded when needed
  let data = await expensiveResource.get()
  resp data

app.get("/data", getData)
app.run()
```

### 4. Optimized Routing Algorithm

An efficient routing algorithm is crucial for handling a large number of routes with minimal latency. Prologue can implement a trie-based routing algorithm for faster route matching.

#### Implementation Strategy

```nim
type
  RouteNode = ref object
    children: Table[string, RouteNode]
    paramChild: Option[tuple[name: string, node: RouteNode]]
    wildcardChild: Option[RouteNode]
    handler: Option[HandlerAsync]

  TrieRouter = ref object
    root: RouteNode

proc newTrieRouter(): TrieRouter =
  result = TrieRouter(
    root: RouteNode(
      children: initTable[string, RouteNode](),
      paramChild: none(tuple[name: string, node: RouteNode]),
      wildcardChild: none(RouteNode),
      handler: none(HandlerAsync)
    )
  )

proc addRoute(router: TrieRouter, path: string, handler: HandlerAsync) =
  var current = router.root
  let segments = path.split('/')
  
  for i, segment in segments:
    if segment.len == 0:
      continue
      
    if segment.startsWith('{') and segment.endsWith('}'):
      # Parameter segment
      let paramName = segment[1..^2]
      if current.paramChild.isNone:
        let newNode = RouteNode(
          children: initTable[string, RouteNode](),
          paramChild: none(tuple[name: string, node: RouteNode]),
          wildcardChild: none(RouteNode),
          handler: none(HandlerAsync)
        )
        current.paramChild = some((paramName, newNode))
      current = current.paramChild.get.node
    elif segment == "*":
      # Wildcard segment
      if current.wildcardChild.isNone:
        let newNode = RouteNode(
          children: initTable[string, RouteNode](),
          paramChild: none(tuple[name: string, node: RouteNode]),
          wildcardChild: none(RouteNode),
          handler: none(HandlerAsync)
        )
        current.wildcardChild = some(newNode)
      current = current.wildcardChild.get
    else:
      # Static segment
      if not current.children.hasKey(segment):
        current.children[segment] = RouteNode(
          children: initTable[string, RouteNode](),
          paramChild: none(tuple[name: string, node: RouteNode]),
          wildcardChild: none(RouteNode),
          handler: none(HandlerAsync)
        )
      current = current.children[segment]
  
  current.handler = some(handler)

proc findRoute(router: TrieRouter, path: string): tuple[handler: Option[HandlerAsync], params: Table[string, string]] =
  var 
    current = router.root
    params = initTable[string, string]()
    segments = path.split('/')
  
  for segment in segments:
    if segment.len == 0:
      continue
      
    # Try static match first
    if current.children.hasKey(segment):
      current = current.children[segment]
    # Then try parameter match
    elif current.paramChild.isSome:
      params[current.paramChild.get.name] = segment
      current = current.paramChild.get.node
    # Finally try wildcard match
    elif current.wildcardChild.isSome:
      current = current.wildcardChild.get
    else:
      # No match found
      return (none(HandlerAsync), params)
  
  return (current.handler, params)
```

#### Integration with Prologue

```nim
proc initOptimizedRouter*(app: Prologue) =
  let router = newTrieRouter()
  app.settings["optimizedRouter"] = router
  
  # Override the default route registration
  app.addRoute = proc(path: string, handler: HandlerAsync, httpMethod: HttpMethod) =
    let router = app.settings["optimizedRouter"].getTrieRouter()
    router.addRoute(httpMethod & " " & path, handler)
  
  # Override the default route matching
  app.findRoute = proc(ctx: Context): Future[void] {.async.} =
    let 
      router = app.settings["optimizedRouter"].getTrieRouter()
      path = ctx.request.path
      httpMethod = $ctx.request.reqMethod
      (handler, params) = router.findRoute(httpMethod & " " & path)
    
    if handler.isSome:
      for key, value in params:
        ctx.request.pathParams[key] = value
      await handler.get(ctx)
    else:
      ctx.response.code = Http404
```

#### Example Usage

```nim
import prologue
import prologue/routing/optimized

let settings = newSettings(appName = "OptimizedRoutingExample")
var app = newApp(settings)

# Initialize the optimized router
app.initOptimizedRouter()

# Routes will now use the optimized trie-based router
app.get("/users/{id}", getUserById)
app.get("/posts/{id}/comments", getPostComments)
app.get("/search/*", searchHandler)

app.run()
```

## Български

### Преглед

Оптимизациите на производителността са от решаващо значение за съвременните уеб фреймуърки, за да се справят с високия трафик и да осигурят отзивчиви потребителски изживявания. Този документ очертава ключови оптимизации на производителността за фреймуърка Prologue, фокусирайки се върху пулове за връзки и напреднали механизми за кеширане.

### 1. Пулове за връзки

Пуловете за връзки са техника, използвана за поддържане на кеш от връзки с бази данни, които могат да бъдат повторно използвани, когато са необходими бъдещи заявки към базата данни. Това значително намалява натоварването от установяването на нова връзка за всяка операция с базата данни.

#### Предимства на пуловете за връзки

1. **Намалено натоварване от връзки**: Елиминира необходимостта от установяване на нова връзка за всяка операция с базата данни.
2. **Подобрено време за отговор**: Повторното използване на съществуващи връзки намалява латентността в операциите с базата данни.
3. **По-добро управление на ресурсите**: Контролира максималния брой връзки, за да предотврати претоварване на сървъра на базата данни.
4. **Валидиране на връзките**: Гарантира, че връзките в пула са валидни преди използване.

#### Стратегия за имплементация

##### 1. Интерфейс на пула за връзки

```nim
type
  ConnectionPool* = ref object
    maxConnections: int
    minConnections: int
    connectionTimeout: int
    validationInterval: int
    connections: seq[DbConn]
    availableConnections: int
    lock: AsyncLock

proc newConnectionPool*(maxConnections = 10, minConnections = 2, 
                       connectionTimeout = 30000, 
                       validationInterval = 30000): ConnectionPool =
  result = ConnectionPool(
    maxConnections: maxConnections,
    minConnections: minConnections,
    connectionTimeout: connectionTimeout,
    validationInterval: validationInterval,
    connections: @[],
    availableConnections: 0,
    lock: newAsyncLock()
  )
  # Инициализиране на минимални връзки
  for i in 0..<minConnections:
    result.connections.add(openConnection())
    inc(result.availableConnections)
```

##### 2. Придобиване и освобождаване на връзки

```nim
proc getConnection*(pool: ConnectionPool): Future[DbConn] {.async.} =
  await pool.lock.acquire()
  try:
    if pool.availableConnections > 0:
      dec(pool.availableConnections)
      for i, conn in pool.connections:
        if not conn.inUse:
          conn.inUse = true
          return conn
    elif pool.connections.len < pool.maxConnections:
      let conn = openConnection()
      conn.inUse = true
      pool.connections.add(conn)
      return conn
    else:
      # Изчакване връзка да стане достъпна
      # Имплементиране на логика за таймаут тук
  finally:
    pool.lock.release()

proc releaseConnection*(pool: ConnectionPool, conn: DbConn) {.async.} =
  await pool.lock.acquire()
  try:
    for i, c in pool.connections:
      if c == conn:
        c.inUse = false
        inc(pool.availableConnections)
        break
  finally:
    pool.lock.release()
```

##### 3. Валидиране и почистване на връзки

```nim
proc validateConnections*(pool: ConnectionPool) {.async.} =
  await pool.lock.acquire()
  try:
    var i = 0
    while i < pool.connections.len:
      let conn = pool.connections[i]
      if not conn.inUse:
        if not isValid(conn):
          pool.connections.delete(i)
          dec(pool.availableConnections)
          continue
      inc(i)
    
    # Осигуряване на минимални връзки
    while pool.availableConnections < pool.minConnections:
      pool.connections.add(openConnection())
      inc(pool.availableConnections)
  finally:
    pool.lock.release()
```

##### 4. Интеграция с Prologue

```nim
proc initConnectionPool*(app: Prologue, connectionString: string, 
                        maxConnections = 10, minConnections = 2) =
  let pool = newConnectionPool(maxConnections, minConnections)
  app.settings["connectionPool"] = pool
  
  # Добавяне на хендлър за изключване за затваряне на връзки
  app.shutdownManager.addHandler(proc() {.async.} =
    let pool = app.settings["connectionPool"].getConnectionPool()
    for conn in pool.connections:
      if not conn.inUse:
        closeConnection(conn)
  )

proc withConnection*(ctx: Context, handler: proc(conn: DbConn): Future[void]): Future[void] {.async.} =
  let pool = ctx.app.settings["connectionPool"].getConnectionPool()
  let conn = await pool.getConnection()
  try:
    await handler(conn)
  finally:
    await pool.releaseConnection(conn)
```

#### Пример за използване

```nim
import prologue
import prologue/db/connectionpool

let settings = newSettings(appName = "ConnectionPoolExample")
var app = newApp(settings)

app.initConnectionPool("localhost:5432:mydb:user:password", maxConnections = 20)

proc getUserData(ctx: Context) {.async.} =
  await ctx.withConnection(proc(conn: DbConn) {.async.} =
    let userId = ctx.getPathParams("id")
    let userData = await conn.query("SELECT * FROM users WHERE id = ?", userId)
    resp $userData
  )

app.get("/users/{id}", getUserData)
app.run()
```

### 2. Напреднали механизми за кеширане

Кеширането е от съществено значение за намаляване на натоварването на базата данни и подобряване на времената за отговор. Prologue може да имплементира различни стратегии за кеширане за оптимизиране на производителността.

#### Стратегии за кеширане

1. **Кеширане в паметта**: Бързо, но ограничено от наличната памет и не се споделя между инстанции.
2. **Разпределено кеширане**: Използване на Redis или Memcached за споделено кеширане между множество инстанции.
3. **Многослойно кеширане**: Комбиниране на различни стратегии за кеширане за оптимална производителност.
4. **Инвалидиране на кеша**: Стратегии за осигуряване на консистентност на кеша.

#### Стратегия за имплементация

##### 1. Интерфейс на кеша

```nim
type
  CacheKey* = string
  CacheValue* = string
  CacheTTL* = int  # Време на живот в секунди

  CacheBackend* = ref object of RootObj
    
  InMemoryCache* = ref object of CacheBackend
    data: Table[CacheKey, tuple[value: CacheValue, expiry: int64]]
    
  RedisCache* = ref object of CacheBackend
    client: RedisClient
    
  MemcachedCache* = ref object of CacheBackend
    client: MemcachedClient

proc get*(cache: CacheBackend, key: CacheKey): Future[Option[CacheValue]] {.async, base.}
proc set*(cache: CacheBackend, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async, base.}
proc delete*(cache: CacheBackend, key: CacheKey): Future[bool] {.async, base.}
proc clear*(cache: CacheBackend): Future[bool] {.async, base.}
```

##### 2. Имплементация на кеш в паметта

```nim
proc newInMemoryCache*(): InMemoryCache =
  result = InMemoryCache(
    data: initTable[CacheKey, tuple[value: CacheValue, expiry: int64]]()
  )

proc get*(cache: InMemoryCache, key: CacheKey): Future[Option[CacheValue]] {.async.} =
  if cache.data.hasKey(key):
    let (value, expiry) = cache.data[key]
    let now = getTime().toUnix()
    if expiry == 0 or expiry > now:
      return some(value)
    else:
      # Изтекъл
      cache.data.del(key)
  return none(CacheValue)

proc set*(cache: InMemoryCache, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async.} =
  let expiry = if ttl > 0: getTime().toUnix() + ttl.int64 else: 0.int64
  cache.data[key] = (value, expiry)
  return true
```

##### 3. Имплементация на Redis кеш

```nim
proc newRedisCache*(url: string): RedisCache =
  result = RedisCache(
    client: newRedisClient(url)
  )

proc get*(cache: RedisCache, key: CacheKey): Future[Option[CacheValue]] {.async.} =
  try:
    let value = await cache.client.get(key)
    if value.len > 0:
      return some(value)
  except:
    # Обработка на Redis грешки
    discard
  return none(CacheValue)

proc set*(cache: RedisCache, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async.} =
  try:
    if ttl > 0:
      return await cache.client.setex(key, ttl, value)
    else:
      return await cache.client.set(key, value)
  except:
    # Обработка на Redis грешки
    return false
```

##### 4. Многослоен кеш

```nim
type
  MultiLevelCache* = ref object of CacheBackend
    levels: seq[CacheBackend]

proc newMultiLevelCache*(levels: varargs[CacheBackend]): MultiLevelCache =
  result = MultiLevelCache(
    levels: @[]
  )
  for level in levels:
    result.levels.add(level)

proc get*(cache: MultiLevelCache, key: CacheKey): Future[Option[CacheValue]] {.async.} =
  for i, level in cache.levels:
    let value = await level.get(key)
    if value.isSome:
      # Разпространяване към по-високи нива
      for j in 0..<i:
        discard await cache.levels[j].set(key, value.get)
      return value
  return none(CacheValue)

proc set*(cache: MultiLevelCache, key: CacheKey, value: CacheValue, ttl: CacheTTL = 0): Future[bool] {.async.} =
  var success = true
  for level in cache.levels:
    success = success and await level.set(key, value, ttl)
  return success
```

##### 5. Middleware за кеширане

```nim
proc cacheMiddleware*(backend: CacheBackend, ttl: CacheTTL = 300): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    # Кеширане само на GET заявки
    if ctx.request.reqMethod == HttpGet:
      let cacheKey = $ctx.request.url
      
      # Опит за вземане от кеша
      let cachedResponse = await backend.get(cacheKey)
      if cachedResponse.isSome:
        ctx