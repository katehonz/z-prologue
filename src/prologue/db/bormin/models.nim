## Ormin -- ORM for Nim.
## Model definition module
##
## [English]
## This module provides the core functionality for defining database models in Ormin.
## Ormin is an Object-Relational Mapping (ORM) library for the Nim programming language,
## allowing developers to work with databases using Nim objects instead of writing raw SQL.
##
## Key features:
## * Define database tables and columns using a simple DSL
## * Support for various column types (int, float, varchar, etc.)
## * Primary key and foreign key constraints
## * Object-oriented API for model definition
## * SQL generation for creating database schemas
##
## Example usage:
## ```nim
## # Define a model using the DSL
## model "User":
##   id: int, primaryKey
##   username: string, notNull
##   email: string, notNull
##
## # Define a model using the object-oriented API
## let postModel = newModelBuilder("Post")
## discard postModel.column("id", dbInt).primaryKey()
## discard postModel.column("user_id", dbInt).notNull().foreignKey("User", "id")
## discard postModel.column("title", dbVarchar).notNull()
## postModel.build()
## ```
##
## [Български]
## Този модул предоставя основната функционалност за дефиниране на модели на бази данни в Ormin.
## Ormin е библиотека за обектно-релационно съпоставяне (ORM) за програмния език Nim,
## позволяваща на разработчиците да работят с бази данни, използвайки обекти на Nim вместо да пишат чист SQL.
##
## Основни характеристики:
## * Дефиниране на таблици и колони в базата данни чрез прост DSL
## * Поддръжка на различни типове колони (int, float, varchar и др.)
## * Ограничения за първичен и външен ключ
## * Обектно-ориентиран API за дефиниране на модели
## * Генериране на SQL за създаване на схеми на бази данни
##
## Пример за използване:
## ```nim
## # Дефиниране на модел чрез DSL
## model "User":
##   id: int, primaryKey
##   username: string, notNull
##   email: string, notNull
##
## # Дефиниране на модел чрез обектно-ориентирания API
## let postModel = newModelBuilder("Post")
## discard postModel.column("id", dbInt).primaryKey()
## discard postModel.column("user_id", dbInt).notNull().foreignKey("User", "id")
## discard postModel.column("title", dbVarchar).notNull()
## postModel.build()
## ```

import std/macros, std/strutils, std/tables, std/sequtils

type
  ORM* = object
    conn*: DbConn
    registry*: ModelRegistry
  DbTypeKind* = enum
    ## [English] Enumeration of supported database column types
    ## [Български] Изброяване на поддържаните типове колони в базата данни
    dbInt, dbFloat, dbVarchar, dbFixedChar, dbBool, dbTimestamp, dbDateTime, dbText

  DbConn* = ref object
    ## [English] Abstract type for database connection
    ## [Български] Абстрактен тип за връзка с база данни
    ## Абстрактный тип для соединения с базой данных

  DbError* = object of CatchableError
    ## [English] Exception type for database errors
    ## [Български] Тип изключение за грешки в базата данни
    ## Тип исключения для ошибок базы данных

  Column* = object
    ## [English] Represents a database column with its properties
    ## [Български] Представлява колона в базата данни със своите свойства
    name*: string          ## Column name / Име на колоната
    typ*: DbTypeKind       ## Column type / Тип на колоната
    primaryKey*: bool      ## Is primary key / Дали е първичен ключ
    notNull*: bool         ## Is NOT NULL / Дали е NOT NULL
    foreignKey*: tuple[table, column: string]  ## Foreign key reference / Референция към външен ключ
    default*: string       ## Default value / Стойност по подразбиране
    
  Table* = object
    ## [English] Represents a database table with its columns
    ## [Български] Представлява таблица в базата данни с нейните колони
    name*: string          ## Table name / Име на таблицата
    columns*: seq[Column]  ## Table columns / Колони на таблицата

  ModelRegistry* = ref object
    ## [English] Registry of all database models/tables in the application
    ## [Български] Регистър на всички модели/таблици в базата данни в приложението
    tables*: OrderedTable[string, Table]  ## Tables by name / Таблици по име

  # Новые типы для объектно-ориентированного определения моделей
  ModelBuilder* = ref object
    ## [English] Builder for creating database models in an object-oriented way
    ## [Български] Строител за създаване на модели на базата данни по обектно-ориентиран начин
    name*: string          ## Model name / Име на модела
    columns*: seq[Column]  ## Model columns / Колони на модела

  ColumnBuilder* = ref object
    ## [English] Builder for creating database columns with a fluent API
    ## [Български] Строител за създаване на колони в базата данни с плавен API
    name*: string          ## Column name / Име на колоната
    typ*: DbTypeKind       ## Column type / Тип на колоната
    primaryKey*: bool      ## Is primary key / Дали е първичен ключ
    notNull*: bool         ## Is NOT NULL / Дали е NOT NULL
    foreignKey*: tuple[table, column: string]  ## Foreign key reference / Референция към външен ключ
    default*: string       ## Default value / Стойност по подразбиране

