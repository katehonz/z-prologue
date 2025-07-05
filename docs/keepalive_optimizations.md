# HTTP/1.1 Keep-Alive Optimizations

Этот документ описывает продвинутые оптимизации HTTP/1.1 Keep-Alive, реализованные в Prologue для улучшения производительности и эффективности соединений.

## Обзор

HTTP/1.1 Keep-Alive оптимизации включают:

- **Connection Pooling** - Интеллектуальное переиспользование соединений
- **Persistent Connections Management** - Управление постоянными соединениями с автоматической очисткой
- **Timeout Optimizations** - Адаптивные алгоритмы управления таймаутами
- **Performance Monitoring** - Мониторинг производительности и автоматическая настройка

## Архитектура

### Основные компоненты

1. **KeepAliveManager** (`src/prologue/core/httpcore/keepalive.nim`)
   - Управление Keep-Alive соединениями
   - Мониторинг здоровья соединений
   - Автоматическая очистка устаревших соединений

2. **AdvancedConnectionPool** (`src/prologue/core/httpcore/connectionpool.nim`)
   - Продвинутый пул соединений с группировкой
   - Различные стратегии выбора соединений
   - Адаптивное управление размером пула

3. **TimeoutManager** (`src/prologue/core/httpcore/timeouts.nim`)
   - Адаптивное управление таймаутами
   - Circuit breaker паттерн
   - Предсказание оптимальных таймаутов

4. **HttpOptimizer** (`src/prologue/core/httpcore/optimizations.nim`)
   - Интеграция всех оптимизаций
   - Автоматическая настройка параметров
   - Мониторинг производительности

## Использование

### Базовая настройка

```nim
import prologue
import prologue/core/httpcore/optimizations

# Инициализация с уровнем оптимизации
initGlobalHttpOptimizer(olBalanced)

var app = newApp()
# Ваши маршруты...
app.run()
```

### Уровни оптимизации

#### Conservative (Консервативный)
- Безопасные оптимизации для продакшена
- Минимальные риски
- Умеренное улучшение производительности

```nim
initGlobalHttpOptimizer(olConservative)
```

#### Balanced (Сбалансированный) - Рекомендуется
- Оптимальный баланс производительности и безопасности
- Адаптивные таймауты включены
- Автоматическая настройка

```nim
initGlobalHttpOptimizer(olBalanced)
```

#### Aggressive (Агрессивный)
- Максимальная производительность
- Все оптимизации включены
- Требует мониторинга

```nim
initGlobalHttpOptimizer(olAggressive)
```

### Кастомная конфигурация

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

## Конфигурация компонентов

### Keep-Alive Manager

```nim
let keepAliveConfig = KeepAliveConfig(
  enabled: true,
  maxConnections: 1000,        # Максимум соединений
  maxIdleTime: 60,            # Максимальное время простоя (сек)
  maxConnectionAge: 300,       # Максимальный возраст соединения (сек)
  maxRequestsPerConnection: 100, # Максимум запросов на соединение
  keepAliveTimeout: 15,        # Таймаут Keep-Alive (сек)
  cleanupInterval: 30,         # Интервал очистки (сек)
  healthCheckInterval: 60,     # Интервал проверки здоровья (сек)
  adaptiveTimeouts: true,      # Адаптивные таймауты
  connectionReuse: true,       # Переиспользование соединений
  compressionEnabled: true     # Сжатие ответов
)
```

### Connection Pool

```nim
let poolConfig = PoolConfig(
  maxGlobalConnections: 2000,  # Максимум глобальных соединений
  maxGroupConnections: 100,    # Максимум соединений в группе
  defaultStrategy: psAdaptive, # Стратегия выбора соединений
  enableAdaptive: true,        # Адаптивное поведение
  enableHealthChecks: true,    # Проверки здоровья
  enableMetrics: true,         # Сбор метрик
  cleanupInterval: 30,         # Интервал очистки (сек)
  metricsInterval: 10,         # Интервал обновления метрик (сек)
  connectionTimeout: 30,       # Таймаут соединения (сек)
  idleTimeout: 300            # Таймаут простоя (сек)
)
```

### Timeout Manager

