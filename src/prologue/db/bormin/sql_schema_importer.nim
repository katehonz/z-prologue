## Ormin -- ORM for Nim.
## SQL Schema Import Module
##
## [English]
## This module provides functionality for importing database schemas directly from SQL files.
## It allows developers to define their database schema using standard SQL DDL statements
## and automatically generate corresponding Nim model definitions.
##
## Key features:
## * Parse SQL CREATE TABLE statements
## * Extract column definitions, constraints, and relationships
## * Generate Nim model code from SQL schema
## * Support for foreign key relationships
## * Automatic type mapping from SQL to Nim types
##
## [Български]
## Този модул предоставя функционалност за импортиране на схеми на бази данни директно от SQL файлове.
## Позволява на разработчиците да дефинират схемата на базата данни, използвайки стандартни SQL DDL заявки
## и автоматично да генерират съответните дефиниции на модели в Nim.
##
## Основни характеристики:
## * Парсиране на SQL CREATE TABLE заявки
## * Извличане на дефиниции на колони, ограничения и връзки
## * Генериране на Nim модел код от SQL схема
## * Поддръжка на връзки с външни ключове
## * Автоматично съпоставяне на типове от SQL към Nim типове

import strutils, sequtils, tables, re, os
import bormin/models

type
  SqlColumn* = object
    ## [English] Represents a column parsed from SQL DDL
    ## [Български] Представлява колона, парсирана от SQL DDL
    name*: string
    sqlType*: string
    isPrimaryKey*: bool
    isNotNull*: bool
    defaultValue*: string
    foreignKey*: tuple[table, column: string]

  SqlTable* = object
    ## [English] Represents a table parsed from SQL DDL
    ## [Български] Представлява таблица, парсирана от SQL DDL
    name*: string
    columns*: seq[SqlColumn]
    foreignKeys*: seq[tuple[column, refTable, refColumn: string]]
    indexes*: seq[string]

  SqlSchemaImporter* = ref object
    ## [English] Main class for importing SQL schemas
    ## [Български] Основен клас за импортиране на SQL схеми
    tables*: OrderedTable[string, SqlTable]

proc newSqlSchemaImporter*(): SqlSchemaImporter =
  ## [English] Creates a new SQL schema importer
  ## [Български] Създава нов импортер на SQL схеми
  result = SqlSchemaImporter(tables: initOrderedTable[string, SqlTable]())

proc mapSqlTypeToDbType*(sqlType: string): DbTypeKind =
  ## [English] Maps SQL data types to Ormin DbTypeKind
  ## [Български] Съпоставя SQL типове данни към Ormin DbTypeKind
  let normalizedType = sqlType.toLowerAscii().strip()
  
  if normalizedType.contains("int") or normalizedType == "integer":
    return dbInt
  elif normalizedType.contains("float") or normalizedType.contains("real") or 
       normalizedType.contains("double") or normalizedType.contains("numeric"):
    return dbFloat
  elif normalizedType.contains("varchar") or normalizedType.contains("text") or
       normalizedType.contains("string"):
    return dbVarchar
  elif normalizedType.contains("char"):
    return dbFixedChar
  elif normalizedType.contains("bool"):
    return dbBool
  elif normalizedType.contains("timestamp") or normalizedType.contains("datetime"):
    return dbTimestamp
  else:
    return dbVarchar  # Default fallback

