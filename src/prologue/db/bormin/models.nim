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

import std/macros, std/strutils, std/tables, std/asyncdispatch

type
  ORM* = object
    conn*: DbConn
    registry*: ModelRegistry
  DbTypeKind* = enum
    ## [English] Enumeration of supported database column types
    ## [Български] Изброяване на поддържаните типове колони в базата данни
    dbInt, dbFloat, dbVarchar, dbFixedChar, dbBool, dbTimestamp, dbDateTime, dbText,
    dbDecimal, dbNumeric, dbMoney,  ## Financial data types / Типове за финансови данни
    dbJson, dbJsonb  ## JSON data types for PostgreSQL / JSON типове данни за PostgreSQL

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
    precision*: int        ## For decimal types - total digits / За decimal типове - общо цифри
    scale*: int            ## For decimal types - decimal places / За decimal типове - десетични места
    unique*: bool          ## Is UNIQUE constraint / Дали е UNIQUE ограничение
    check*: string         ## CHECK constraint / CHECK ограничение
    
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

  # Transaction types for ACID compliance
  Transaction* = ref object
    ## [English] Database transaction for ACID operations
    ## [Български] Транзакция в базата данни за ACID операции
    conn*: DbConn
    active*: bool
    rollbackOnly*: bool
    
  TransactionError* = object of CatchableError
    ## [English] Exception type for transaction errors
    ## [Български] Тип изключение за грешки в транзакциите
    
  IsolationLevel* = enum
    ## [English] Transaction isolation levels
    ## [Български] Нива на изолация на транзакциите
    ilReadUncommitted = "READ UNCOMMITTED"
    ilReadCommitted = "READ COMMITTED"
    ilRepeatableRead = "REPEATABLE READ"
    ilSerializable = "SERIALIZABLE"

  ColumnBuilder* = ref object
    ## [English] Builder for creating database columns with a fluent API
    ## [Български] Строител за създаване на колони в базата данни с плавен API
    column*: ptr Column    ## Reference to the actual column / Референция към истинската колона
    modelName*: string     ## Model name for registry updates / Име на модела за registry обновления

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

proc dbTypeToSql*(dbType: DbTypeKind, precision: int = 0, scale: int = 0): string =
  ## [English] Converts DbTypeKind to SQL type string
  ## [Български] Конвертира DbTypeKind в SQL тип string
  case dbType:
  of dbInt: "INTEGER"
  of dbFloat: "REAL"
  of dbVarchar: "VARCHAR(255)"
  of dbFixedChar: "CHAR(255)"
  of dbBool: "BOOLEAN"
  of dbTimestamp: "TIMESTAMP"
  of dbDateTime: "DATETIME"
  of dbText: "TEXT"
  of dbDecimal:
    if precision > 0 and scale >= 0:
      "DECIMAL(" & $precision & "," & $scale & ")"
    else:
      "DECIMAL(15,2)"  # Default for financial data
  of dbNumeric:
    if precision > 0 and scale >= 0:
      "NUMERIC(" & $precision & "," & $scale & ")"
    else:
      "NUMERIC(15,2)"  # Default for financial data
  of dbMoney: "MONEY"
  of dbJson: "JSON"
  of dbJsonb: "JSONB"

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
      var columnDef = "  " & column.name & " " & dbTypeToSql(column.typ, column.precision, column.scale)
      
      if column.notNull:
        columnDef.add(" NOT NULL")
      
      if column.unique:
        columnDef.add(" UNIQUE")
      
      if column.primaryKey:
        columnDef.add(" PRIMARY KEY")
      
      if column.default != "":
        columnDef.add(" DEFAULT " & column.default)
      
      if column.check != "":
        columnDef.add(" CHECK (" & column.check & ")")
      
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
    default: "",
    precision: 0,
    scale: 0,
    unique: false,
    check: ""
  )
  
  model.columns.add(newColumn)
  
  # Создаем ColumnBuilder с референцией към реалната колона
  result = ColumnBuilder(
    column: addr model.columns[^1],  # Reference to last added column
    modelName: model.name
  )
  
  return result