```nim
let timeoutConfigs = {
  ttConnection: TimeoutConfig(
    timeoutType: ttConnection,
    baseTimeout: 5000,          # Базовый таймаут (мс)
    minTimeout: 1000,           # Минимальный таймаут (мс)
    maxTimeout: 30000,          # Максимальный таймаут (мс)
    strategy: tsAdaptive,       # Стратегия адаптации
    adaptationFactor: 0.1,      # Фактор адаптации
    historySize: 50,            # Размер истории
    circuitThreshold: 5,        # Порог для circuit breaker
    circuitRecoveryTime: 30000  # Время восстановления (мс)
  )
}.toTable
```

## Стратегии Connection Pool

### Round Robin
- Циклический выбор соединений
- Равномерное распределение нагрузки
- Простая и надежная стратегия

### Least Used
- Выбор наименее используемого соединения
- Оптимизация для неравномерной нагрузки
- Хорошо для долгоживущих соединений

### Health Based
- Выбор на основе здоровья соединений
- Учитывает время отклика и ошибки
- Автоматическое избегание проблемных соединений

### Adaptive
- Комбинирует все факторы
- Автоматическая адаптация к условиям
- Рекомендуется для большинства случаев

## Мониторинг и метрики

### Получение статистики

```nim
# Статистика Keep-Alive
let keepAliveStats = getConnectionPoolStats()
echo "Pool Hit Rate: ", keepAliveStats.poolHitRate

# Статистика Connection Pool
let optimizer = getGlobalHttpOptimizer()
let poolStats = getPoolStatistics(optimizer.connectionPool)
echo "Utilization: ", poolStats.utilizationRate

# Статистика таймаутов
let timeoutStats = getTimeoutStatistics(optimizer.timeoutManager)
echo "Timeout occurrences: ", timeoutStats.timeoutOccurrences
```

### Логирование статистики

```nim
# Автоматическое логирование
logConnectionStats()
logPoolStatus(optimizer.connectionPool)
logTimeoutStatistics(optimizer.timeoutManager)
logOptimizerStatus(optimizer)
```

### JSON статистика

```nim
# Получение статистики в JSON формате
let status = getOptimizerStatus(optimizer)
echo status.pretty()
```

## Автоматическая настройка

Система автоматически анализирует производительность и предлагает оптимизации:

```nim
# Анализ производительности
let profile = analyzePerformance(optimizer)
echo "Avg Response Time: ", profile.avgResponseTime
echo "Error Rate: ", profile.errorRate

# Получение рекомендаций
let recommendations = generateRecommendations(optimizer, profile)
for rec in recommendations:
  echo "Recommendation: ", rec.component, " -> ", rec.parameter
  echo "Expected improvement: ", rec.expectedImprovement, "%"

# Применение рекомендаций
applyRecommendations(optimizer, recommendations)
```

## Интеграция с обработчиками

### Автоматическая оптимизация заголовков

```nim
proc myHandler(ctx: Context) {.async.} =
  let startTime = getTime()
  
  # Ваша логика обработки...
  
  let responseTime = (getTime() - startTime).inMilliseconds.float
  let clientId = ctx.request.hostName()
  
  # Запись метрик для оптимизации
  recordRequestMetrics(clientId, responseTime, true, true)
  
  resp "Hello World!"
```

### Кастомные заголовки Keep-Alive

```nim
proc customHandler(ctx: Context) {.async.} =
  var headers = initOptimizedResponseHeaders(ctx.request.hostName())
  
  # Автоматическая оптимизация заголовков
  headers.optimize()
  
  # Добавление кастомных заголовков
  headers["X-Custom"] = "value"
  
  resp "Response", Http200, headers.headers
```

## Примеры использования

### Базовый пример

```nim
import prologue
import prologue/core/httpcore/optimizations

# Инициализация оптимизаций
initGlobalHttpOptimizer(olBalanced)

proc hello(ctx: Context) {.async.} =
  resp "Hello, optimized world!"

var app = newApp()
app.get("/", hello)
app.run()
```

### Продвинутый пример с метриками

