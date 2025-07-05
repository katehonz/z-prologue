# HTTP/1.1 Keep-Alive Оптимизации

Този документ описва напредналите HTTP/1.1 Keep-Alive оптимизации, реализирани в Prologue за подобряване на производителността и ефективността на връзките.

## Преглед

HTTP/1.1 Keep-Alive оптимизациите включват:

- **Connection Pooling** - Интелигентно преизползване на връзки
- **Persistent Connections Management** - Управление на постоянни връзки с автоматично почистване
- **Timeout Optimizations** - Адаптивни алгоритми за управление на таймаути
- **Performance Monitoring** - Мониторинг на производителността и автоматична настройка

## Архитектура

### Основни компоненти

1. **KeepAliveManager** (`src/prologue/core/httpcore/keepalive.nim`)
   - Управление на Keep-Alive връзки
   - Мониторинг на здравето на връзките
   - Автоматично почистване на остарели връзки

2. **HttpConnectionPool** (`src/prologue/core/httpcore/connectionpool.nim`)
   - Напреднал пул от връзки с групиране
   - Различни стратегии за избор на връзки
   - Адаптивно управление на размера на пула

3. **TimeoutManager** (`src/prologue/core/httpcore/timeouts.nim`)
   - Адаптивно управление на таймаути
   - Circuit breaker модел
   - Предсказване на оптимални таймаути

4. **HttpOptimizer** (`src/prologue/core/httpcore/optimizations.nim`)
   - Интеграция на всички оптимизации
   - Автоматична настройка на параметри
   - Мониторинг на производителността

## Използване

### Основна настройка

```nim
import prologue
import prologue/core/httpcore/optimizations

# Инициализация с ниво на оптимизация
initGlobalHttpOptimizer(olBalanced)

var app = newApp()
# Вашите маршрути...
app.run()
```

### Нива на оптимизация

#### Conservative (Консервативно)
- Безопасни оптимизации за продукция
- Минимални рискове
- Умерено подобрение на производителността

```nim
initGlobalHttpOptimizer(olConservative)
```

#### Balanced (Балансирано) - Препоръчително
- Оптимален баланс между производителност и безопасност
- Адаптивни таймаути включени
- Автоматична настройка

```nim
initGlobalHttpOptimizer(olBalanced)
```

#### Aggressive (Агресивно)
- Максимална производителност
- Всички оптимизации включени
- Изисква мониторинг

```nim
initGlobalHttpOptimizer(olAggressive)
```

### Персонализирана конфигурация

```nim
let customConfig = OptimizerConfig(
  level: olCustom,
  enableKeepAlive: true,
  enableConnectionPooling: true,
  enableAdaptiveTimeouts: true,
  enableMetrics: true,
  enableAutoTuning: true,
  metricsInterval: 30,
  autoTuningInterval: 120,
  performanceThreshold: 1500.0
)

initGlobalHttpOptimizer(olCustom, some(customConfig))
```

## Конфигурация на компонентите

### Keep-Alive Manager

```nim
let keepAliveConfig = KeepAliveConfig(
  enabled: true,
  maxConnections: 1000,        # Максимум връзки
  maxIdleTime: 60,            # Максимално време на бездействие (сек)
  maxConnectionAge: 300,       # Максимална възраст на връзката (сек)
  maxRequestsPerConnection: 100, # Максимум заявки на връзка
  keepAliveTimeout: 15,        # Таймаут Keep-Alive (сек)
  cleanupInterval: 30,         # Интервал на почистване (сек)
  healthCheckInterval: 60,     # Интервал на проверка на здравето (сек)
  adaptiveTimeouts: true,      # Адаптивни таймаути
  connectionReuse: true,       # Преизползване на връзки
  compressionEnabled: true     # Компресия на отговори
)
```

### Connection Pool

```nim
let poolConfig = PoolConfig(
  maxGlobalConnections: 2000,  # Максимум глобални връзки
  maxGroupConnections: 100,    # Максимум връзки в група
  defaultStrategy: psAdaptive, # Стратегия за избор на връзки
  enableAdaptive: true,        # Адаптивно поведение
  enableHealthChecks: true,    # Проверки на здравето
  enableMetrics: true,         # Събиране на метрики
  cleanupInterval: 30,         # Интервал на почистване (сек)
  metricsInterval: 10,         # Интервал на обновяване на метрики (сек)
  connectionTimeout: 30,       # Таймаут на връзката (сек)
  idleTimeout: 300            # Таймаут на бездействие (сек)
)
```

### Timeout Manager