proc column*(model: ModelBuilder, name: string, typ: DbTypeKind, precision: int, scale: int): ColumnBuilder =
  ## [English] Adds a new column to the model with precision and scale (for decimal types)
  ##
  ## Returns a ColumnBuilder instance that can be used to set column properties
  ## using a fluent API (method chaining). Used primarily for decimal/numeric types.
  ##
  ## [Български] Добавя нова колона към модела с точност и мащаб (за десетични типове)
  ##
  ## Връща екземпляр на ColumnBuilder, който може да се използва за задаване на свойства на колоната
  ## с помощта на плавен API (верига от методи). Използва се главно за decimal/numeric типове.
  ##
  ## Добавляет новую колонку к модели с точностью и масштабом (для десятичных типов)
  let newColumn = Column(
    name: name,
    typ: typ,
    primaryKey: false,
    notNull: false,
    foreignKey: ("", ""),
    default: "",
    precision: precision,
    scale: scale,
    unique: false,
    check: ""
  )
  
  model.columns.add(newColumn)
  
  # Создаем ColumnBuilder с референцией към реалната колона
  result = ColumnBuilder(
    column: addr model.columns[^1],  # Reference to last added column
    modelName: model.name
  )
  
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
  column.column.primaryKey = true
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
  column.column.notNull = true
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
  column.column.default = value
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
  column.column.foreignKey = (table, refColumn)
  return column

proc decimal*(column: ColumnBuilder, precision: int, scale: int): ColumnBuilder =
  ## [English] Sets decimal precision and scale for financial columns
  ##
  ## This method configures decimal precision (total digits) and scale (decimal places)
  ## for financial data columns. Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Задава точност и мащаб на decimal за финансови колони
  ##
  ## Този метод конфигурира decimal точност (общо цифри) и мащаб (десетични места)
  ## за колони с финансови данни. Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Устанавливает точность и масштаб decimal для финансовых колонок
  column.column.precision = precision
  column.column.scale = scale
  return column

proc unique*(column: ColumnBuilder): ColumnBuilder =
  ## [English] Sets the column as UNIQUE constraint
  ##
  ## This method marks the column with UNIQUE constraint in the database schema.
  ## Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Задава колоната с UNIQUE ограничение
  ##
  ## Този метод маркира колоната с UNIQUE ограничение в схемата на базата данни.
  ## Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Устанавливает колонку с ограничением UNIQUE
  column.column.unique = true
  return column

proc check*(column: ColumnBuilder, constraint: string): ColumnBuilder =
  ## [English] Adds CHECK constraint to the column
  ##
  ## This method adds a CHECK constraint for business rule validation.
  ## Returns the ColumnBuilder for method chaining.
  ##
  ## [Български] Добавя CHECK ограничение към колоната
  ##
  ## Този метод добавя CHECK ограничение за валидация на бизнес правила.
  ## Връща ColumnBuilder за верижно извикване на методи.
  ##
  ## Добавляет ограничение CHECK к колонке
  column.column.check = constraint
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
          default: `default`,
          precision: 0,
          scale: 0,
          unique: false,
          check: ""
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

# Добавяне на метод за масово вмъкване (bulk insert) - TODO: Implement when Model type is defined
when false:
  discard """
  proc saveBulk*(models: seq[Model]; db: DbConn = nil): Future[void] {.async.} =
  ## Запазва множество модели с една базова заявка (масово вмъкване)
  if models.len == 0:
    return
  
  let modelType = type(models[0])
  let table = modelType.getTable()
  var columns: seq[string] = @[]
  var valuesList: seq[seq[string]] = @[]
  
  # Събиране на колоните
  for column in table.columns:
    if not column.primaryKey or column.default == "":
      columns.add(column.name)
  
  # Събиране на стойностите за всички модели
  for model in models:
    var modelValues: seq[string] = @[]
    for column in table.columns:
      if not column.primaryKey or column.default == "":
        let value = model.getColumnValue(column.name)
        modelValues.add(toSqlValue(value, column.typ))
    valuesList.add(modelValues)
  
  # Генериране на SQL заявката
  let placeholders = newSeqWith(columns.len, "?").join(", ")
  let valuesPlaceholders = newSeqWith(models.len, "(" & placeholders & ")").join(", ")
  
  let sql = "INSERT INTO " & table.name & " (" & columns.join(", ") & ") VALUES " & valuesPlaceholders
  
  # Изпълнение на заявката
  let conn = if db != nil: db else: getORM().conn
  var params: seq[string] = @[]
  for values in valuesList:
    params.add(values)
  
  conn.exec(sql, params)
  """

