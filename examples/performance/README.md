# Оптимизации на производителността за Prologue

Този директорий съдържа примери за оптимизации на производителността в Prologue web framework.

## Файлове

### `simple_optimizations.nim` ✅ РАБОТИ
Прост, работещ пример, който демонстрира основни техники за подобряване на производителността:

- **Performance Middleware**: Мониторинг на времето за отговор
- **Асинхронни операции**: Използване на `async/await` за неблокиращи операции
- **JSON API endpoints**: Структурирани API отговори
- **Симулация на база данни**: Демонстрация на забавяне при заявки

#### Как да стартирате:
```bash
cd examples/performance
nim c -r simple_optimizations.nim
```

Сървърът ще стартира на `http://localhost:8080`

#### Налични endpoints:
- `GET /` - Начална страница с документация
- `GET /users` - Всички потребители (100ms забавяне)
- `GET /users/{id}` - Потребител по ID (50ms забавяне)
- `GET /metrics` - Метрики за производителност
- `GET /health` - Проверка за здраве

### Други файлове (ЕКСПЕРИМЕНТАЛНИ)

⚠️ **Забележка**: Следните файлове са експериментални и може да не работят поради архитектурни несъвместимости с текущата версия на Prologue:

- `basic_optimizations.nim` - Сложни оптимизации (има грешки при компилация)
- `advanced_caching.nim` - Разширено кеширане (има грешки при компилация)

## Демонстрирани техники

### 1. Performance Middleware
```nim
proc performanceMiddleware(): HandlerAsync =
  result = proc (ctx: Context) {.async, gcsafe.} =
    let startTime = epochTime()
    await switch(ctx)
    let endTime = epochTime()
    let requestTime = endTime - startTime
    ctx.response.headers["X-Response-Time"] = $(requestTime * 1000) & "ms"
```

### 2. Асинхронни операции
```nim
proc getUserById(ctx: Context) {.async, gcsafe.} =
  await sleepAsync(50) # Симулира заявка към база данни
  # ... обработка на заявката
```

### 3. JSON API отговори
```nim
ctx.response.body = """{"id": 1, "name": "Иван Петров"}"""
ctx.response.headers["Content-Type"] = "application/json"
```

## Резултати от оптимизациите

- **Мониторинг**: Всеки отговор включва `X-Response-Time` header
- **Асинхронност**: Неблокиращи операции за по-добра производителност
- **Структурирани отговори**: JSON формат за лесна интеграция
- **Здравни проверки**: Endpoint за мониторинг на състоянието

## Тестване на производителността

Можете да тествате производителността с инструменти като:

```bash
# Тест с curl
curl -w "@curl-format.txt" -o /dev/null -s "http://localhost:8080/users/1"

# Тест с ab (Apache Bench)
ab -n 1000 -c 10 http://localhost:8080/users

# Тест с wrk
wrk -t12 -c400 -d30s http://localhost:8080/users
```

## Бъдещи подобрения

За по-напреднали оптимизации можете да разгледате:

1. **Кеширане**: Redis или in-memory кеш
2. **Connection pooling**: За база данни
3. **Компресия**: Gzip компресия на отговорите
4. **Rate limiting**: Ограничаване на заявките
5. **Load balancing**: Разпределяне на натоварването

## Архитектурни бележки

Текущата версия на Prologue има специфични изисквания за GC safety и middleware patterns. Сложните оптимизации изискват внимателно проектиране, за да се избегнат конфликти с архитектурата на framework-а.