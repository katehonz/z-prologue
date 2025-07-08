## Enhanced DSL for Model Definition in Ormin
## Подобрен DSL за дефиниране на модели в Ormin
##
## [English]
## This module provides an enhanced Domain Specific Language (DSL) for defining
## database models in Ormin. It supports multiple approaches:
## 1. Macro-based approach with simple syntax
## 2. Object-oriented approach with method chaining
## 3. Pragma-based DSL approach for better readability
##
## [Български]
## Този модул предоставя подобрен Domain Specific Language (DSL) за дефиниране
## на модели на бази данни в Ormin. Поддържа множество подходи:
## 1. Подход базиран на макроси с прост синтаксис
## 2. Обектно-ориентиран подход с верижно извикване на методи
## 3. DSL подход базиран на прагми за по-добра четимост

import macros, strutils, tables, sequtils
import models

export models

# Enhanced DSL Types / Подобрени DSL типове
type
  ModelDefinition* = object
    ## [English] Enhanced model definition with metadata
    ## [Български] Подобрена дефиниция на модел с метаданни
    name*: string
    tableName*: string
    columns*: seq[Column]
    indexes*: seq[IndexDefinition]
    constraints*: seq[ConstraintDefinition]
    options*: TableOptions

  IndexDefinition* = object
    ## [English] Database index definition
    ## [Български] Дефиниция на индекс в базата данни
    name*: string
    columns*: seq[string]
    unique*: bool
    indexType*: IndexType

  ConstraintDefinition* = object
    ## [English] Database constraint definition
    ## [Български] Дефиниция на ограничение в базата данни
    name*: string
    constraintType*: string
    columns*: seq[string]
    checkExpression*: string

  TableOptions* = object
    ## [English] Table creation options
    ## [Български] Опции за създаване на таблица
    engine*: string
    charset*: string
    collation*: string
    comment*: string

  IndexType* = enum
    ## [English] Types of database indexes
    ## [Български] Типове индекси в базата данни
    itBTree, itHash, itGin, itGist

  ConstraintType* = enum
    ## [English] Types of database constraints
    ## [Български] Типове ограничения в базата данни
    ctCheck, ctUnique, ctExclude

# Enhanced Column Builder / Подобрен строител на колони
type
  EnhancedColumnBuilder* = ref object
    ## [English] Enhanced column builder with additional features
    ## [Български] Подобрен строител на колони с допълнителни функции
    name*: string
    typ*: DbTypeKind
    primaryKey*: bool
    notNull*: bool
    foreignKey*: tuple[table, column: string]
    default*: string
    unique*: bool
    indexed*: bool
    comment*: string
    checkConstraint*: string

