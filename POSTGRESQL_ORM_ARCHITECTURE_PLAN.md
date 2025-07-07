# 🏗️ Архитектурен план за PostgreSQL ORM в Prologue

## Преглед

Този документ описва архитектурния план за създаване на специализирана PostgreSQL ORM система за Prologue web framework. Планът е разделен на етапи за постепенно развитие и подобрение.

## 📊 Текущо състояние

### Анализ на съществуващия код
- ✅ **Connection Pool**: Има абстрактна имплементация в `src/prologue/db/connectionpool.nim`
- ❌ **ORM система**: Липсва специализиран ORM
- ⚠️ **Примери**: Използват SQLite с директни SQL заявки
- ✅ **Архитектура**: Модулна структура с отделни папки

### Съществуващи зависимости
```nim
requires "nim >= 2.0.0"
requires "regex >= 0.20.0"
requires "nimcrypto >= 0.5.4"
requires "cookiejar >= 0.2.0"
requires "httpx >= 0.3.7"
requires "logue >= 0.2.0"
```

## 🏛️ Архитектурна диаграма

```mermaid
graph TB
    A[Prologue App] --> B[ORM Manager]
    B --> C[Connection Pool]
    B --> D[Model Registry]
    B --> E[Query Builder]
    
    C --> F[PostgreSQL Driver]
    D --> G[Model Definitions]
    E --> H[SQL Generator]
    
    G --> I[User Model]
    G --> J[Post Model]
    G --> K[Custom Models]
    
    H --> L[SELECT Queries]
    H --> M[INSERT Queries]
    H --> N[UPDATE Queries]
    H --> O[DELETE Queries]
```

## 📁 Структура на файловете

```
src/prologue/db/
├── connectionpool.nim          # ✅ Съществува
├── orm/
│   ├── orm.nim                # Главен ORM модул
│   ├── model.nim              # Базов модел клас
│   ├── field.nim              # Дефиниции на полета
│   ├── query.nim              # Query builder
│   ├── migration.nim          # Система за миграции
│   ├── relation.nim           # Релации между модели
│   └── postgres/
│       ├── driver.nim         # PostgreSQL драйвер
│       ├── types.nim          # PostgreSQL типове
│       └── sql_generator.nim  # SQL генератор
```

## 🚀 Етапи на разработка

### **Етап 1: Основна архитектура (1-2 седмици)**

#### Цели:
- Създаване на базовата ORM архитектура
- Интеграция с PostgreSQL драйвер
- Основни CRUD операции

#### Файлове за създаване:
1. `src/prologue/db/orm/orm.nim` - Главен ORM модул
2. `src/prologue/db/orm/postgres/driver.nim` - PostgreSQL драйвер
3. `src/prologue/db/orm/postgres/types.nim` - PostgreSQL типове

#### Функционалности:
```nim
# Основна конфигурация
let app = newApp()
app.initORM(
  driver: "postgresql",
  host: "localhost",
  port: 5432,
  database: "myapp",
  username: "user",
  password: "pass",
  maxConnections: 20
)
```

### **Етап 2: Model система (2-3 седмици)**

#### Цели:
- Дефиниция на модели
- Основни CRUD операции
- Валидация на данни

#### Файлове за създаване:
1. `src/prologue/db/orm/model.nim` - Базов модел клас
2. `src/prologue/db/orm/field.nim` - Дефиниции на полета

#### Функционалности:
```nim
# Дефиниция на модел
type
  User* = ref object of Model
    id*: int {.primary_key.}
    username*: string {.unique, max_length: 50.}
    email*: string {.unique.}
    created_at*: DateTime {.auto_now_add.}
    updated_at*: DateTime {.auto_now.}

# Основни операции
let user = User(username: "john", email: "john@example.com")
await user.save()

let foundUser = await User.objects.get(id=1)
await foundUser.delete()
```

### **Етап 3: Query Builder и миграции (2-3 седмици)**

#### Цели:
- Сложни заявки
- Система за миграции
- SQL генератор

#### Файлове за създаване:
1. `src/prologue/db/orm/query.nim` - Query builder
2. `src/prologue/db/orm/migration.nim` - Система за миграции
3. `src/prologue/db/orm/postgres/sql_generator.nim` - SQL генератор

#### Функционалности:
```nim
# Query Builder
let users = await User.objects
  .filter("age > ?", 18)
  .orderBy("username")
  .limit(10)

# Миграции
await createMigration("add_user_table")
await runMigrations()
```

### **Етап 4: Релации и валидация (1-2 седмици)**

#### Цели:
- OneToMany, ManyToOne, ManyToMany релации
- Lazy/Eager loading
- Разширена валидация