# Добавяне на метод за пагинация - TODO: Implement when Model type is defined
when false:
  discard """
  proc paginate*(modelType: typedesc[Model]; page: int; pageSize: int = 10; db: DbConn = nil): Future[seq[Model]] {.async.} =
  ## Връща странична група от записи със зададен размер
  if page < 1:
    raise newException(ValueError, "Page number must be >= 1")
  if pageSize < 1:
    raise newException(ValueError, "Page size must be >= 1")
  
  let offset = (page - 1) * pageSize
  let sql = "SELECT * FROM " & modelType.getTable().name & " LIMIT " & $pageSize & " OFFSET " & $offset
  
  let conn = if db != nil: db else: getORM().conn
  let rows = await conn.fastRows(sql)
  
  result = @[]
  for row in rows:
    let model = modelType()
    for i, column in modelType.getTable().columns:
      model.setColumnValue(column.name, fromSqlValue(row[i], column.typ))
    result.add(model)
  """

# ACID Transaction Management / Управление на ACID транзакции
proc beginTransaction*(conn: DbConn, isolationLevel: IsolationLevel = ilReadCommitted): Future[Transaction] {.async.} =
  ## [English] Begins a new database transaction with specified isolation level
  ##
  ## This function starts a new ACID transaction for critical financial operations.
  ## Default isolation level is READ COMMITTED for financial data consistency.
  ##
  ## [Български] Започва нова транзакция в базата данни със зададено ниво на изолация
  ##
  ## Тази функция стартира нова ACID транзакция за критични финансови операции.
  ## Нивото на изолация по подразбиране е READ COMMITTED за консистентност на финансовите данни.
  ##
  ## Начинает новую транзакцию в базе данных с указанным уровнем изоляции
  try:
    # Set isolation level
    conn.exec("SET TRANSACTION ISOLATION LEVEL " & $isolationLevel)
    
    # Begin transaction
    conn.exec("BEGIN")
    
    result = Transaction(
      conn: conn,
      active: true,
      rollbackOnly: false
    )
    
    echo "Transaction started with isolation level: ", isolationLevel
  except Exception as e:
    raise newException(TransactionError, "Failed to begin transaction: " & e.msg)

proc rollback*(transaction: Transaction): Future[void] {.async.} =
  ## [English] Rolls back the transaction and undoes all changes
  ##
  ## This function undoes all changes made within the transaction.
  ## Essential for maintaining data integrity when errors occur.
  ##
  ## [Български] Отменя транзакцията и връща всички промени
  ##
  ## Тази функция отменя всички промени направени в транзакцията.
  ## От съществено значение за поддържане на интегритета на данните при грешки.
  ##
  ## Откатывает транзакцию и отменяет все изменения
  if not transaction.active:
    return  # Already rolled back or committed
  
  try:
    transaction.conn.exec("ROLLBACK")
    transaction.active = false
    echo "Transaction rolled back"
  except Exception as e:
    echo "Warning: Failed to rollback transaction: ", e.msg

proc commit*(transaction: Transaction): Future[void] {.async.} =
  ## [English] Commits the transaction and makes all changes permanent
  ##
  ## This function commits all changes made within the transaction.
  ## Critical for ensuring data consistency in financial operations.
  ##
  ## [Български] Потвърждава транзакцията и прави всички промени постоянни
  ##
  ## Тази функция потвърждава всички промени направени в транзакцията.
  ## Критична за осигуряване на консистентност на данните при финансови операции.
  ##
  ## Подтверждает транзакцию и делает все изменения постоянными
  if not transaction.active:
    raise newException(TransactionError, "Transaction is not active")
  
  if transaction.rollbackOnly:
    raise newException(TransactionError, "Transaction is marked for rollback only")
  
  try:
    transaction.conn.exec("COMMIT")
    transaction.active = false
    echo "Transaction committed successfully"
  except Exception as e:
    await transaction.rollback()
    raise newException(TransactionError, "Failed to commit transaction: " & e.msg)

proc setRollbackOnly*(transaction: Transaction) =
  ## [English] Marks transaction for rollback only
  ##
  ## This function marks the transaction to be rolled back, preventing commit.
  ## Useful when business logic errors are detected.
  ##
  ## [Български] Маркира транзакцията само за отмяна
  ##
  ## Тази функция маркира транзакцията за отмяна, предотвратявайки потвърждаване.
  ## Полезна когато се открият грешки в бизнес логиката.
  ##
  ## Помечает транзакцию только для отката
  transaction.rollbackOnly = true