```nim
let timeoutConfigs = {
  ttConnection: TimeoutConfig(
    timeoutType: ttConnection,
    baseTimeout: 5000,          # Базов таймаут (мс)
    minTimeout: 1000,           # Минимален таймаут (мс)
    maxTimeout: 30000,          # Максимален таймаут (мс)
    strategy: tsAdaptive,       # Стратегия на адаптация
    adaptationFactor: 0.1,      # Фактор на адаптация
    historySize: 50,            # Размер на историята
    circuitThreshold: 5,        # Праг за circuit breaker
    circuitRecoveryTime: 30000  # Време за възстановяване (мс)
  )
}.toTable
```

## Стратегии на Connection Pool

### Round Robin
- Цикличен избор на връзки
- Равномерно разпределение на натоварването
- Проста и надеждна стратегия

### Least Used
- Избор на най-малко използваната връзка
- Оптимизация за неравномерно натоварване
- Добра за дълготрайни връзки

### Health Based
- Избор въз основа на здравето на връзките
- Отчита времето за отговор и грешките
- Автоматично избягване на проблемни връзки

### Adaptive
- Комбинира всички фактори
- Автоматична адаптация към условията
- Препоръчва се за повечето случаи

## Мониторинг и метрики

### Получаване на статистика

```nim
# Статистика Keep-Alive
let keepAliveStats = getConnectionPoolStats()
echo "Pool Hit Rate: ", keepAliveStats.poolHitRate

# Статистика Connection Pool
let optimizer = getGlobalHttpOptimizer()
let poolStats = getPoolStatistics(optimizer.connectionPool)
echo "Utilization: ", poolStats.utilizationRate

# Статистика таймаути
let timeoutStats = getTimeoutStatistics(optimizer.timeoutManager)
echo "Timeout occurrences: ", timeoutStats.timeoutOccurrences
```

### Логиране на статистика

```nim
# Автоматично логиране
logConnectionStats()
logPoolStatus(optimizer.connectionPool)
logTimeoutStatistics(optimizer.timeoutManager)
logOptimizerStatus(optimizer)
```

### JSON статистика

```nim
# Получаване на статистика в JSON формат
let status = getOptimizerStatus(optimizer)
echo status.pretty()
```

## Автоматична настройка

Системата автоматично анализира производителността и предлага оптимизации:

```nim
# Анализ на производителността
let profile = analyzePerformance(optimizer)
echo "Avg Response Time: ", profile.avgResponseTime
echo "Error Rate: ", profile.errorRate

# Получаване на препоръки
let recommendations = generateRecommendations(optimizer, profile)
for rec in recommendations:
  echo "Препоръка: ", rec.component, " -> ", rec.parameter
  echo "Очаквано подобрение: ", rec.expectedImprovement, "%"

# Прилагане на препоръки
applyRecommendations(optimizer, recommendations)
```

## Интеграция с обработчици

### Автоматична оптимизация на заглавки

```nim
proc myHandler(ctx: Context) {.async.} =
  let startTime = getTime()
  
  # Вашата логика за обработка...
  
  let responseTime = (getTime() - startTime).inMilliseconds.float
  let clientId = ctx.request.hostName()
  
  # Записване на метрики за оптимизация
  recordRequestMetrics(clientId, responseTime, true, true)
  
  resp "Hello World!"
```

### Персонализирани Keep-Alive заглавки

```nim
proc customHandler(ctx: Context) {.async.} =
  var headers = initOptimizedResponseHeaders(ctx.request.hostName())
  
  # Автоматична оптимизация на заглавките
  headers.optimize()
  
  # Добавяне на персонализирани заглавки
  headers["X-Custom"] = "value"
  
  resp "Response", Http200, headers.headers
```

## Примери за използване

### Основен пример

```nim
import prologue
import prologue/core/httpcore/optimizations

# Инициализация на оптимизации
initGlobalHttpOptimizer(olBalanced)

proc hello(ctx: Context) {.async.} =
  resp "Здравей, оптимизиран свят!"

var app = newApp()
app.get("/", hello)
app.run()
```

### Напреднал пример с метрики

```nim
import prologue
import prologue/core/httpcore/optimizations
import std/[times, json]

initGlobalHttpOptimizer(olAggressive)

proc apiHandler(ctx: Context) {.async.} =
  let startTime = getTime()
  
  # Симулация на обработка
  await sleepAsync(50)
  
  let responseTime = (getTime() - startTime).inMilliseconds.float
  let clientId = ctx.request.hostName()
  
  # Записване на метрики
  recordRequestMetrics(clientId, responseTime, true, true)
  
  let response = %*{
    "message": "API отговор",
    "responseTime": responseTime,
    "optimized": true
  }
  
  resp $response, Http200, {"Content-Type": "application/json"}

proc metricsHandler(ctx: Context) {.async.} =
  let optimizer = getGlobalHttpOptimizer()
  let status = getOptimizerStatus(optimizer)
  resp $status, Http200, {"Content-Type": "application/json"}

var app = newApp()
app.get("/api", apiHandler)
app.get("/metrics", metricsHandler)
app.run()
```

