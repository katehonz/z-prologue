![License: Apache-2.0](https://img.shields.io/github/license/planety/prologue)

# Z-Prologue

**Enhanced Version of Prologue Web Framework** | **Улучшенная версия Prologue Web Framework**

*What's past is prologue.*

## Description | Описание

**English:**
`Z-Prologue` is an enhanced version of the powerful and flexible Prologue web framework written in Nim. This fork includes additional performance optimizations, improved architecture, and new features for building elegant and high-performance web services.

**Русский:**
`Z-Prologue` - это усовершенствованная версия мощного и гибкого веб-фреймворка Prologue, написанного на языке Nim. Этот форк включает в себя дополнительные оптимизации производительности, улучшенную архитектуру и новые функции для создания элегантных и высокопроизводительных веб-сервисов.

**Author | Автор:** GIgov

### Key Improvements in Z-Prologue | Ключевые улучшения в Z-Prologue:

- 🚀 **Performance Optimizations | Оптимизации производительности**: Enhanced caching system, lazy loading, and optimized routing | Улучшенная система кэширования, ленивая загрузка и оптимизированная маршрутизация
- 🔧 **Database Connection Pool | Пул соединений с базой данных**: Efficient database connection management | Эффективное управление подключениями к БД
- ⚡ **Advanced Caching | Продвинутое кэширование**: LRU and LFU cache with automatic cleanup | LRU и LFU кэш с автоматической очисткой
- 🎯 **Optimized Routing | Оптимизированная маршрутизация**: Fast route processing with minimal overhead | Быстрая обработка маршрутов с минимальными накладными расходами
- 📊 **Performance Monitoring | Мониторинг производительности**: Built-in tools for tracking metrics | Встроенные инструменты для отслеживания метрик

## Purpose | Цель

**English:**
`Z-Prologue` is ideal for building elegant and high-performance web services with a focus on performance and scalability.

**Русский:**
`Z-Prologue` идеально подходит для создания элегантных и высокопроизводительных веб-сервисов с акцентом на производительность и масштабируемость.

**Reduce magic. Reduce surprise. | Уменьшить магию. Уменьшить сюрпризы.**

## Documentation | Документация

**English:**
Z-Prologue maintains compatibility with the original Prologue API while adding new features. You can refer to the original documentation and our enhanced features documentation:

**Русский:**
Z-Prologue поддерживает совместимость с оригинальным API Prologue, добавляя новые функции. Вы можете обратиться к оригинальной документации и документации наших улучшенных функций:

<table class="tg">
<tbody>
  <tr>
    <td class="tg-0pky">Original Documentation | Оригинальная документация</td>
    <td class="tg-c3ow" text-align="center" colspan="2"><a href="https://planety.github.io/prologue" target="_blank" rel="noopener noreferrer">Index Page</a></td>
  </tr>
  <tr>
    <td class="tg-c3ow">Performance Optimizations | Оптимизации производительности</td>
    <td class="tg-0pky"><a href="PERFORMANCE_OPTIMIZATIONS.md">Performance Guide</a></td>
    <td class="tg-0pky"><a href="examples/performance/">Examples</a></td>
  </tr>
  <tr>
    <td class="tg-c3ow">Z-Prologue Examples | Примеры Z-Prologue</td>
    <td class="tg-0pky"><a href="examples/">Local Examples</a></td>
    <td class="tg-0pky"><a href="docs/">Documentation</a></td>
  </tr>
</tbody>
</table>

**English:** Welcome to share your experience with Z-Prologue and contribute to the project!

**Русский:** Добро пожаловать поделиться своим опытом с Z-Prologue и внести вклад в проект!

## Features | Возможности

**English:** All original Prologue features plus Z-Prologue enhancements:

**Русский:** Все оригинальные возможности Prologue плюс улучшения Z-Prologue:

- **Core | Ядро**
  - [x] Configure and Settings | Конфигурация и настройки
  - [x] Context | Контекст
  - [x] Param and Query Data | Параметры и данные запросов
  - [x] Form Data | Данные форм
  - [x] Static Files | Статические файлы
  - [x] Middleware | Промежуточное ПО
  - [x] Powerful Routing System | Мощная система маршрутизации (based on [nest](https://github.com/kedean/nest))
  - [x] Cookie | Куки
  - [x] Startup and Shutdown Events | События запуска и остановки
  - [x] URL Building | Построение URL
  - [x] Error Handler | Обработчик ошибок

- **Plugin | Плагины**
  - [x] I18n | Интернационализация
  - [x] Basic Authentication | Базовая аутентификация
  - [x] Minimal OpenAPI support | Минимальная поддержка OpenAPI
  - [x] Websocket support | Поддержка WebSocket
  - [x] Mocking test | Тестирование с моками
  - [x] CORS Response | CORS ответы
  - [x] Data Validation | Валидация данных
  - [x] Session | Сессии
  - [x] Cache | Кэширование
  - [x] Signing | Подписывание
  - [x] Command line tools | Инструменты командной строки
  - [x] Cross-Site Request Forgery | Защита от CSRF
  - [x] Clickjacking Protection | Защита от кликджекинга

- **🚀 Z-Prologue Enhancements | Улучшения Z-Prologue**
  - [x] **Performance Optimizations | Оптимизации производительности**
    - [x] LRU/LFU Caching | LRU/LFU кэширование
    - [x] Lazy Loading | Ленивая загрузка
    - [x] Optimized Routing | Оптимизированная маршрутизация
  - [x] **Database Connection Pool | Пул соединений с БД**
  - [x] **Advanced Caching System | Продвинутая система кэширования**
  - [x] **Performance Monitoring | Мониторинг производительности**
  - [x] **Memory Management Optimizations | Оптимизации управления памятью**


## Installation | Установка

**English:**
First you should install [Nim](https://nim-lang.org/) language which is an elegant and high performance language. Follow the [instructions](https://nim-lang.org/install.html) and set environment variables correctly.

Then you can clone and build `z-prologue`:

```bash
git clone https://github.com/katehonz/z-prologue.git
cd z-prologue
nimble install
```

Or install directly from repository:

```bash
nimble install https://github.com/katehonz/z-prologue
```

**Русский:**
Сначала установите язык [Nim](https://nim-lang.org/), который является элегантным и высокопроизводительным языком. Следуйте [инструкциям](https://nim-lang.org/install.html) и правильно настройте переменные окружения.

Затем вы можете клонировать и собрать `z-prologue`:

```bash
git clone https://github.com/katehonz/z-prologue.git
cd z-prologue
nimble install
```

Или установить напрямую из репозитория:

```bash
nimble install https://github.com/katehonz/z-prologue
```

## Usage | Использование

### Hello World | Привет, мир!

```nim
import prologue

proc hello*(ctx: Context) {.async.} =
  resp "<h1>Hello, Z-Prologue!</h1>"

let app = newApp()
app.get("/", hello)
app.run()
```

**English:** Run **app.nim** ( `nim c -r app.nim` ). Now the server is running at `localhost:8080`.

**Русский:** Запустите **app.nim** ( `nim c -r app.nim` ). Теперь сервер работает на `localhost:8080`.

### Performance Optimizations Example | Пример с оптимизациями производительности

```nim
import prologue
import prologue/performance

proc optimizedHello*(ctx: Context) {.async.} =
  # Using built-in caching | Использование встроенного кэширования
  let cached = ctx.getFromCache("hello_response")
  if cached.isSome:
    resp cached.get()
  else:
    let response = "<h1>Optimized Z-Prologue! | Оптимизированный Z-Prologue!</h1>"
    ctx.setCache("hello_response", response, ttl = 300) # 5 minutes | 5 минут
    resp response

let app = newApp()
# Enable performance optimizations | Включение оптимизаций производительности
app.enablePerformanceOptimizations()
app.get("/", optimizedHello)
app.run()
```

### More Examples | Больше примеров
- [HelloWorld](examples/helloworld) - Basic example | Базовый пример
- [ToDoList](examples/todolist) - Todo list | Список задач
- [ToDoApp](examples/todoapp) - Todo application | Приложение задач
- [Blog](examples/blog) - Blog application | Блог-приложение
- [Performance Examples](examples/performance) - Performance optimization examples | Примеры оптимизации производительности
- [WebSocket Chat](examples/websocket_chat) - WebSocket chat | Чат с WebSocket

### Extensions | Расширения

**English:**
If you need more extensions, you can refer to [awesome prologue](https://github.com/planety/awesome-prologue) and [awesome nim](https://github.com/ringabout/awesome-nim#web).

**Русский:**
Если вам нужны дополнительные расширения, вы можете обратиться к [awesome prologue](https://github.com/planety/awesome-prologue) и [awesome nim](https://github.com/ringabout/awesome-nim#web).

## Performance | Производительность

**English:**
Z-Prologue includes many performance optimizations:

- **Caching**: LRU/LFU cache with configurable TTL
- **Connection Pool**: Efficient database connection management
- **Lazy Loading**: Load resources on demand
- **Optimized Routing**: Fast route processing

See [performance documentation](PERFORMANCE_OPTIMIZATIONS.md) for more details.

**Русский:**
Z-Prologue включает в себя множество оптимизаций производительности:

- **Кэширование**: LRU/LFU кэш с настраиваемым TTL
- **Пул соединений**: Эффективное управление подключениями к БД
- **Ленивая загрузка**: Загрузка ресурсов по требованию
- **Оптимизированная маршрутизация**: Быстрая обработка маршрутов

Подробнее см. [документацию по производительности](PERFORMANCE_OPTIMIZATIONS.md).

## License | Лицензия

Apache-2.0

## Contributing | Участие в разработке

**English:**
Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

**Русский:**
Вклад в проект приветствуется! Пожалуйста, не стесняйтесь отправлять Pull Request. Для крупных изменений сначала откройте issue для обсуждения того, что вы хотели бы изменить.

## Author | Автор

**GIgov** - Creator and main developer of Z-Prologue | Создатель и основной разработчик Z-Prologue

## Acknowledgments | Благодарности

**English:**
Special thanks to the original Prologue framework developers for creating an excellent foundation.

**Русский:**
Особая благодарность разработчикам оригинального фреймворка Prologue за создание отличной основы.

---

*Based on the original Prologue framework by planety | Основано на оригинальном Prologue framework от planety*