proc execInTransaction*(transaction: Transaction, sql: string, args: varargs[string, `$`]): Future[void] {.async.} =
  ## [English] Executes SQL within a transaction context
  ##
  ## This function executes SQL statements within an active transaction.
  ## Automatically marks transaction for rollback if an error occurs.
  ##
  ## [Български] Изпълнява SQL в контекста на транзакция
  ##
  ## Тази функция изпълнява SQL заявки в активна транзакция.
  ## Автоматично маркира транзакцията за отмяна при грешка.
  ##
  ## Выполняет SQL в контексте транзакции
  if not transaction.active:
    raise newException(TransactionError, "Transaction is not active")
  
  if transaction.rollbackOnly:
    raise newException(TransactionError, "Transaction is marked for rollback only")
  
  try:
    transaction.conn.exec(sql, args)
  except Exception as e:
    transaction.setRollbackOnly()
    raise newException(TransactionError, "SQL execution failed in transaction: " & e.msg)

# Template for transaction management / Шаблон за управление на транзакции
template withTransaction*(conn: DbConn, isolationLevel: IsolationLevel = ilReadCommitted, body: untyped): untyped =
  ## [English] Template for automatic transaction management
  ##
  ## This template automatically begins, commits or rolls back transactions.
  ## Ensures proper cleanup even if exceptions occur.
  ##
  ## [Български] Шаблон за автоматично управление на транзакции
  ##
  ## Този шаблон автоматично започва, потвърждава или отменя транзакции.
  ## Осигурява правилно почистване дори при възникване на изключения.
  ##
  ## Шаблон для автоматического управления транзакциями
  let transaction = await beginTransaction(conn, isolationLevel)
  
  try:
    body
    await transaction.commit()
  except Exception as e:
    await transaction.rollback()
    raise e

# Accounting-specific transaction helpers / Помощни функции за счетоводни транзакции
proc createAccountingEntry*(transaction: Transaction, debitAccount: string, creditAccount: string, 
                           amount: string, description: string, reference: string = ""): Future[void] {.async.} =
  ## [English] Creates a double-entry accounting transaction
  ##
  ## This function creates a proper double-entry accounting transaction
  ## ensuring debit and credit balance according to accounting principles.
  ##
  ## [Български] Създава двойна счетоводна проводка
  ##
  ## Тази функция създава правилна двойна счетоводна проводка
  ## осигурявайки баланс между дебит и кредит според счетоводните принципи.
  ##
  ## Создает двойную бухгалтерскую проводку
  try:
    # Create main transaction record
    let transactionSql = """
      INSERT INTO transactions (date, description, reference, created_at)
      VALUES (CURRENT_DATE, ?, ?, CURRENT_TIMESTAMP)
      RETURNING id
    """
    
    let transactionRows = transaction.conn.fastRows(transactionSql, description, reference)
    let transactionId = transactionRows[0][0]
    
    # Create debit entry
    let debitSql = """
      INSERT INTO entries (transaction_id, account_code, debit, credit, created_at)
      VALUES (?, ?, ?, 0, CURRENT_TIMESTAMP)
    """
    await transaction.execInTransaction(debitSql, transactionId, debitAccount, amount)
    
    # Create credit entry
    let creditSql = """
      INSERT INTO entries (transaction_id, account_code, debit, credit, created_at)
      VALUES (?, ?, 0, ?, CURRENT_TIMESTAMP)
    """
    await transaction.execInTransaction(creditSql, transactionId, creditAccount, amount)
    
    echo "Accounting entry created: ", debitAccount, " -> ", creditAccount, " Amount: ", amount
    
  except Exception as e:
    transaction.setRollbackOnly()
    raise newException(TransactionError, "Failed to create accounting entry: " & e.msg)

proc validateAccountingBalance*(transaction: Transaction): Future[bool] {.async.} =
  ## [English] Validates that accounting entries are balanced
  ##
  ## This function checks that total debits equal total credits
  ## ensuring accounting equation integrity.
  ##
  ## [Български] Валидира че счетоводните записи са балансирани
  ##
  ## Тази функция проверява че общите дебити са равни на общите кредити
  ## осигурявайки интегритета на счетоводното уравнение.
  ##
  ## Проверяет сбалансированность бухгалтерских записей
  try:
    let sql = """
      SELECT 
        SUM(debit) as total_debit,
        SUM(credit) as total_credit
      FROM entries
    """
    
    let rows = transaction.conn.fastRows(sql)
    if rows.len > 0:
      let totalDebit = rows[0][0]
      let totalCredit = rows[0][1]
      
      result = totalDebit == totalCredit
      if not result:
        echo "Warning: Accounting imbalance detected! Debit: ", totalDebit, " Credit: ", totalCredit
    else:
      result = true
      
  except Exception as e:
    raise newException(TransactionError, "Failed to validate accounting balance: " & e.msg)