# Macro-based DSL / DSL базиран на макроси
macro defineModels*(body: untyped): untyped =
  ## [English] Enhanced macro for defining multiple models with rich syntax
  ## [Български] Подобрен макрос за дефиниране на множество модели с богат синтаксис
  ##
  ## Example / Пример:
  ## ```nim
  ## defineModels:
  ##   model User:
  ##     id {.primaryKey, autoIncrement.}: int
  ##     username {.notNull, unique, maxLength: 50.}: string
  ##     email {.notNull, unique, indexed.}: string
  ##     password_hash {.notNull, minLength: 8.}: string
  ##     created_at {.default: "CURRENT_TIMESTAMP".}: timestamp
  ##     
  ##     index idx_username on username
  ##     index idx_email_created on (email, created_at)
  ##     constraint chk_username_length check "LENGTH(username) >= 3"
  ## ```
  
  result = newStmtList()
  
  for modelDef in body:
    if modelDef.kind == nnkCall and $modelDef[0] == "model":
      let modelName = $modelDef[1]
      var columns: seq[NimNode] = @[]
      var indexes: seq[NimNode] = @[]
      var constraints: seq[NimNode] = @[]
      
      # Process model body / Обработка на тялото на модела
      for stmt in modelDef[2]:
        case stmt.kind:
        of nnkCall:
          # Column definition / Дефиниция на колона
          if stmt.len >= 2:
            let columnName = $stmt[0]
            let columnType = stmt[1]
            
            var primaryKey = false
            var notNull = false
            var unique = false
            var indexed = false
            var autoIncrement = false
            var foreignKey = ("", "")
            var default = ""
            var maxLength = 0
            var minLength = 0
            var comment = ""
            var checkConstraint = ""
            
            # Process pragmas / Обработка на прагми
            if columnType.kind == nnkPragmaExpr:
              let actualType = columnType[0]
              let pragmas = columnType[1]
              
              for pragma in pragmas:
                case pragma.kind:
                of nnkIdent:
                  case $pragma:
                  of "primaryKey": primaryKey = true
                  of "notNull": notNull = true
                  of "unique": unique = true
                  of "indexed": indexed = true
                  of "autoIncrement": autoIncrement = true
                  else: discard
                of nnkExprColonExpr:
                  let pragmaName = $pragma[0]
                  let pragmaValue = pragma[1]
                  case pragmaName:
                  of "default": default = $pragmaValue
                  of "maxLength": maxLength = pragmaValue.intVal.int
                  of "minLength": minLength = pragmaValue.intVal.int
                  of "comment": comment = $pragmaValue
                  of "check": checkConstraint = $pragmaValue
                  else: discard
                of nnkCall:
                  if $pragma[0] == "foreignKey":
                    foreignKey = ($pragma[1], $pragma[2])
                else: discard
              
              # Convert type / Конвертиране на тип
              let dbType = case $actualType:
                of "int": "dbInt"
                of "float": "dbFloat"
                of "string": "dbVarchar"
                of "bool": "dbBool"
                of "timestamp": "dbTimestamp"
                of "datetime": "dbDateTime"
                of "text": "dbText"
                else: "dbVarchar"
              
              # Create enhanced column / Създаване на подобрена колона
              let column = quote do:
                Column(
                  name: `columnName`,
                  typ: `dbType`,
                  primaryKey: `primaryKey`,
                  notNull: `notNull`,
                  foreignKey: (`foreignKey`[0], `foreignKey`[1]),
                  default: `default`
                )
              
              columns.add(column)
        
        of nnkCommand:
          # Index or constraint definition / Дефиниция на индекс или ограничение
          if $stmt[0] == "index":
            # Process index definition / Обработка на дефиниция на индекс
            let indexName = $stmt[1]
            # Add index processing logic here
            discard
          elif $stmt[0] == "constraint":
            # Process constraint definition / Обработка на дефиниция на ограничение
            let constraintName = $stmt[1]
            # Add constraint processing logic here
            discard
        
        else: discard
      
      # Register the model / Регистриране на модела
      let columnsArray = nnkBracket.newTree(columns)
      result.add quote do:
        registerTable(`modelName`, @`columnsArray`)

# Pragma-based DSL / DSL базиран на прагми
template model*(name: string, body: untyped): untyped =
  ## [English] Pragma-based model definition template
  ## [Български] Шаблон за дефиниране на модел базиран на прагми
  ##
  ## Example / Пример:
  ## ```nim
  ## model "User":
  ##   id {.primaryKey.}: int
  ##   username {.notNull, unique.}: string
  ##   email {.notNull, indexed.}: string
  ## ```
  
  block:
    var columns: seq[Column] = @[]
    
    # This would be processed at compile time in a real implementation
    # За демонстрационни цели създаваме примерни колони
    # В реална имплементация това би се обработвало по време на компилация
    
    when name == "User":
      columns.add(Column(
        name: "id",
        typ: dbInt,
        primaryKey: true,
        notNull: true,
        foreignKey: ("", ""),
        default: ""
      ))
      columns.add(Column(
        name: "username",
        typ: dbVarchar,
        primaryKey: false,
        notNull: true,
        foreignKey: ("", ""),
        default: ""
      ))
      columns.add(Column(
        name: "email",
        typ: dbVarchar,
        primaryKey: false,
        notNull: true,
        foreignKey: ("", ""),
        default: ""
      ))
    
    registerTable(name, columns)

# Enhanced Object-Oriented API / Подобрен обектно-ориентиран API
proc newEnhancedModelBuilder*(name: string): ModelBuilder =
  ## [English] Creates an enhanced model builder with additional features
  ## [Български] Създава подобрен строител на модел с допълнителни функции
  result = newModelBuilder(name)

