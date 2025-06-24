## Прост пример за оптимизации на производителността в Prologue
## Този пример демонстрира основни техники за подобряване на производителността

import std/[asyncdispatch, json, strutils, times]
import prologue

# === ROUTE HANDLERS ===

proc getUserById(ctx: Context) {.async, gcsafe.} =
  ## Получава потребител по ID
  let userId = ctx.getPathParams("id", "")
  
  # Симулира заявка към база данни
  await sleepAsync(50) # 50ms забавяне
  
  # Примерни данни (в реалното приложение биха били от база данни)
  case userId:
  of "1":
    ctx.response.body = """{"id": 1, "name": "Иван Петров", "email": "ivan@example.com"}"""
  of "2":
    ctx.response.body = """{"id": 2, "name": "Мария Георгиева", "email": "maria@example.com"}"""
  of "3":
    ctx.response.body = """{"id": 3, "name": "Петър Димитров", "email": "peter@example.com"}"""
  else:
    ctx.response.code = Http404
    ctx.response.body = """{"error": "User not found"}"""
  
  ctx.response.headers["Content-Type"] = "application/json"

proc getAllUsers(ctx: Context) {.async, gcsafe.} =
  ## Получава всички потребители
  # Симулира заявка към база данни
  await sleepAsync(100) # 100ms забавяне
  
  let usersJson = """{
    "users": [
      {"id": 1, "name": "Иван Петров", "email": "ivan@example.com"},
      {"id": 2, "name": "Мария Георгиева", "email": "maria@example.com"},
      {"id": 3, "name": "Петър Димитров", "email": "peter@example.com"}
    ]
  }"""
  
  ctx.response.body = usersJson
  ctx.response.headers["Content-Type"] = "application/json"

proc getMetricsHandler(ctx: Context) {.async, gcsafe.} =
  ## Връща метрики за производителност
  let response = """{
    "status": "running",
    "users_count": 3,
    "timestamp": """ & "\"" & $now() & "\"" & """
  }"""
  
  ctx.response.body = response
  ctx.response.headers["Content-Type"] = "application/json"

proc healthCheck(ctx: Context) {.async, gcsafe.} =
  ## Проверка за здравето на приложението
  let response = """{
    "status": "healthy",
    "timestamp": """ & "\"" & $now() & "\"" & """,
    "uptime": "running"
  }"""
  
  ctx.response.body = response
  ctx.response.headers["Content-Type"] = "application/json"

# === MIDDLEWARE ЗА ПРОИЗВОДИТЕЛНОСТ ===

proc performanceMiddleware(): HandlerAsync =
  ## Middleware за мониторинг на производителността
  result = proc (ctx: Context) {.async, gcsafe.} =
    let startTime = epochTime()
    
    # Продължава към следващия middleware/handler
    await switch(ctx)
    
    let endTime = epochTime()
    let requestTime = endTime - startTime
    
    # Добавя header с времето за обработка
    ctx.response.headers["X-Response-Time"] = $(requestTime * 1000) & "ms"

# === ГЛАВНА ФУНКЦИЯ ===

proc main() {.async.} =
  # Създава Prologue приложение
  var app = newApp()
  
  # Добавя middleware за производителност
  app.use(performanceMiddleware())
  
  # Дефинира маршрути
  app.get("/users/{id}", getUserById)
  app.get("/users", getAllUsers)
  app.get("/metrics", getMetricsHandler)
  app.get("/health", healthCheck)
  
  # Добавя основен маршрут
  app.get("/", proc (ctx: Context) {.async, gcsafe.} =
    ctx.response.body = """
    <h1>Prologue Performance Demo</h1>
    <p>Налични endpoints:</p>
    <ul>
      <li><a href="/users">GET /users</a> - Всички потребители</li>
      <li>GET /users/1 - Потребител с ID 1</li>
      <li>GET /users/2 - Потребител с ID 2</li>
      <li>GET /users/3 - Потребител с ID 3</li>
      <li><a href="/metrics">GET /metrics</a> - Метрики за производителност</li>
      <li><a href="/health">GET /health</a> - Проверка за здраве</li>
    </ul>
    <p>Този пример демонстрира:</p>
    <ul>
      <li>Middleware за мониторинг на времето за отговор</li>
      <li>Асинхронни операции</li>
      <li>JSON API endpoints</li>
      <li>Симулация на забавяне на база данни</li>
    </ul>
    """)
  
  echo "🚀 Сървърът стартира на http://localhost:8080"
  echo "📊 Оптимизациите за производителност са активни"
  echo "⏱️  Middleware за мониторинг на времето е включен"
  
  app.run()

when isMainModule:
  waitFor main()