# Заглушки для методов работы с базой данных
proc exec*(db: DbConn, query: string, args: varargs[string, `$`]) =
  ## Заглушка для выполнения SQL-запроса
  echo "Executing SQL: ", query
  if args.len > 0:
    echo "  with args: ", args.join(", ")

proc fastRows*(db: DbConn, query: string, args: varargs[string, `$`]): seq[seq[string]] =
  ## Заглушка для получения результатов запроса
  echo "Executing query: ", query
  
  # Для запроса миграций возвращаем пустой результат
  if query.contains("ormin_migrations"):
    result = @[]
  # Для запроса пользователей
  elif query.contains("SELECT id, username, email FROM User"):
    result = @[@["1", "test", "test@example.com"]]
  # Для запроса постов с JOIN
  elif query.contains("JOIN User"):
    result = @[@["1", "Test Post", "This is a test post", "test"]]
  # Для запроса постов
  elif query.contains("Post"):
    result = @[@["1", "Test Post", "This is a test post"]]
  # Для запроса с RETURNING id
  elif query.contains("RETURNING id"):
    result = @[@["1"]]
  # Для всех остальных запросов
  else:
    result = @[@["1", "Test Comment", "Test Post"]]

proc close*(db: DbConn) =
  ## Заглушка для закрытия соединения с базой данных
  echo "Closing database connection"

template sql*(query: string): string =
  ## Заглушка для шаблона sql
  query

proc open*(filename, user, password, database: string): DbConn =
  ## Заглушка для функции открытия соединения с базой данных
  echo "Opening database: ", filename
  return DbConn()

# Инициализация реестра моделей

var modelRegistry* = ModelRegistry(tables: initOrderedTable[string, Table]())

proc registerTable*(name: string, columns: seq[Column]) =
  ## [English] Registers a table in the model registry
  ##
  ## This function adds a new table with the specified name and columns
  ## to the global model registry.
  ##
  ## [Български] Регистрира таблица в регистъра на моделите
  ##
  ## Тази функция добавя нова таблица със зададеното име и колони
  ## към глобалния регистър на моделите.
  modelRegistry.tables[name] = Table(name: name, columns: columns)

proc getTable*(name: string): Table =
  ## [English] Gets a table from the model registry by name
  ##
  ## Raises KeyError if the table is not found.
  ##
  ## [Български] Получава таблица от регистъра на моделите по име
  ##
  ## Предизвиква KeyError, ако таблицата не е намерена.
  if not modelRegistry.tables.hasKey(name):
    raise newException(KeyError, "Table not found: " & name)
  
  return modelRegistry.tables[name]