```nim
import prologue
import prologue/core/httpcore/optimizations
import std/[times, json]

initGlobalHttpOptimizer(olAggressive)

proc apiHandler(ctx: Context) {.async.} =
  let startTime = getTime()
  
  # Симуляция обработки
  await sleepAsync(50)
  
  let responseTime = (getTime() - startTime).inMilliseconds.float
  let clientId = ctx.request.hostName()
  
  # Запись метрик
  recordRequestMetrics(clientId, responseTime, true, true)
  
  let response = %*{
    "message": "API response",
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

## Тестирование оптимизаций

### Тестирование Keep-Alive с curl

```bash
# Тест с Keep-Alive (по умолчанию в HTTP/1.1)
curl -v http://localhost:8080/api

# Тест без Keep-Alive
curl -v -H "Connection: close" http://localhost:8080/api

# Множественные запросы для тестирования переиспользования соединений
for i in {1..10}; do
  curl -s http://localhost:8080/api > /dev/null
done
```

### Нагрузочное тестирование

```bash
# Использование Apache Bench
ab -n 1000 -c 10 -k http://localhost:8080/api

# Использование wrk
wrk -t4 -c100 -d30s --timeout 10s http://localhost:8080/api
```

## Лучшие практики

### 1. Выбор уровня оптимизации
- **Продакшен**: используйте `olBalanced` или `olConservative`
- **Разработка**: можно использовать `olAggressive` для тестирования
- **Высоконагруженные системы**: настройте `olCustom`

### 2. Мониторинг
- Регулярно проверяйте метрики производительности
- Настройте алерты на высокий уровень ошибок
- Мониторьте использование памяти пулом соединений

### 3. Настройка таймаутов
- Начните с консервативных значений
- Используйте адаптивные таймауты в продакшене
- Настройте circuit breaker для критических сервисов

### 4. Connection Pool
- Настройте размер пула в зависимости от нагрузки
- Используйте группировку соединений для разных типов клиентов
- Регулярно очищайте неиспользуемые соединения

### 5. Отладка
- Включите подробное логирование в режиме разработки
- Используйте эндпоинты метрик для мониторинга
- Анализируйте рекомендации автоматической настройки

## Производительность

### Ожидаемые улучшения

- **Время отклика**: 15-30% улучшение для множественных запросов
- **Пропускная способность**: 20-40% увеличение при высокой нагрузке
- **Использование ресурсов**: 10-25% снижение использования CPU и памяти
- **Количество соединений**: 50-70% снижение новых TCP соединений

### Факторы, влияющие на производительность

- Тип нагрузки (короткие vs длинные запросы)
- Количество одновременных клиентов
- Сетевая задержка
- Размер ответов
- Частота запросов от одного клиента

## Устранение неполадок

### Частые проблемы

1. **Высокое использование памяти**
   - Уменьшите размер пула соединений
   - Сократите время жизни соединений
   - Увеличьте частоту очистки

2. **Медленные ответы**
   - Проверьте настройки таймаутов
   - Анализируйте метрики производительности
   - Рассмотрите использование более агрессивных оптимизаций

3. **Ошибки соединений**
   - Проверьте настройки circuit breaker
   - Увеличьте таймауты для медленных клиентов
   - Проверьте здоровье соединений

### Отладочная информация

```nim
# Включение подробного логирования
setLogFilter(lvlDebug)

# Получение детальной информации
let optimizer = getGlobalHttpOptimizer()
logOptimizerStatus(optimizer)

# Анализ рекомендаций
let profile = analyzePerformance(optimizer)
let recommendations = generateRecommendations(optimizer, profile)
for rec in recommendations:
  echo "Debug: ", rec
```

## Заключение

HTTP/1.1 Keep-Alive оптимизации в Prologue предоставляют мощный набор инструментов для улучшения производительности веб-приложений. Правильная настройка и мониторинг этих оптимизаций может значительно улучшить пользовательский опыт и эффективность использования ресурсов сервера.

Для получения дополнительной информации и примеров, смотрите:
- `examples/performance/keepalive_optimizations.nim` - полный пример использования
- Исходный код в `src/prologue/core/httpcore/` - детальная реализация
- Тесты производительности в `tests/performance/` - бенчмарки и тесты