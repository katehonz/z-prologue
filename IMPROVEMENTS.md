# Prologue Framework Improvements / Подобрения на Фреймуърка Prologue

## English

### Overview of Improvements

We have analyzed and improved the Prologue web framework written in Nim. Here are the main improvements that have been made:

### 1. Code Structure Improvements

- **Elimination of global variables**: Replaced the global variable `dontUseThisShutDownEvents` in `application.nim` with a structured `ShutdownManager`.
- **Improved error handling**: Added more detailed logging and improved exception handling in the `handleContext` method.
- **Code organization**: Split large files into smaller modules for better readability and maintainability.

### 2. New Functionality

- **WebSocket rooms and channels**: Created a new module `websocket/rooms.nim` for organizing WebSocket connections into rooms and channels.
- **JWT authentication**: Added a new module `auth/jwt.nim` for creating, verifying, and using JWT tokens.
- **Enhanced middleware**: Improved middleware system with better error handling and more flexibility.

### 3. New Examples

- **WebSocket chat**: Created a full-featured chat example with room support in `examples/websocket_chat/`.
- **JWT authentication**: Created an authentication example using JWT in `examples/jwt_auth/`.

### 4. Documentation Improvements

- **Bilingual documentation**: Added documentation in both English and Bulgarian.
- **Updated changelog**: Added information about new features in version 0.7.0.
- **README files for examples**: Created detailed README files for new examples.
- **API documentation**: Added comprehensive API documentation for new modules.

### 5. Package Updates

- **Version update**: Updated version to 0.7.0 in `prologue.nimble`.
- **New tasks**: Added new tasks for testing new examples.
- **Export of new modules**: Updated `src/prologue.nim` to export new modules.

### Modified Files

- `src/prologue/core/application.nim` - Improved error handling and eliminated global variables
- `src/prologue.nim` - Added exports for new modules
- `prologue.nimble` - Updated version and added new tasks
- `changelog.md` - Added information about new features
- `mkdocs.yml` - Added new documentation pages to navigation

### New Files

- `src/prologue/websocket/rooms.nim` - WebSocket rooms and channels module
- `src/prologue/auth/jwt.nim` - JWT authentication module
- `examples/websocket_chat/` - WebSocket chat example
- `examples/jwt_auth/` - JWT authentication example
- `docs/websocket_rooms.md` - Documentation for WebSocket rooms
- `docs/jwt_auth.md` - Documentation for JWT authentication

These improvements make Prologue more powerful, flexible, and user-friendly, adding modern features that are often required in web applications.

## Български

### Преглед на подобренията

Анализирахме и подобрихме уеб фреймуърка Prologue, написан на Nim. Ето основните подобрения, които бяха направени:

### 1. Подобрения в структурата на кода

- **Премахване на глобални променливи**: Заменихме глобалната променлива `dontUseThisShutDownEvents` в `application.nim` със структуриран `ShutdownManager`.
- **Подобрена обработка на грешки**: Добавихме по-подробно логване и подобрена обработка на изключения в метода `handleContext`.
- **Организация на кода**: Разделихме големи файлове на по-малки модули за по-добра четимост и поддръжка.

### 2. Нова функционалност

- **WebSocket стаи и канали**: Създадохме нов модул `websocket/rooms.nim` за организиране на WebSocket връзки в стаи и канали.
- **JWT аутентикация**: Добавихме нов модул `auth/jwt.nim` за създаване, проверка и използване на JWT токени.
- **Подобрена middleware система**: Подобрихме middleware системата с по-добра обработка на грешки и повече гъвкавост.

### 3. Нови примери

- **WebSocket чат**: Създадохме пълнофункционален пример за чат с поддръжка на стаи в `examples/websocket_chat/`.
- **JWT аутентикация**: Създадохме пример за аутентикация с използване на JWT в `examples/jwt_auth/`.

### 4. Подобрения в документацията

- **Двуезична документация**: Добавихме документация на английски и български език.
- **Актуализиран changelog**: Добавихме информация за новите функции във версия 0.7.0.
- **README файлове за примерите**: Създадохме подробни README файлове за новите примери.
- **API документация**: Добавихме изчерпателна API документация за новите модули.

### 5. Актуализации на пакета

- **Актуализация на версията**: Актуализирахме версията до 0.7.0 в `prologue.nimble`.
- **Нови задачи**: Добавихме нови задачи за тестване на новите примери.
- **Експорт на нови модули**: Актуализирахме `src/prologue.nim`, за да експортира новите модули.

### Модифицирани файлове

- `src/prologue/core/application.nim` - Подобрена обработка на грешки и премахнати глобални променливи
- `src/prologue.nim` - Добавени експорти за новите модули
- `prologue.nimble` - Актуализирана версия и добавени нови задачи
- `changelog.md` - Добавена информация за новите функции
- `mkdocs.yml` - Добавени нови страници с документация в навигацията

### Нови файлове

- `src/prologue/websocket/rooms.nim` - Модул за WebSocket стаи и канали
- `src/prologue/auth/jwt.nim` - Модул за JWT аутентикация
- `examples/websocket_chat/` - Пример за WebSocket чат
- `examples/jwt_auth/` - Пример за JWT аутентикация
- `docs/websocket_rooms.md` - Документация за WebSocket стаи
- `docs/jwt_auth.md` - Документация за JWT аутентикация

Тези подобрения правят Prologue по-мощен, гъвкав и удобен за потребителите, добавяйки модерни функции, които често се изискват в уеб приложенията.