#### Файлове за създаване:
1. `src/prologue/db/orm/relation.nim` - Релации между модели

#### Функционалности:
```nim
# Релации
type
  User* = ref object of Model
    posts*: seq[Post] {.one_to_many: "author_id".}
  
  Post* = ref object of Model
    author*: User {.many_to_one: "author_id".}

# Използване
let user = await User.objects.get(id=1)
let posts = await user.posts.all()  # Lazy loading
```

### **Етап 5: Performance оптимизации (1-2 седмици)**

#### Цели:
- Prepared statements
- Batch операции
- Query optimization
- Caching интеграция

#### Функционалности:
```nim
# Batch операции
await User.objects.bulkCreate([user1, user2, user3])

# Prepared statements (автоматично)
let users = await User.objects.filter("status = ?", "active")
```

### **Етап 6: Developer tools (1 седмица)**

#### Цели:
- CLI команди
- Debug tools
- Документация

#### Функционалности:
```bash
# CLI команди
prologue generate model User username:string email:string
prologue generate migration add_index_to_users
prologue migrate
```

## 🔧 Технически спецификации

### Нови зависимости
```nim
# Добавки в prologue.nimble
requires "db_connector >= 0.1.0"  # PostgreSQL драйвер
requires "times >= 1.0.0"         # DateTime поддръжка
requires "json >= 1.0.0"          # JSON сериализация
```

### Конфигурация
```nim
# В Prologue приложение
import prologue/db/orm

let app = newApp()
app.initORM(
  connectionString: "postgresql://user:pass@localhost:5432/mydb",
  maxConnections: 20,
  minConnections: 5
)
```

### Интеграция с Context
```nim
proc getUserProfile(ctx: Context) {.async.} =
  let userId = ctx.getPathParams("id").parseInt
  let user = await User.objects.get(id=userId)
  resp jsonResponse(user.toJson())
```

## 📝 Примери за използване

### Основни операции
```nim
# Създаване
let user = User(username: "john", email: "john@example.com")
await user.save()

# Четене
let user = await User.objects.get(id=1)
let users = await User.objects.filter("age > ?", 18).all()

# Обновяване
user.email = "newemail@example.com"
await user.save()

# Изтриване
await user.delete()
```

### Сложни заявки
```nim
# JOIN заявки
let usersWithPosts = await User.objects
  .select("users.*, COUNT(posts.id) as post_count")
  .join("posts", "users.id = posts.author_id")
  .groupBy("users.id")
  .having("post_count > ?", 5)
  .all()

# Subqueries
let activeUsers = await User.objects
  .filter("id IN (SELECT DISTINCT author_id FROM posts WHERE created_at > ?)", 
          now() - 30.days)
  .all()
```

### Транзакции
```nim
await withTransaction:
  let user = User(username: "john")
  await user.save()
  
  let post = Post(title: "Hello", author_id: user.id)
  await post.save()
```

## 🎯 Ключови предимства

1. **Type Safety**: Пълна типова безопасност с Nim
2. **Performance**: Оптимизирано за PostgreSQL
3. **Async**: Пълна async поддръжка
4. **Integration**: Тясна интеграция с Prologue
5. **Developer Experience**: Лесно за използване API
6. **Extensibility**: Модулна архитектура за разширения

## 🔄 Миграционна стратегия

### От съществуващи SQLite примери
```nim
# Преди (SQLite)
let db = open("todo.db", "", "", "")
let rows = db.getAllRows(sql"SELECT * FROM todo")
db.close()

# След (PostgreSQL ORM)
let todos = await Todo.objects.all()
```

### Постепенна миграция
1. Запазване на съществуващия connection pool
2. Добавяне на ORM като опционална функционалност
3. Примери за миграция от директни SQL заявки
4. Backward compatibility за съществуващи приложения

## 📚 Документация и тестове

### Структура на документацията
```
docs/
├── orm/
│   ├── quickstart.md
│   ├── models.md
│   ├── queries.md
│   ├── migrations.md
│   ├── relations.md
│   └── performance.md
```

### Тестова покритие
- Unit тестове за всеки модул
- Integration тестове с PostgreSQL
- Performance тестове
- Example приложения

## 🚦 Следващи стъпки

1. **Одобрение на плана**: Преглед и одобрение на архитектурата
2. **Setup на development environment**: PostgreSQL, тестова база данни
3. **Започване на Етап 1**: Създаване на основната архитектура
4. **Итеративно развитие**: Следване на етапите с редовни прегледи

---

*Този план е жив документ и ще се актуализира според нуждите и обратната връзка по време на разработката.*