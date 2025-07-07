# PostgreSQL ORM Example

Този пример демонстрира как да използвате новата PostgreSQL ORM система в Prologue framework.

## Предварителни изисквания

1. **PostgreSQL сървър** - трябва да имате инсталиран и работещ PostgreSQL сървър
2. **База данни** - създайте база данни с име `ex-orm`
3. **Nim зависимости** - добавете следните зависимости в `prologue.nimble`:

```nim
requires "db_connector >= 0.1.0"  # PostgreSQL драйвер
```

## Настройка на базата данни

```sql
-- Свържете се към PostgreSQL като администратор
CREATE DATABASE "ex-orm";
CREATE USER postgres WITH PASSWORD 'azina681024';
GRANT ALL PRIVILEGES ON DATABASE "ex-orm" TO postgres;
```

## Стартиране на примера

```bash
# От root директорията на проекта
cd examples/postgresql_orm
nim c -r app.nim
```

Сървърът ще стартира на `http://localhost:8080`

## API Endpoints

### Основни
- `GET /` - Начална страница с документация
- `GET /test` - Тест на връзката с базата данни
- `GET /stats` - Статистики за базата данни

### Потребители (Users)
- `GET /users` - Получаване на всички потребители
- `POST /users` - Създаване на нов потребител
- `GET /users/{id}` - Получаване на потребител по ID
- `PUT /users/{id}` - Обновяване на потребител
- `DELETE /users/{id}` - Изтриване на потребител

### Публикации (Posts)
- `POST /posts` - Създаване на нова публикация
- `GET /users/{userId}/posts` - Получаване на публикации по потребител

## Примери за заявки

### Създаване на потребител
```bash
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{
    "username": "john_doe",
    "email": "john@example.com",
    "fullName": "John Doe",
    "isActive": true
  }'
```

### Получаване на всички потребители
```bash
curl http://localhost:8080/users
```

### Създаване на публикация
```bash
curl -X POST http://localhost:8080/posts \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Post",
    "content": "This is the content of my first post",
    "authorId": 1
  }'
```

### Тест на връзката
```bash
curl http://localhost:8080/test
```

## Архитектура на ORM системата

### Модели
Моделите се дефинират като наследници на базовия `Model` клас:

```nim
type
  User* = ref object of Model
    username*: string
    email*: string
    fullName*: string
    isActive*: bool
    createdAt*: string
```

### CRUD операции
```nim
# Създаване
let user = User()
user.username = "john"
await user.save()

# Четене
let user = await User.objects.get(1)
let users = await User.objects.all()

# Обновяване
user.email = "new@email.com"
user.markDirty()
await user.save()

# Изтриване
await user.delete()
```

### Query Manager
```nim
# Филтриране
let activeUsers = await User.objects.all("is_active = $1", @["true"])

# Броене
let userCount = await User.objects.count()

# Проверка за съществуване
let exists = await User.objects.exists(1)
```

## Структура на файловете

```
examples/postgresql_orm/
├── app.nim          # Главното приложение
├── README.md        # Тази документация
└── config.nims      # Nim конфигурация (опционално)
```

## Функционалности на ORM

### ✅ Реализирани
- Основни CRUD операции
- Connection pooling
- PostgreSQL специфични типове
- Транзакции
- Модел валидация
- Query manager
- Автоматично създаване на таблици

### 🚧 В разработка
- Релации между модели (OneToMany, ManyToMany)
- Сложен Query Builder
- Миграции
- Lazy/Eager loading
- Batch операции

### 📋 Планирани
- CLI инструменти
- Автоматично генериране на модели
- Performance оптимизации
- Caching интеграция

## Отстраняване на проблеми

### Грешка при свързване
```
Error: Failed to connect to PostgreSQL database
```
- Проверете дали PostgreSQL сървърът работи
- Проверете потребителското име и паролата
- Проверете дали базата данни `ex-orm` съществува

### Грешка при компилиране
```
Error: cannot open file: db_connector/db_postgres
```
- Инсталирайте зависимостта: `nimble install db_connector`

### Грешка при създаване на таблица
```
Error: relation "users" already exists
```
- Това е нормално при повторно стартиране - таблиците вече съществуват

## Допълнителна информация

За повече информация относно архитектурата и планираните подобрения, вижте:
- `POSTGRESQL_ORM_ARCHITECTURE_PLAN.md` в root директорията
- Документацията на Prologue framework
- PostgreSQL документация за типове данни и заявки