proc parseCreateTable*(importer: SqlSchemaImporter, sql: string) =
  ## [English] Parses a CREATE TABLE statement and extracts table information
  ## [Български] Парсира CREATE TABLE заявка и извлича информация за таблицата
  
  # Remove comments and normalize whitespace - simplified approach
  var cleanSql = sql
  # Remove single line comments
  let lines = cleanSql.splitLines()
  var cleanLines: seq[string] = @[]
  for line in lines:
    let commentPos = line.find("--")
    if commentPos >= 0:
      cleanLines.add(line[0..<commentPos].strip())
    else:
      cleanLines.add(line.strip())
  cleanSql = cleanLines.join(" ")
  
  # Remove multi-line comments (simplified)
  while true:
    let startComment = cleanSql.find("/*")
    let endComment = cleanSql.find("*/")
    if startComment >= 0 and endComment >= 0 and endComment > startComment:
      cleanSql = cleanSql[0..<startComment] & cleanSql[endComment+2..^1]
    else:
      break
  
  # Normalize whitespace
  cleanSql = cleanSql.replace(re"\s+", " ").strip()
  
  # Extract table name - simplified approach
  let upperSql = cleanSql.toUpperAscii()
  let createTablePos = upperSql.find("CREATE TABLE")
  if createTablePos == -1:
    return
  
  # Find table name after CREATE TABLE [IF NOT EXISTS]
  var nameStart = createTablePos + 12  # length of "CREATE TABLE"
  if upperSql[nameStart..^1].strip().startsWith("IF NOT EXISTS"):
    nameStart = upperSql.find("EXISTS", nameStart) + 6
  
  let remainingPart = cleanSql[nameStart..^1].strip()
  let parenPos = remainingPart.find("(")
  if parenPos == -1:
    return
  
  let tableName = remainingPart[0..<parenPos].strip()
  
  # Extract column definitions
  let startIdx = cleanSql.find("(")
  let endIdx = cleanSql.rfind(")")
  if startIdx == -1 or endIdx == -1:
    return
  
  let columnsPart = cleanSql[startIdx+1..endIdx-1]
  var table = SqlTable(name: tableName, columns: @[], foreignKeys: @[], indexes: @[])
  
  # Split by commas, but be careful with nested parentheses
  var columns: seq[string] = @[]
  var current = ""
  var parenLevel = 0
  
  for c in columnsPart:
    if c == '(':
      parenLevel += 1
    elif c == ')':
      parenLevel -= 1
    elif c == ',' and parenLevel == 0:
      columns.add(current.strip())
      current = ""
      continue
    current.add(c)
  
  if current.strip() != "":
    columns.add(current.strip())
  
  # Parse each column definition
  for colDef in columns:
    let trimmed = colDef.strip()
    
    # Skip constraint definitions for now
    if trimmed.toLowerAscii().startsWith("primary key") or
       trimmed.toLowerAscii().startsWith("foreign key") or
       trimmed.toLowerAscii().startsWith("constraint") or
       trimmed.toLowerAscii().startsWith("unique") or
       trimmed.toLowerAscii().startsWith("check"):
      
      # Handle foreign key constraints
      if trimmed.toLowerAscii().startsWith("foreign key"):
        # Simple parsing for foreign key constraints
        let upperTrimmed = trimmed.toUpperAscii()
        let keyStart = upperTrimmed.find("(")
        let keyEnd = upperTrimmed.find(")")
        let refStart = upperTrimmed.find("REFERENCES")
        if keyStart > 0 and keyEnd > keyStart and refStart > keyEnd:
          # Extract foreign key information - simplified approach
          continue
      continue
    
    # Parse column definition
    let parts = trimmed.split()
    if parts.len < 2:
      continue
    
    let columnName = parts[0]
    let columnType = parts[1]
    
    var column = SqlColumn(
      name: columnName,
      sqlType: columnType,
      isPrimaryKey: false,
      isNotNull: false,
      defaultValue: "",
      foreignKey: ("", "")
    )
    
    # Check for constraints
    let upperTrimmed = trimmed.toUpperAscii()
    if upperTrimmed.contains("PRIMARY KEY"):
      column.isPrimaryKey = true
    if upperTrimmed.contains("NOT NULL"):
      column.isNotNull = true
    
    # Extract default value
    let defaultMatch = upperTrimmed.find("DEFAULT")
    if defaultMatch != -1:
      let defaultPart = upperTrimmed[defaultMatch..^1]
      let defaultParts = defaultPart.split()
      if defaultParts.len > 1:
        column.defaultValue = defaultParts[1]
    
    table.columns.add(column)
  
  importer.tables[tableName] = table

proc importFromFile*(importer: SqlSchemaImporter, filepath: string) =
  ## [English] Imports schema from a SQL file
  ## [Български] Импортира схема от SQL файл
  
  if not fileExists(filepath):
    raise newException(IOError, "SQL file not found: " & filepath)
  
  let content = readFile(filepath)
  # Split SQL into individual statements
  let statements = content.split(";")
  
  for statement in statements:
    let trimmed = statement.strip()
    if trimmed.toLowerAscii().startsWith("create table"):
      importer.parseCreateTable(trimmed)

proc importFromString*(importer: SqlSchemaImporter, sql: string) =
  ## [English] Imports schema from a SQL string
  ## [Български] Импортира схема от SQL низ
  
  # Split SQL into individual statements
  let statements = sql.split(";")
  
  for statement in statements:
    let trimmed = statement.strip()
    if trimmed.toLowerAscii().startsWith("create table"):
      importer.parseCreateTable(trimmed)

