# Copyright 2023 Prologue Contributors
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

## Модуль для работы с JWT (JSON Web Tokens)
## 
## Этот модуль предоставляет функциональность для создания, проверки и
## использования JWT токенов для аутентификации и авторизации в приложениях Prologue.

import std/[base64, json, times, strutils, options, tables, asyncdispatch, strformat]
import nimcrypto/[sha2, hmac]

import ../core/context
import ../core/middlewaresbase
import ../core/httpexception

type
  JWTError* = object of CatchableError
    ## Исключение, возникающее при ошибках работы с JWT

  JWTAlgorithm* = enum
    ## Поддерживаемые алгоритмы подписи JWT
    HS256, HS384, HS512

  JWTClaims* = JsonNode
    ## Полезная нагрузка JWT токена

  JWTOptions* = object
    ## Настройки JWT
    secret*: string  # Секретный ключ для подписи
    algorithm*: JWTAlgorithm  # Алгоритм подписи
    issuer*: Option[string]  # Издатель токена
    audience*: Option[string]  # Аудитория токена
    expireIn*: Option[int]  # Время жизни токена в секундах

  JWTMiddleware* = ref object
    ## Middleware для проверки JWT токенов
    options*: JWTOptions
    tokenLocation*: tuple[header: string, query: string, cookie: string]
    excludePaths*: seq[string]

# Вспомогательные функции

proc base64UrlEncode(data: string): string =
  ## Кодирует строку в base64url формат
  result = base64.encode(data)
  result = result.replace('+', '-').replace('/', '_').replace("=", "")

proc base64UrlDecode(data: string): string =
  ## Декодирует строку из base64url формата
  var padding = ""
  let remainder = data.len mod 4
  if remainder > 0:
    padding = repeat('=', 4 - remainder)
  
  let fixedData = data.replace('-', '+').replace('_', '/')
  result = base64.decode(fixedData & padding)

proc getHashFunction(algorithm: JWTAlgorithm): proc(key, data: string): string =
  ## Возвращает функцию хеширования для указанного алгоритма
  case algorithm
  of HS256:
    result = proc(key, data: string): string =
      let hmacCtx = hmac.hmac(sha256, key, data)
      return $hmacCtx
  of HS384:
    result = proc(key, data: string): string =
      let hmacCtx = hmac.hmac(sha384, key, data)
      return $hmacCtx
  of HS512:
    result = proc(key, data: string): string =
      let hmacCtx = hmac.hmac(sha512, key, data)
      return $hmacCtx

# Основные функции для работы с JWT

proc newJWTOptions*(secret: string, algorithm = JWTAlgorithm.HS256,
                   issuer = none(string), audience = none(string),
                   expireIn = some(3600)): JWTOptions =
  ## Создает новые настройки JWT
  JWTOptions(
    secret: secret,
    algorithm: algorithm,
    issuer: issuer,
    audience: audience,
    expireIn: expireIn
  )

proc createToken*(options: JWTOptions, claims: JWTClaims): string =
  ## Создает JWT токен с указанными настройками и полезной нагрузкой
  # Создаем заголовок
  let header = %* {
    "alg": $options.algorithm,
    "typ": "JWT"
  }
  
  # Создаем полезную нагрузку
  var payload = claims
  
  # Добавляем стандартные поля
  let now = getTime().toUnix()
  payload["iat"] = %now  # Время создания токена
  
  if options.expireIn.isSome:
    payload["exp"] = %(now + options.expireIn.get)  # Время истечения токена
  
  if options.issuer.isSome:
    payload["iss"] = %options.issuer.get  # Издатель токена
  
  if options.audience.isSome:
    payload["aud"] = %options.audience.get  # Аудитория токена
  
  # Кодируем заголовок и полезную нагрузку
  let headerEncoded = base64UrlEncode($header)
  let payloadEncoded = base64UrlEncode($payload)
  
  # Создаем подпись
  let data = headerEncoded & "." & payloadEncoded
  let hashFunc = getHashFunction(options.algorithm)
  let signature = base64UrlEncode(hashFunc(options.secret, data))
  
  # Собираем токен
  result = data & "." & signature