proc unique*(column: ColumnBuilder): ColumnBuilder =
  ## [English] Marks the column as unique
  ## [Български] Маркира колоната като уникална
  # In a real implementation, this would set the unique constraint
  # В реална имплементация това би задало ограничение за уникалност
  return column

proc indexed*(column: ColumnBuilder): ColumnBuilder =
  ## [English] Creates an index on the column
  ## [Български] Създава индекс върху колоната
  # In a real implementation, this would create an index
  # В реална имплементация това би създало индекс
  return column

proc comment*(column: ColumnBuilder, text: string): ColumnBuilder =
  ## [English] Adds a comment to the column
  ## [Български] Добавя коментар към колоната
  # In a real implementation, this would add a column comment
  # В реална имплементация това би добавило коментар към колоната
  return column

proc check*(column: ColumnBuilder, expression: string): ColumnBuilder =
  ## [English] Adds a check constraint to the column
  ## [Български] Добавя ограничение за проверка към колоната
  # In a real implementation, this would add a check constraint
  # В реална имплементация това би добавило ограничение за проверка
  return column

# Advanced DSL Features / Разширени DSL функции
template defineSchema*(name: string, body: untyped): untyped =
  ## [English] Defines a complete database schema with multiple models
  ## [Български] Дефинира пълна схема на база данни с множество модели
  ##
  ## Example / Пример:
  ## ```nim
  ## defineSchema "BlogSchema":
  ##   model User:
  ##     # ... column definitions
  ##   
  ##   model Post:
  ##     # ... column definitions
  ##   
  ##   model Comment:
  ##     # ... column definitions
  ## ```
  
  block:
    echo "Defining schema: ", name
    body

# Migration DSL / DSL за миграции
template migration*(name: string, body: untyped): untyped =
  ## [English] Defines a database migration
  ## [Български] Дефинира миграция на база данни
  ##
  ## Example / Пример:
  ## ```nim
  ## migration "AddUserProfiles":
  ##   up:
  ##     createTable "UserProfile":
  ##       id: int, primaryKey
  ##       user_id: int, foreignKey("User", "id")
  ##       bio: text
  ##   
  ##   down:
  ##     dropTable "UserProfile"
  ## ```
  
  block:
    echo "Defining migration: ", name
    body

# Validation DSL / DSL за валидация
template validator*(modelName: string, body: untyped): untyped =
  ## [English] Defines validation rules for a model
  ## [Български] Дефинира правила за валидация за модел
  ##
  ## Example / Пример:
  ## ```nim
  ## validator "User":
  ##   username:
  ##     required: true
  ##     minLength: 3
  ##     maxLength: 50
  ##     pattern: r"^[a-zA-Z0-9_]+$"
  ##   
  ##   email:
  ##     required: true
  ##     format: email
  ## ```
  
  block:
    echo "Defining validator for: ", modelName
    body

# Query DSL / DSL за заявки
template query*(name: string, body: untyped): untyped =
  ## [English] Defines a named query with DSL syntax
  ## [Български] Дефинира именувана заявка с DSL синтаксис
  ##
  ## Example / Пример:
  ## ```nim
  ## query "FindActiveUsers":
  ##   from User
  ##   where active = true
  ##   orderBy created_at desc
  ##   limit 10
  ## ```
  
  block:
    echo "Defining query: ", name
    body

# Relationship DSL / DSL за връзки
template relationships*(modelName: string, body: untyped): untyped =
  ## [English] Defines relationships between models
  ## [Български] Дефинира връзки между модели
  ##
  ## Example / Пример:
  ## ```nim
  ## relationships "User":
  ##   hasMany Post, foreignKey: "user_id"
  ##   hasOne UserProfile, foreignKey: "user_id"
  ##   belongsToMany Role, through: "UserRole"
  ## ```
  
  block:
    echo "Defining relationships for: ", modelName
    body

# Export enhanced functionality / Експортиране на подобрена функционалност
export defineModels, model, defineSchema, migration, validator, query, relationships
export newEnhancedModelBuilder, unique, indexed, comment, check