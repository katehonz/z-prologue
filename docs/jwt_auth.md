# JWT Authentication / JWT Аутентификация

## English

### Overview

The JWT Authentication module provides functionality for creating, verifying, and using JSON Web Tokens (JWT) for authentication and authorization in Prologue applications. JWT is a compact, URL-safe means of representing claims to be transferred between two parties.

### Features

- Create and verify JWT tokens
- Middleware for automatic token verification
- Support for different signature algorithms (HS256, HS384, HS512)
- Role-based authorization
- Flexible token extraction from headers, query parameters, or cookies

### Usage

```nim
import prologue
import prologue/auth/jwt

# Create JWT options
let jwtOptions = newJWTOptions(
  secret = "your-secret-key",
  algorithm = JWTAlgorithm.HS256,
  issuer = some("prologue"),
  audience = some("users"),
  expireIn = some(3600)  # 1 hour
)

# Create JWT middleware
let jwtMiddleware = newJWTMiddleware(
  options = jwtOptions,
  excludePaths = @["/login", "/", "/static/"]
)

# Create a JWT token
let claims = %* {
  "sub": "user123",
  "name": "John Doe",
  "roles": ["user", "admin"]
}

let token = createToken(jwtOptions, claims)

# Verify a JWT token
let verified = verifyToken(jwtOptions, token)

# Use JWT middleware in your application
var app = newApp()
app.use(jwtMiddleware.jwtMiddleware)

# Access JWT claims in a handler
proc protectedHandler(ctx: Context) {.async.} =
  let claims = getJWTClaims(ctx)
  let username = claims["sub"].getStr()
  
  # Check if user has a specific role
  if hasJWTRole(ctx, "admin"):
    # Admin-only functionality
    resp "Admin area"
  else:
    resp "User area"

app.get("/protected", protectedHandler)
```

### API Reference

#### Types

- `JWTAlgorithm`: Enum for supported signature algorithms (HS256, HS384, HS512)
- `JWTClaims`: JSON payload of a JWT token
- `JWTOptions`: Configuration options for JWT
- `JWTMiddleware`: Middleware for JWT authentication

#### Functions

- `newJWTOptions(secret, algorithm, issuer, audience, expireIn)`: Creates new JWT options
- `createToken(options, claims)`: Creates a JWT token
- `verifyToken(options, token)`: Verifies a JWT token and returns its claims
- `extractToken(ctx, tokenLocation)`: Extracts a JWT token from a request
- `newJWTMiddleware(options, tokenLocation, excludePaths)`: Creates a new JWT middleware
- `jwtMiddleware(middleware)`: Creates a handler for JWT authentication
- `getJWTClaims(ctx)`: Gets JWT claims from context
- `getJWTSubject(ctx)`: Gets the subject (sub) from JWT claims
- `hasJWTRole(ctx, role)`: Checks if the user has a specific role

## Български

### Преглед

Модулът JWT Аутентификация предоставя функционалност за създаване, проверка и използване на JSON Web Tokens (JWT) за аутентификация и авторизация в приложения с Prologue. JWT е компактен, URL-безопасен начин за представяне на твърдения, които да бъдат прехвърлени между две страни.

### Функции

- Създаване и проверка на JWT токени
- Middleware за автоматична проверка на токени
- Поддръжка на различни алгоритми за подпис (HS256, HS384, HS512)
- Авторизация, базирана на роли
- Гъвкаво извличане на токени от заглавия, параметри на заявката или бисквитки

### Използване

```nim
import prologue
import prologue/auth/jwt

# Създаване на JWT опции
let jwtOptions = newJWTOptions(
  secret = "вашият-таен-ключ",
  algorithm = JWTAlgorithm.HS256,
  issuer = some("prologue"),
  audience = some("users"),
  expireIn = some(3600)  # 1 час
)

# Създаване на JWT middleware
let jwtMiddleware = newJWTMiddleware(
  options = jwtOptions,
  excludePaths = @["/login", "/", "/static/"]
)

# Създаване на JWT токен
let claims = %* {
  "sub": "user123",
  "name": "Иван Иванов",
  "roles": ["user", "admin"]
}

let token = createToken(jwtOptions, claims)

# Проверка на JWT токен
let verified = verifyToken(jwtOptions, token)

# Използване на JWT middleware във вашето приложение
var app = newApp()
app.use(jwtMiddleware.jwtMiddleware)

# Достъп до JWT claims в обработчик
proc protectedHandler(ctx: Context) {.async.} =
  let claims = getJWTClaims(ctx)
  let username = claims["sub"].getStr()
  
  # Проверка дали потребителят има определена роля
  if hasJWTRole(ctx, "admin"):
    # Функционалност само за администратори
    resp "Административна зона"
  else:
    resp "Потребителска зона"

app.get("/protected", protectedHandler)
```

### API Референция

#### Типове

- `JWTAlgorithm`: Изброим тип за поддържаните алгоритми за подпис (HS256, HS384, HS512)
- `JWTClaims`: JSON полезен товар на JWT токен
- `JWTOptions`: Конфигурационни опции за JWT
- `JWTMiddleware`: Middleware за JWT аутентификация

#### Функции

- `newJWTOptions(secret, algorithm, issuer, audience, expireIn)`: Създава нови JWT опции
- `createToken(options, claims)`: Създава JWT токен
- `verifyToken(options, token)`: Проверява JWT токен и връща неговите claims
- `extractToken(ctx, tokenLocation)`: Извлича JWT токен от заявка
- `newJWTMiddleware(options, tokenLocation, excludePaths)`: Създава ново JWT middleware
- `jwtMiddleware(middleware)`: Създава обработчик за JWT аутентификация
- `getJWTClaims(ctx)`: Получава JWT claims от контекста
- `getJWTSubject(ctx)`: Получава subject (sub) от JWT claims
- `hasJWTRole(ctx, role)`: Проверява дали потребителят има определена роля