proc generateSql*(registry: ModelRegistry): string =
  ## [English] Generates SQL for all tables in the registry
  ##
  ## Creates SQL CREATE TABLE statements for all tables in the registry,
  ## including column definitions, primary keys, and foreign key constraints.
  ##
  ## [Български] Генерира SQL за всички таблици в регистъра
  ##
  ## Създава SQL CREATE TABLE заявки за всички таблици в регистъра,
  ## включително дефиниции на колони, първични ключове и ограничения за външни ключове.
  result = ""
  
  for name, table in registry.tables:
    result.add("CREATE TABLE IF NOT EXISTS " & name & "(\n")
    
    var columnDefs: seq[string] = @[]
    var foreignKeys: seq[string] = @[]
    
    for column in table.columns:
      var columnDef = "  " & column.name & " " & $column.typ
      
      if column.notNull:
        columnDef.add(" NOT NULL")
      
      if column.primaryKey:
        columnDef.add(" PRIMARY KEY")
      
      if column.default != "":
        columnDef.add(" DEFAULT " & column.default)
      
      columnDefs.add(columnDef)
      
      if column.foreignKey.table != "" and column.foreignKey.column != "":
        let fkDef = "  FOREIGN KEY (" & column.name & ") REFERENCES " &
                    column.foreignKey.table & "(" & column.foreignKey.column & ")"
        foreignKeys.add(fkDef)
    
    result.add(columnDefs.join(",\n"))
    
    if foreignKeys.len > 0:
      result.add(",\n")
      result.add(foreignKeys.join(",\n"))
    
    result.add("\n);\n\n")

# Объектно-ориентированный API для определения моделей

proc newModelBuilder*(name: string): ModelBuilder =
  ## [English] Creates a new model builder
  ##
  ## This is the starting point for creating a model using the object-oriented API.
  ## Returns a ModelBuilder instance that can be used to add columns and build the model.
  ##
  ## [Български] Създава нов строител на модел
  ##
  ## Това е началната точка за създаване на модел с помощта на обектно-ориентирания API.
  ## Връща екземпляр на ModelBuilder, който може да се използва за добавяне на колони и изграждане на модела.
  ##
  ## Создает новый построитель модели
  return ModelBuilder(name: name, columns: @[])

proc column*(model: ModelBuilder, name: string, typ: DbTypeKind): ColumnBuilder =
  ## [English] Adds a new column to the model
  ##
  ## Returns a ColumnBuilder instance that can be used to set column properties
  ## using a fluent API (method chaining).
  ##
  ## [Български] Добавя нова колона към модела
  ##
  ## Връща екземпляр на ColumnBuilder, който може да се използва за задаване на свойства на колоната
  ## с помощта на плавен API (верига от методи).
  ##
  ## Добавляет новую колонку к модели
  let newColumn = Column(
    name: name,
    typ: typ,
    primaryKey: false,
    notNull: false,
    foreignKey: ("", ""),
    default: ""
  )
  
  model.columns.add(newColumn)
  
  # Создаем ColumnBuilder для цепочки методов
  result = ColumnBuilder(
    name: name,
    typ: typ,
    primaryKey: false,
    notNull: false,
    foreignKey: ("", ""),
    default: ""
  )
  
  # Проверяем, зарегистрирована ли уже модель
  if modelRegistry.tables.hasKey(model.name):
    # Если да, добавляем колонку к существующей модели
    modelRegistry.tables[model.name].columns.add(newColumn)
  
  return result

proc primaryKey*(column: ColumnBuilder): ColumnBuilder =
  ## [English] Sets the column as a primary key
  ##
  ## This method marks the column as a primary key in the database schema.
  ## Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Задава колоната като първичен ключ
  ##
  ## Този метод маркира колоната като първичен ключ в схемата на базата данни.
  ## Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Устанавливает колонку как первичный ключ
  column.primaryKey = true
  # Обновляем последнюю добавленную колонку в модели
  var modelName = ""
  var columnIdx = -1
  
  # Находим модель и индекс колонки
  for name, table in modelRegistry.tables:
    for i, col in table.columns:
      if col.name == column.name:
        modelName = name
        columnIdx = i
        break
    if modelName != "":
      break
  
  # Если нашли колонку, обновляем её
  if modelName != "" and columnIdx >= 0:
    modelRegistry.tables[modelName].columns[columnIdx].primaryKey = true
  
  return column

