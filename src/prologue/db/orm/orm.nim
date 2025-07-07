# Copyright 2025 Prologue PostgreSQL ORM
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## Prologue PostgreSQL ORM
## 
## This is the main ORM module that provides high-level database operations
## and model management for PostgreSQL databases.

import std/[asyncdispatch, logging, tables, json, strutils, macros]
import ./postgres/[driver, types]

type
  ORM* = ref object
    driver*: PgDriver
    config*: PgConfig
    models*: Table[string, ModelMeta]

  ModelMeta* = object
    name*: string
    tableName*: string
    fields*: seq[FieldMeta]
    primaryKey*: string

  FieldMeta* = object
    name*: string
    pgType*: PgFieldType
    nimType*: string
    constraints*: seq[PgConstraint]
    defaultValue*: string

  ORMError* = object of CatchableError

# Global ORM instance
var globalORM*: ORM

# Initialize ORM with configuration
proc initORM*(
  host = "localhost",
  port = 5432,
  database: string,
  username: string,
  password: string,
  sslMode = "prefer",
  maxConnections = 10,
  minConnections = 2,
  connectionTimeout = 30000,
  commandTimeout = 30000
): ORM =
  
  let config = newPgConfig(
    host = host,
    port = port,
    database = database,
    username = username,
    password = password,
    sslMode = sslMode,
    maxConnections = maxConnections,
    minConnections = minConnections,
    connectionTimeout = connectionTimeout,
    commandTimeout = commandTimeout
  )
  
  result = ORM(
    driver: newPgDriver(config),
    config: config,
    models: initTable[string, ModelMeta]()
  )
  
  globalORM = result
  logging.info("ORM initialized for database: " & database)

# Simplified ORM access - using global instance for now
proc getORM*(): ORM =
  if globalORM.isNil:
    raise newException(ORMError, "ORM not initialized")
  return globalORM

# Register model metadata
proc registerModel*(orm: ORM, meta: ModelMeta) =
  orm.models[meta.name] = meta
  logging.debug("Model registered: " & meta.name)

# Get model metadata
proc getModel*(orm: ORM, modelName: string): ModelMeta =
  if not orm.models.hasKey(modelName):
    raise newException(ORMError, "Model not found: " & modelName)
  return orm.models[modelName]

# Test database connection
proc testConnection*(orm: ORM): Future[bool] {.async.} =
  return await orm.driver.testConnection()

# Execute raw SQL
proc execute*(orm: ORM, sql: string, params: seq[string] = @[]): Future[PgResult] {.async.} =
  let result = await orm.driver.execute(sql, params)
  return result

# Execute single row query
proc queryRow*(orm: ORM, sql: string, params: seq[string] = @[]): Future[seq[string]] {.async.} =
  return await orm.driver.queryRow(sql, params)

# Execute scalar query
proc queryValue*(orm: ORM, sql: string, params: seq[string] = @[]): Future[string] {.async.} =
  return await orm.driver.queryValue(sql, params)

# Execute within transaction with proper type handling
proc withTransaction*[T](orm: ORM, operation: proc(): Future[T] {.async.}): Future[T] {.async.} =
  return await orm.driver.withTransaction(operation)

# Execute within transaction for void operations
proc withTransactionVoid*(orm: ORM, operation: proc(): Future[void] {.async.}): Future[void] {.async.} =
  await orm.driver.withTransactionVoid(operation)

# Create table for model
proc createTable*(orm: ORM, modelName: string): Future[void] {.async.} =
  let meta = orm.getModel(modelName)
  
  var columns: seq[tuple[name: string, pgType: PgFieldType, constraints: seq[PgConstraint]]] = @[]
  
  for field in meta.fields:
    columns.add((
      name: field.name,
      pgType: field.pgType,
      constraints: field.constraints
    ))
  
  await orm.driver.createTable(meta.tableName, columns)

# Drop table for model
proc dropTable*(orm: ORM, modelName: string, ifExists = true): Future[void] {.async.} =
  let meta = orm.getModel(modelName)
  await orm.driver.dropTable(meta.tableName, ifExists)

# Check if table exists
proc tableExists*(orm: ORM, modelName: string): Future[bool] {.async.} =
  let meta = orm.getModel(modelName)
  return await orm.driver.tableExists(meta.tableName)

# Sync database schema (create missing tables)
proc syncDatabase*(orm: ORM): Future[void] {.async.} =
  logging.info("Syncing database schema...")
  
  for modelName, meta in orm.models:
    let exists = await orm.tableExists(modelName)
    if not exists:
      logging.info("Creating table for model: " & modelName)
      await orm.createTable(modelName)
    else:
      logging.debug("Table exists for model: " & modelName)
  
  logging.info("Database schema sync completed")

# Close ORM and cleanup
proc close*(orm: ORM) =
  if not orm.driver.isNil:
    orm.driver.close()
  logging.info("ORM closed")

# Convenience macro for model field definition
macro field*(name: untyped, fieldType: typedesc, constraints: varargs[untyped]): untyped =
  result = newNimNode(nnkObjConstr)
  result.add(ident("FieldMeta"))
  
  # Field name
  result.add(newColonExpr(ident("name"), newStrLitNode($name)))
  
  # PostgreSQL type (inferred from Nim type)
  let pgTypeCall = newCall(ident("nimTypeToPgType"), newStrLitNode($fieldType))
  result.add(newColonExpr(ident("pgType"), pgTypeCall))
  
  # Nim type
  result.add(newColonExpr(ident("nimType"), newStrLitNode($fieldType)))
  
  # Constraints
  var constraintSeq = newNimNode(nnkBracket)
  for constraint in constraints:
    constraintSeq.add(constraint)
  result.add(newColonExpr(ident("constraints"), newCall(ident("@"), constraintSeq)))
  
  # Default value (empty for now)
  result.add(newColonExpr(ident("defaultValue"), newStrLitNode("")))

# Helper template for creating model metadata
template defineModel*(modelName: string, tableName: string, primaryKey: string, fields: varargs[FieldMeta]): ModelMeta =
  ModelMeta(
    name: modelName,
    tableName: tableName,
    fields: @fields,
    primaryKey: primaryKey
  )

# ORM operations helper
proc withORM*(operation: proc(orm: ORM): Future[void] {.async.}): Future[void] {.async.} =
  let orm = getORM()
  await operation(orm)

# Example usage and initialization helper
proc initExampleORM*(): Future[ORM] {.async.} =
  # Initialize with provided credentials
  result = initORM(
    host = "localhost",
    port = 5432,
    database = "ex-orm",
    username = "postgres",
    password = "azina681024",
    maxConnections = 10,
    minConnections = 2
  )
  
  # Test connection
  let connected = await result.testConnection()
  if not connected:
    raise newException(ORMError, "Failed to connect to PostgreSQL database")
  
  logging.info("Example ORM initialized successfully")

# Export main types and functions
export ORM, ModelMeta, FieldMeta, ORMError
export initORM, getORM, registerModel, getModel
export testConnection, execute, queryRow, queryValue, withTransaction, withTransactionVoid
export createTable, dropTable, tableExists, syncDatabase, close
export field, defineModel, withORM, initExampleORM