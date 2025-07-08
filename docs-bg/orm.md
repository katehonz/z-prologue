# Ormin ORM (bormin) Документация

## Общ преглед
Ormin ORM (`bormin`) е разширяема библиотека за обектно-релационно съпоставяне (ORM) за Nim, предназначена за гъвкаво дефиниране на модели, управление на схеми и ефективен достъп до бази данни. Поддържа PostgreSQL и SQLite бекенди и се интегрира лесно с Nim приложения.

---

## Бърз старт

1. **Дефинирай моделите:**
```nim
import src/prologue/db/bormin/models

proc defineModels*() =
  let userModel = newModelBuilder("User")
  discard userModel.column("id", dbInt).primaryKey()
  discard userModel.column("username", dbVarchar).notNull()
  userModel.build()
defineModels()
```

2. **Свържи се с базата:**
```nim
import src/prologue/db/dbconfig
let orm = connectDb(database = "mydb", username = "user", password = "secret")
```

3. **Създай таблиците:**
```nim
let sql = generateSql(modelRegistry)
orm.conn.exec(sql)
```

4. **CRUD операции:**
```nim
# Пример: Извличане на всички потребители
echo orm.conn.fastRows("SELECT * FROM User")
```

---

## Дефиниране на модели
- Използвай `newModelBuilder("TableName")` за програмно дефиниране на модели.
- Верижно добавяй `.column`, `.primaryKey()`, `.notNull()`, `.default()`, `.foreignKey()` за ограничения на колоните.
- Регистрирай моделите глобално с `.build()`.

## Конфигуриране на базата
- Централизирано в `src/prologue/db/dbconfig.nim`.
- Използвай `connectDb()` за създаване на обект `ORM` с връзка и регистър.
- Поддържа host, port, database, username, password, pool size.

## Пул от връзки
- Ефективен асинхронен пул (виж `connectionpool.nim`).
- Използвай за скалируеми и конкурентни приложения.

## CRUD операции
- Използвай `orm.conn.exec()` за SQL команди.
- Използвай `orm.conn.fastRows()` за резултати от заявки.
- Можеш да разшириш с твои query помощници.

## Миграции
- Дефинирай и изпълнявай миграции чрез модула `migrations.nim`.
- Поддържа еволюция и версиониране на схемата.

## Интеграция
- Импортирай `bormin/models` и извикай `defineModels()` при стартиране.
- Свържи се с `connectDb` и използвай ORM в бизнес логика или handler-и.

## Разширяване
- Добави нови бекенди чрез имплементация на интерфейса DbConn.
- Разшири регистъра на модели или query builder-а по нужда.

## Често задавани въпроси
- **В:** Как да добавя нова колона?  
  **О:** Промени дефиницията на модела и изпълни отново миграциите или генерирането на SQL.
- **В:** Как да сменя бекенда?  
  **О:** Импортирай съответния модул и промени connection string-а.

---

За повече примери виж `main_ormin_example.nim` и папка `examples/`.