## Тестване на оптимизациите

### Тестване Keep-Alive с curl

```bash
# Тест с Keep-Alive (по подразбиране в HTTP/1.1)
curl -v http://localhost:8080/api

# Тест без Keep-Alive
curl -v -H "Connection: close" http://localhost:8080/api

# Множествени заявки за тестване на преизползването на връзки
for i in {1..10}; do
  curl -s http://localhost:8080/api > /dev/null
done
```

### Натоварващо тестване

```bash
# Използване на Apache Bench
ab -n 1000 -c 10 -k http://localhost:8080/api

# Използване на wrk
wrk -t4 -c100 -d30s --timeout 10s http://localhost:8080/api
```

## Най-добри практики

### 1. Избор на ниво на оптимизация
- **Продукция**: използвайте `olBalanced` или `olConservative`
- **Разработка**: можете да използвате `olAggressive` за тестване
- **Високонатоварени системи**: настройте `olCustom`

### 2. Мониторинг
- Редовно проверявайте метриките за производителност
- Настройте алерти за високо ниво на грешки
- Мониторирайте използването на памет от пула от връзки

### 3. Настройка на таймаути
- Започнете с консервативни стойности
- Използвайте адаптивни таймаути в продукция
- Настройте circuit breaker за критични услуги

### 4. Connection Pool
- Настройте размера на пула в зависимост от натоварването
- Използвайте групиране на връзки за различни типове клиенти
- Редовно почиствайте неизползвани връзки

### 5. Отстраняване на грешки
- Включете подробно логиране в режим на разработка
- Използвайте крайни точки за метрики за мониторинг
- Анализирайте препоръките за автоматична настройка

## Производителност

### Очаквани подобрения

- **Време за отговор**: 15-30% подобрение за множествени заявки
- **Пропускателна способност**: 20-40% увеличение при високо натоварване
- **Използване на ресурси**: 10-25% намаляване на използването на CPU и памет
- **Брой връзки**: 50-70% намаляване на новите TCP връзки

### Фактори, влияещи на производителността

- Тип натоварване (кратки срещу дълги заявки)
- Брой едновременни клиенти
- Мрежово забавяне
- Размер на отговорите
- Честота на заявките от един клиент

## Отстраняване на неизправности

### Чести проблеми

1. **Високо използване на памет**
   - Намалете размера на пула от връзки
   - Съкратете времето на живот на връзките
   - Увеличете честотата на почистване

2. **Бавни отговори**
   - Проверете настройките на таймаутите
   - Анализирайте метриките за производителност
   - Помислете за използване на по-агресивни оптимизации

3. **Грешки във връзките**
   - Проверете настройките на circuit breaker
   - Увеличете таймаутите за бавни клиенти
   - Проверете здравето на връзките

### Информация за отстраняване на грешки

```nim
# Включване на подробно логиране
setLogFilter(lvlDebug)

# Получаване на подробна информация
let optimizer = getGlobalHttpOptimizer()
logOptimizerStatus(optimizer)

# Анализ на препоръки
let profile = analyzePerformance(optimizer)
let recommendations = generateRecommendations(optimizer, profile)
for rec in recommendations:
  echo "Debug: ", rec
```

## Заключение

HTTP/1.1 Keep-Alive оптимизациите в Prologue предоставят мощен набор от инструменти за подобряване на производителността на уеб приложенията. Правилната настройка и мониторинг на тези оптимизации може значително да подобри потребителския опит и ефективността на използването на сървърните ресурси.

За получаване на допълнителна информация и примери, вижте:
- `examples/performance/keepalive_optimizations.nim` - пълен пример за използване
- Изходен код в `src/prologue/core/httpcore/` - подробна реализация
- Тестове за производителност в `tests/performance/` - бенчмаркове и тестове

## Български специфични бележки

Тази документация е преведена на български език за по-лесно разбиране от българските разработчици. Всички примери и код остават на английски език, тъй като това е стандартната практика в програмирането.

За въпроси и поддръжка на български език, моля свържете се с българската общност на разработчици на Nim или създайте issue в GitHub хранилището.