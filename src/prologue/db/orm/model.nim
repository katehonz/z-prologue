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

## Model Base Class for Prologue PostgreSQL ORM
## 
## This module provides the base Model class and CRUD operations
## for database models in the ORM system.

import std/[asyncdispatch, json, strutils, sequtils, tables, times, logging]
import ./orm
import ./postgres/[types, driver]

type
  Model* = ref object of RootObj
    ## Base model class for all ORM models
    id*: int
    isNew*: bool
    isDirty*: bool
    originalData*: JsonNode

  ModelError* = object of CatchableError

  # Query manager for model operations
  QueryManager*[T] = ref object
    modelType*: typedesc[T]
    orm*: ORM
    tableName*: string

# Base model constructor
proc newModel*[T: Model](): T =
  result = T()
  result.isNew = true
  result.isDirty = false
  result.originalData = newJObject()

# Convert model to JSON
proc toJson*(model: Model): JsonNode =
  result = newJObject()
  # This would be implemented with reflection/macros in full version
  result["id"] = %model.id

# Load model from JSON
proc fromJson*[T: Model](modelType: typedesc[T], data: JsonNode): T =
  result = newModel[T]()
  result.isNew = false
  result.isDirty = false
  result.originalData = data.copy()
  
  # Load fields from JSON (simplified)
  if data.hasKey("id"):
    result.id = data["id"].getInt()

# Mark model as dirty (needs saving)
proc markDirty*(model: Model) =
  model.isDirty = true

# Check if model has unsaved changes
proc hasChanges*(model: Model): bool =
  return model.isNew or model.isDirty

# Get table name for model type
proc getTableName*[T: Model](modelType: typedesc[T]): string =
  # In full implementation, this would use model metadata
  return ($modelType).toLowerAscii() & "s"

# Create query manager for model
proc objects*[T: Model](modelType: typedesc[T]): QueryManager[T] =
  if globalORM.isNil:
    raise newException(ModelError, "ORM not initialized")
  
  result = QueryManager[T](
    modelType: modelType,
    orm: globalORM,
    tableName: getTableName(modelType)
  )

# Save model to database with better async handling
proc save*[T: Model](model: T): Future[void] {.async.} =
  if globalORM.isNil:
    raise newException(ModelError, "ORM not initialized")
  
  let tableName = getTableName(T)
  
  try:
    if model.isNew:
      # INSERT operation - simplified for basic functionality
      let sql = "INSERT INTO " & tableName & " (id) VALUES (DEFAULT) RETURNING id"
      let result = await globalORM.queryValue(sql, @[])
      model.id = parseInt(result)
      model.isNew = false
      logging.debug("Model inserted with ID: " & $model.id)
    else:
      # UPDATE operation - simplified for basic functionality
      if model.isDirty:
        let sql = "UPDATE " & tableName & " SET id = $1 WHERE id = $2"
        discard await globalORM.execute(sql, @[$model.id, $model.id])
        logging.debug("Model updated with ID: " & $model.id)
    
    model.isDirty = false
    
  except Exception as e:
    let errorMsg = "Failed to save model: " & e.msg
    logging.error(errorMsg)
    raise newException(ModelError, errorMsg)

# Delete model from database
proc delete*[T: Model](model: T): Future[void] {.async.} =
  if globalORM.isNil:
    raise newException(ModelError, "ORM not initialized")
  
  if model.isNew:
    raise newException(ModelError, "Cannot delete unsaved model")
  
  let tableName = getTableName(T)
  let sql = "DELETE FROM " & tableName & " WHERE id = $1"
  discard await globalORM.execute(sql, @[$model.id])
  
  logging.debug("Model deleted with ID: " & $model.id)

# Get model by ID with better error handling
proc get*[T: Model](qm: QueryManager[T], id: int): Future[T] {.async.} =
  try:
    let sql = "SELECT * FROM " & qm.tableName & " WHERE id = $1"
    let row = await qm.orm.queryRow(sql, @[$id])
    
    if row.len == 0:
      raise newException(ModelError, "Model not found with ID: " & $id)
    
    # Create model from row data (simplified)
    result = newModel[T]()
    result.id = parseInt(row[0])  # Assuming first column is ID
    result.isNew = false
    result.isDirty = false
    
  except ModelError:
    raise  # Re-raise ModelError as-is
  except Exception as e:
    let errorMsg = "Failed to get model with ID " & $id & ": " & e.msg
    logging.error(errorMsg)
    raise newException(ModelError, errorMsg)

# Get all models with better error handling
proc all*[T: Model](qm: QueryManager[T]): Future[seq[T]] {.async.} =
  try:
    let sql = "SELECT * FROM " & qm.tableName
    let pgResult = await qm.orm.execute(sql)
    
    result = @[]
    for row in pgResult.rows:
      if row.len > 0:
        let model = newModel[T]()
        model.id = parseInt(row[0])  # Assuming first column is ID
        model.isNew = false
        model.isDirty = false
        result.add(model)
        
  except Exception as e:
    let errorMsg = "Failed to get all models: " & e.msg
    logging.error(errorMsg)
    raise newException(ModelError, errorMsg)