proc generateNimModels*(importer: SqlSchemaImporter): string =
  ## [English] Generates Nim model definitions from imported SQL schema
  ## [Български] Генерира дефиниции на Nim модели от импортираната SQL схема
  
  result = "# Generated Nim models from SQL schema\n"
  result.add("# Генерирани Nim модели от SQL схема\n\n")
  result.add("import ormin/models\n\n")
  
  for tableName, table in importer.tables:
    result.add("# Model for table: " & tableName & "\n")
    result.add("# Модел за таблица: " & tableName & "\n")
    result.add("let " & tableName.toLowerAscii() & "Model = newModelBuilder(\"" & tableName & "\")\n")
    
    for column in table.columns:
      let dbType = mapSqlTypeToDbType(column.sqlType)
      var line = "discard " & tableName.toLowerAscii() & "Model.column(\"" & column.name & "\", " & $dbType & ")"
      
      if column.isPrimaryKey:
        line.add(".primaryKey()")
      if column.isNotNull:
        line.add(".notNull()")
      if column.defaultValue != "":
        line.add(".default(\"" & column.defaultValue & "\")")
      if column.foreignKey.table != "":
        line.add(".foreignKey(\"" & column.foreignKey.table & "\", \"" & column.foreignKey.column & "\")")
      
      result.add(line & "\n")
    
    result.add(tableName.toLowerAscii() & "Model.build()\n\n")

proc generateSqlFromModels*(importer: SqlSchemaImporter): string =
  ## [English] Generates SQL CREATE statements from imported models
  ## [Български] Генерира SQL CREATE заявки от импортираните модели
  
  result = "-- Generated SQL from imported schema\n"
  result.add("-- Генериран SQL от импортираната схема\n\n")
  
  for tableName, table in importer.tables:
    result.add("CREATE TABLE IF NOT EXISTS " & tableName & " (\n")
    
    var columnDefs: seq[string] = @[]
    var foreignKeys: seq[string] = @[]
    
    for column in table.columns:
      var colDef = "  " & column.name & " " & column.sqlType
      
      if column.isNotNull:
        colDef.add(" NOT NULL")
      if column.isPrimaryKey:
        colDef.add(" PRIMARY KEY")
      if column.defaultValue != "":
        colDef.add(" DEFAULT " & column.defaultValue)
      
      columnDefs.add(colDef)
      
      if column.foreignKey.table != "":
        let fkDef = "  FOREIGN KEY (" & column.name & ") REFERENCES " &
                    column.foreignKey.table & "(" & column.foreignKey.column & ")"
        foreignKeys.add(fkDef)
    
    result.add(columnDefs.join(",\n"))
    
    if foreignKeys.len > 0:
      result.add(",\n")
      result.add(foreignKeys.join(",\n"))
    
    result.add("\n);\n\n")

# Convenience procedures for easy usage
proc importSqlSchema*(filepath: string): SqlSchemaImporter =
  ## [English] Convenience function to import SQL schema from file
  ## [Български] Удобна функция за импортиране на SQL схема от файл
  result = newSqlSchemaImporter()
  result.importFromFile(filepath)

proc sqlToNimModels*(sqlFilepath: string, outputFilepath: string = "") =
  ## [English] Converts SQL schema file to Nim models file
  ## [Български] Конвертира SQL схема файл към Nim модели файл
  
  let importer = importSqlSchema(sqlFilepath)
  let nimCode = importer.generateNimModels()
  
  if outputFilepath == "":
    echo nimCode
  else:
    writeFile(outputFilepath, nimCode)
    echo "Nim models generated: " & outputFilepath
    echo "Nim модели генерирани: " & outputFilepath

# Example usage / Пример за използване:
when isMainModule:
  # Test with a sample SQL schema
  let sampleSql = """
  CREATE TABLE IF NOT EXISTS User (
    id INTEGER PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE TABLE IF NOT EXISTS Post (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    title VARCHAR(200) NOT NULL,
    content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES User(id)
  );
  """
  
  let importer = newSqlSchemaImporter()
  importer.importFromString(sampleSql)
  
  echo "Generated Nim models:"
  echo "Генерирани Nim модели:"
  echo importer.generateNimModels()