proc notNull*(column: ColumnBuilder): ColumnBuilder =
  ## [English] Sets the column as NOT NULL
  ##
  ## This method marks the column as NOT NULL in the database schema,
  ## which means it cannot contain NULL values.
  ## Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Задава колоната като NOT NULL
  ##
  ## Този метод маркира колоната като NOT NULL в схемата на базата данни,
  ## което означава, че не може да съдържа NULL стойности.
  ## Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Устанавливает колонку как NOT NULL
  column.notNull = true
  # Обновляем последнюю добавленную колонку в модели
  var modelName = ""
  var columnIdx = -1
  
  # Находим модель и индекс колонки
  for name, table in modelRegistry.tables:
    for i, col in table.columns:
      if col.name == column.name:
        modelName = name
        columnIdx = i
        break
    if modelName != "":
      break
  
  # Если нашли колонку, обновляем её
  if modelName != "" and columnIdx >= 0:
    modelRegistry.tables[modelName].columns[columnIdx].notNull = true
  
  return column

proc default*(column: ColumnBuilder, value: string): ColumnBuilder =
  ## [English] Sets the default value for the column
  ##
  ## This method sets the default value that will be used when no value is provided
  ## during insertion. Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Задава стойност по подразбиране за колоната
  ##
  ## Този метод задава стойността по подразбиране, която ще се използва, когато не е предоставена
  ## стойност при вмъкване. Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Устанавливает значение по умолчанию для колонки
  column.default = value
  # Обновляем последнюю добавленную колонку в модели
  var modelName = ""
  var columnIdx = -1
  
  # Находим модель и индекс колонки
  for name, table in modelRegistry.tables:
    for i, col in table.columns:
      if col.name == column.name:
        modelName = name
        columnIdx = i
        break
    if modelName != "":
      break
  
  # Если нашли колонку, обновляем её
  if modelName != "" and columnIdx >= 0:
    modelRegistry.tables[modelName].columns[columnIdx].default = value
  
  return column

proc foreignKey*(column: ColumnBuilder, table, refColumn: string): ColumnBuilder =
  ## [English] Sets a foreign key reference for the column
  ##
  ## This method creates a foreign key constraint that references another table's column.
  ## Parameters:
  ## * table: The name of the referenced table
  ## * refColumn: The name of the referenced column
  ## Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Задава референция към външен ключ за колоната
  ##
  ## Този метод създава ограничение за външен ключ, който реферира към колона от друга таблица.
  ## Параметри:
  ## * table: Името на референтната таблица
  ## * refColumn: Името на референтната колона
  ## Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Устанавливает внешний ключ для колонки
  column.foreignKey = (table, refColumn)
  # Обновляем последнюю добавленную колонку в модели
  var modelName = ""
  var columnIdx = -1
  
  # Находим модель и индекс колонки
  for name, table in modelRegistry.tables:
    for i, col in table.columns:
      if col.name == column.name:
        modelName = name
        columnIdx = i
        break
    if modelName != "":
      break
  
  # Если нашли колонку, обновляем её
  if modelName != "" and columnIdx >= 0:
    modelRegistry.tables[modelName].columns[columnIdx].foreignKey = (table, refColumn)
  
  return column

proc build*(model: ModelBuilder) =
  ## [English] Registers the model in the registry
  ##
  ## This method finalizes the model definition and registers it in the global model registry.
  ## Call this method after defining all columns and their properties.
  ##
  ## [Български] Регистрира модела в регистъра
  ##
  ## Този метод финализира дефиницията на модела и го регистрира в глобалния регистър на моделите.
  ## Извикайте този метод след като дефинирате всички колони и техните свойства.
  ##
  ## Регистрирует модель в реестре
  registerTable(model.name, model.columns)

# Макросы для определения моделей