# Filter models with WHERE clause
proc filter*[T: Model](qm: QueryManager[T], whereClause: string, params: seq[string] = @[]): QueryManager[T] =
  # In full implementation, this would build a query object
  # For now, return the same query manager (simplified)
  result = qm

# Execute filter and get results
proc all*[T: Model](qm: QueryManager[T], whereClause: string, params: seq[string] = @[]): Future[seq[T]] {.async.} =
  let sql = "SELECT * FROM " & qm.tableName & " WHERE " & whereClause
  let pgResult = await qm.orm.execute(sql, params)
  
  result = @[]
  for row in pgResult.rows:
    if row.len > 0:
      let model = newModel[T]()
      model.id = parseInt(row[0])  # Assuming first column is ID
      model.isNew = false
      model.isDirty = false
      result.add(model)

# Count models
proc count*[T: Model](qm: QueryManager[T]): Future[int] {.async.} =
  let sql = "SELECT COUNT(*) FROM " & qm.tableName
  let countStr = await qm.orm.queryValue(sql)
  result = parseInt(countStr)

# Check if model exists
proc exists*[T: Model](qm: QueryManager[T], id: int): Future[bool] {.async.} =
  let sql = "SELECT EXISTS(SELECT 1 FROM " & qm.tableName & " WHERE id = $1)"
  let existsStr = await qm.orm.queryValue(sql, @[$id])
  result = existsStr.toLowerAscii() in ["t", "true", "1"]

# Create model
proc create*[T: Model](qm: QueryManager[T], data: JsonNode): Future[T] {.async.} =
  result = fromJson(T, data)
  result.isNew = true
  await result.save()

# Get or create model
proc getOrCreate*[T: Model](qm: QueryManager[T], id: int, defaults: JsonNode = newJObject()): Future[tuple[model: T, created: bool]] {.async.} =
  try:
    let model = await qm.get(id)
    return (model: model, created: false)
  except ModelError:
    let model = await qm.create(defaults)
    return (model: model, created: true)

# Bulk create models
proc bulkCreate*[T: Model](qm: QueryManager[T], dataList: seq[JsonNode]): Future[seq[T]] {.async.} =
  result = @[]
  
  # In full implementation, this would use batch INSERT
  for data in dataList:
    let model = await qm.create(data)
    result.add(model)

# Update models with WHERE clause
proc update*[T: Model](qm: QueryManager[T], whereClause: string, params: seq[string], updateData: JsonNode): Future[int] {.async.} =
  # Simplified update - in full implementation would build proper UPDATE statement
  let sql = "UPDATE " & qm.tableName & " SET id = id WHERE " & whereClause
  let pgResult = await qm.orm.execute(sql, params)
  result = pgResult.affectedRows

# Delete models with WHERE clause
proc delete*[T: Model](qm: QueryManager[T], whereClause: string, params: seq[string]): Future[int] {.async.} =
  let sql = "DELETE FROM " & qm.tableName & " WHERE " & whereClause
  let pgResult = await qm.orm.execute(sql, params)
  result = pgResult.affectedRows

# Transaction support for models with proper type handling
proc withTransaction*[T](operation: proc(): Future[T] {.async.}): Future[T] {.async.} =
  if globalORM.isNil:
    raise newException(ModelError, "ORM not initialized")
  
  return await globalORM.withTransaction(operation)

# Transaction support for void operations
proc withTransactionVoid*(operation: proc(): Future[void] {.async.}): Future[void] {.async.} =
  if globalORM.isNil:
    raise newException(ModelError, "ORM not initialized")
  
  await globalORM.withTransactionVoid(operation)

# Model validation (to be extended)
proc validate*(model: Model): seq[string] =
  result = @[]
  # Add validation rules here
  if model.id < 0:
    result.add("ID must be positive")

# Check if model is valid
proc isValid*(model: Model): bool =
  return model.validate().len == 0

# Refresh model from database
proc refresh*[T: Model](model: T): Future[void] {.async.} =
  if model.isNew:
    raise newException(ModelError, "Cannot refresh unsaved model")
  
  let fresh = await T.objects.get(model.id)
  # Copy fresh data to current model (simplified)
  model.originalData = fresh.originalData
  model.isDirty = false

# Export main types and functions
export Model, ModelError, QueryManager
export newModel, toJson, fromJson, markDirty, hasChanges
export objects, save, delete, get, all, filter, count, exists
export create, getOrCreate, bulkCreate, update
export withTransaction, withTransactionVoid, validate, isValid, refresh