proc verifyToken*(options: JWTOptions, token: string): JWTClaims =
  ## Проверяет JWT токен и возвращает полезную нагрузку
  # Разбиваем токен на части
  let parts = token.split('.')
  if parts.len != 3:
    raise newException(JWTError, "Invalid token format")
  
  let headerEncoded = parts[0]
  let payloadEncoded = parts[1]
  let signatureEncoded = parts[2]
  
  # Проверяем подпись
  let data = headerEncoded & "." & payloadEncoded
  let hashFunc = getHashFunction(options.algorithm)
  let expectedSignature = base64UrlEncode(hashFunc(options.secret, data))
  
  if signatureEncoded != expectedSignature:
    raise newException(JWTError, "Invalid token signature")
  
  # Декодируем полезную нагрузку
  let payloadJson = base64UrlDecode(payloadEncoded)
  let payload = parseJson(payloadJson)
  
  # Проверяем время истечения токена
  if payload.hasKey("exp"):
    let expTime = payload["exp"].getInt()
    let now = getTime().toUnix()
    
    if now > expTime:
      raise newException(JWTError, "Token has expired")
  
  # Проверяем издателя токена
  if options.issuer.isSome and payload.hasKey("iss"):
    if payload["iss"].getStr() != options.issuer.get:
      raise newException(JWTError, "Invalid token issuer")
  
  # Проверяем аудиторию токена
  if options.audience.isSome and payload.hasKey("aud"):
    if payload["aud"].getStr() != options.audience.get:
      raise newException(JWTError, "Invalid token audience")
  
  result = payload

proc extractToken*(ctx: Context, tokenLocation: tuple[header: string, query: string, cookie: string]): Option[string] =
  ## Извлекает JWT токен из запроса
  # Проверяем заголовок
  if tokenLocation.header.len > 0 and ctx.request.headers().hasKey(tokenLocation.header):
    let authHeader = ctx.request.headers()[tokenLocation.header, 0]
    if authHeader.startsWith("Bearer "):
      return some(authHeader[7..^1])
  
  # Проверяем параметр запроса
  if tokenLocation.query.len > 0:
    let token = ctx.getQueryParams(tokenLocation.query)
    if token.len > 0:
      return some(token)
  
  # Проверяем cookie
  if tokenLocation.cookie.len > 0 and ctx.request.cookies.hasKey(tokenLocation.cookie):
    return some(ctx.request.cookies[tokenLocation.cookie])
  
  return none(string)

# Middleware для JWT

proc newJWTMiddleware*(options: JWTOptions,
                      tokenLocation = (header: "Authorization", query: "token", cookie: "jwt"),
                      excludePaths: seq[string] = @[]): JWTMiddleware =
  ## Создает новый middleware для проверки JWT токенов
  JWTMiddleware(
    options: options,
    tokenLocation: tokenLocation,
    excludePaths: excludePaths
  )

proc jwtMiddleware*(middleware: JWTMiddleware): HandlerAsync =
  ## Создает middleware для проверки JWT токенов
  result = proc(ctx: Context) {.async.} =
    # Проверяем, исключен ли текущий путь
    let path = ctx.request.url.path
    for excludePath in middleware.excludePaths:
      if path.startsWith(excludePath):
        await switch(ctx)
        return
    
    # Извлекаем токен
    let tokenOpt = extractToken(ctx, middleware.tokenLocation)
    if tokenOpt.isNone:
      raise newException(HttpError, "JWT token is missing")
    
    let token = tokenOpt.get
    
    try:
      # Проверяем токен
      let claims = verifyToken(middleware.options, token)
      
      # Сохраняем полезную нагрузку в контексте
      ctx.ctxData["jwt_claims"] = $claims
      
      # Продолжаем обработку запроса
      await switch(ctx)
    except JWTError as e:
      # В случае ошибки проверки токена возвращаем 401 Unauthorized
      raise newException(HttpError, "JWT token is invalid: " & e.msg)

# Вспомогательные функции для работы с JWT в контексте

proc getJWTClaims*(ctx: Context): JWTClaims =
  ## Возвращает полезную нагрузку JWT токена из контекста
  if ctx.ctxData.hasKey("jwt_claims"):
    result = parseJson(ctx.ctxData["jwt_claims"])
  else:
    raise newException(JWTError, "JWT claims not found in context")

proc getJWTSubject*(ctx: Context): string =
  ## Возвращает subject (sub) из JWT токена
  let claims = getJWTClaims(ctx)
  if claims.hasKey("sub"):
    result = claims["sub"].getStr()
  else:
    raise newException(JWTError, "JWT subject not found in claims")

proc hasJWTRole*(ctx: Context, role: string): bool =
  ## Проверяет, имеет ли пользователь указанную роль
  try:
    let claims = getJWTClaims(ctx)
    if claims.hasKey("roles") and claims["roles"].kind == JArray:
      for roleNode in claims["roles"]:
        if roleNode.kind == JString and roleNode.getStr() == role:
          return true
  except:
    discard
  
  return false

# Пример использования
when isMainModule:
  # Создаем настройки JWT
  let options = newJWTOptions(
    secret = "my-secret-key",
    algorithm = JWTAlgorithm.HS256,
    issuer = some("prologue"),
    audience = some("users"),
    expireIn = some(3600)  # 1 час
  )
  
  # Создаем полезную нагрузку
  let claims = %* {
    "sub": "user123",
    "name": "John Doe",
    "roles": ["user", "admin"]
  }
  
  # Создаем токен
  let token = createToken(options, claims)
  echo "Token: ", token
  
  # Проверяем токен
  let verified = verifyToken(options, token)
  echo "Verified: ", verified