macro model*(name: string, body: untyped): untyped =
  ## [English] Macro for defining a database model
  ##
  ## This macro provides a DSL (Domain Specific Language) for defining database models
  ## in a declarative way. It processes the body to extract column definitions and
  ## registers the model in the global registry.
  ##
  ## Example:
  ## ```nim
  ## model "User":
  ##   username: string, primaryKey
  ##   email: string, notNull
  ##   age: int
  ## ```
  ##
  ## [Български] Макрос за дефиниране на модел на база данни
  ##
  ## Този макрос предоставя DSL (Domain Specific Language) за дефиниране на модели на бази данни
  ## по декларативен начин. Той обработва тялото, за да извлече дефиниции на колони и
  ## регистрира модела в глобалния регистър.
  ##
  ## Пример:
  ## ```nim
  ## model "User":
  ##   username: string, primaryKey
  ##   email: string, notNull
  ##   age: int
  ## ```
  
  result = newStmtList()
  
  let tableName = name.strVal
  var columns: seq[NimNode] = @[]
  
  # Process the body to extract column definitions
  for def in body:
    if def.kind == nnkCall:
      let columnName = $def[0]
      let columnType = $def[1][0]
      var primaryKey = false
      var notNull = false
      var foreignKey = ("", "")
      var default = ""
      
      # Process column attributes
      for i in 1..<def[1].len:
        let attr = def[1][i]
        if attr.kind == nnkIdent:
          case $attr
          of "primaryKey": primaryKey = true
          of "notNull": notNull = true
          else: discard
        elif attr.kind == nnkCall and $attr[0] == "foreignKey":
          foreignKey = ($attr[1], $attr[2])
        elif attr.kind == nnkCall and $attr[0] == "default":
          default = $attr[1]
      
      # Convert column type to DbTypeKind
      var dbType = "db" & capitalizeAscii(columnType)
      
      # Create column definition
      let column = quote do:
        Column(
          name: `columnName`,
          typ: DbTypeKind.`dbType`,
          primaryKey: `primaryKey`,
          notNull: `notNull`,
          foreignKey: (`foreignKey`[0], `foreignKey`[1]),
          default: `default`
        )
      
      columns.add(column)
  
  # Create the table registration
  let columnsArray = nnkBracket.newTree(columns)
  
  result.add quote do:
    registerTable(`tableName`, @`columnsArray`)

# Упрощенная версия макроса для определения моделей в стиле DSL
template defineModel*(body: untyped) =
  ## [English] Simplified version of the model definition macro in DSL style
  ##
  ## This template is for demonstration purposes only. In a real implementation,
  ## it would process a DSL for model definition.
  ##
  ## [Български] Опростена версия на макроса за дефиниране на модел в DSL стил
  ##
  ## Този шаблон е само за демонстрационни цели. В реална имплементация,
  ## той би обработвал DSL за дефиниране на модел.
  ##
  ## Упрощенная версия макроса для определения модели в стиле DSL
  ## Для демонстрационных целей
  echo "DSL model definition processed"
  
  # В реальной реализации здесь был бы код для обработки DSL
  # Но для демонстрации мы просто создадим модели напрямую
  
  # Создаем модель User
  let userModel = newModelBuilder("User")
  discard userModel.column("id", dbInt).primaryKey()
  discard userModel.column("username", dbVarchar).notNull()
  discard userModel.column("email", dbVarchar).notNull()
  discard userModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  userModel.build()
  
  # Создаем модель Post
  let postModel = newModelBuilder("Post")
  discard postModel.column("id", dbInt).primaryKey()
  discard postModel.column("user_id", dbInt).notNull().foreignKey("User", "id")
  discard postModel.column("title", dbVarchar).notNull()
  discard postModel.column("content", dbVarchar).notNull()
  discard postModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  postModel.build()

proc createModels*() =
  ## [English] Generates type definitions for all models in the registry
  ##
  ## This is a stub implementation for demonstration purposes.
  ## In a real implementation, this would generate actual Nim type definitions
  ## based on the models registered in the global registry.
  ##
  ## [Български] Генерира дефиниции на типове за всички модели в регистъра
  ##
  ## Това е заглушка за демонстрационни цели.
  ## В реална имплементация, това би генерирало действителни дефиниции на типове в Nim
  ## въз основа на моделите, регистрирани в глобалния регистър.
  ##
  ## Generates type definitions for all models in the registry
  ## This is a stub implementation for demonstration purposes
  echo "Creating model types for:"
  for name, table in modelRegistry.tables:
    echo "  - ", name, " with ", table.columns.len, " columns"
    
    # In a real implementation, this would generate actual type definitions
    # But for our demo, we'll just print the model information
    for column in table.columns:
      let typeName = case column.typ
        of dbInt: "int"
        of dbFloat: "float"
        of dbVarchar, dbFixedChar, dbText: "string"
        of dbBool: "bool"
        of dbTimestamp, dbDateTime: "DateTime"
        else: "string"
      
      echo "    * ", column.name, ": ", typeName