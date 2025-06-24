import std/[asyncdispatch, json, times, strformat, options]
import prologue
import prologue/auth/jwt

# Пример данных пользователей (в реальном приложении это будет база данных)
let users = {
  "user1": (password: "password1", roles: @["user"]),
  "admin": (password: "admin123", roles: @["user", "admin"])
}.toTable

# Настройки JWT
let jwtOptions = newJWTOptions(
  secret = "your-secret-key-should-be-long-and-secure",
  algorithm = JWTAlgorithm.HS256,
  issuer = some("prologue-example"),
  audience = some("prologue-users"),
  expireIn = some(3600)  # 1 час
)

# Создаем middleware для JWT
let jwtMiddleware = newJWTMiddleware(
  options = jwtOptions,
  excludePaths = @["/login", "/", "/static/"]
)

# Обработчик для главной страницы
proc home(ctx: Context) {.async.} =
  resp """
  <html>
  <head>
    <title>JWT Auth Example</title>
    <style>
      body { font-family: Arial, sans-serif; margin: 40px; line-height: 1.6; }
      h1 { color: #333; }
      form { margin: 20px 0; padding: 20px; border: 1px solid #ddd; border-radius: 5px; max-width: 400px; }
      label { display: block; margin-bottom: 5px; }
      input[type="text"], input[type="password"] { width: 100%; padding: 8px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 3px; }
      button { background: #4CAF50; color: white; border: none; padding: 10px 15px; border-radius: 3px; cursor: pointer; }
      button:hover { background: #45a049; }
      .error { color: red; margin-bottom: 15px; }
      .success { color: green; margin-bottom: 15px; }
      pre { background: #f4f4f4; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
  </head>
  <body>
    <h1>JWT Authentication Example</h1>
    <p>This example demonstrates JWT authentication in Prologue.</p>
    
    <h2>Login</h2>
    <form action="/login" method="post">
      <label for="username">Username:</label>
      <input type="text" id="username" name="username" required>
      
      <label for="password">Password:</label>
      <input type="password" id="password" name="password" required>
      
      <button type="submit">Login</button>
    </form>
    
    <h2>Protected Endpoints</h2>
    <ul>
      <li><a href="/api/user">User Profile</a> - Requires authentication</li>
      <li><a href="/api/admin">Admin Panel</a> - Requires admin role</li>
    </ul>
    
    <h2>Test Your Token</h2>
    <p>After login, you'll receive a token. Use it to access protected endpoints:</p>
    <pre>
    # Using curl
    curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/user
    </pre>
  </body>
  </html>
  """

# Обработчик для входа
proc login(ctx: Context) {.async.} =
  if ctx.request.reqMethod == HttpPost:
    let 
      username = ctx.getPostParams("username")
      password = ctx.getPostParams("password")
    
    if username.len == 0 or password.len == 0:
      resp "Username and password are required", Http400
      return
    
    if users.hasKey(username) and users[username].password == password:
      # Создаем JWT токен
      let claims = %* {
        "sub": username,
        "roles": users[username].roles
      }
      
      let token = createToken(jwtOptions, claims)
      
      # Возвращаем токен
      resp %* {
        "success": true,
        "token": token,
        "expires_in": jwtOptions.expireIn.get,
        "token_type": "Bearer"
      }
    else:
      resp %* {"success": false, "error": "Invalid username or password"}, Http401
  else:
    resp "Method not allowed", Http405

# Обработчик для профиля пользователя (требует аутентификации)
proc userProfile(ctx: Context) {.async.} =
  try:
    let claims = getJWTClaims(ctx)
    let username = claims["sub"].getStr()
    
    resp %* {
      "username": username,
      "roles": claims["roles"]
    }
  except JWTError:
    resp "Unauthorized", Http401

# Обработчик для админ-панели (требует роли admin)
proc adminPanel(ctx: Context) {.async.} =
  try:
    if not hasJWTRole(ctx, "admin"):
      resp "Forbidden: Admin role required", Http403
      return
    
    resp %* {
      "message": "Welcome to the admin panel",
      "server_time": now().format("yyyy-MM-dd HH:mm:ss")
    }
  except JWTError:
    resp "Unauthorized", Http401

# Инициализация приложения
proc main() =
  # Загружаем настройки из .env файла или используем значения по умолчанию
  let settings = newSettings(
    appName = "JWT Auth Example",
    debug = true,
    port = Port(8080)
  )
  
  var app = newApp(settings = settings)
  
  # Добавляем middleware для JWT
  app.use(jwtMiddleware.jwtMiddleware)
  
  # Добавляем маршруты
  app.get("/", home)
  app.post("/login", login)
  app.get("/api/user", userProfile)
  app.get("/api/admin", adminPanel)
  
  # Запускаем приложение
  app.run()

when isMainModule:
  main()