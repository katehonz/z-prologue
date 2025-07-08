## Ormin -- ORM for Nim.
## Migration support module

import os, strutils, times, json, parsesql, streams, sequtils, algorithm
import bormin/models

type
  Migration* = object
    id*: int
    name*: string
    appliedAt*: DateTime
    sql*: string

  MigrationManager* = ref object
    db*: DbConn
    migrationsTable*: string
    migrationsDir*: string

proc newMigrationManager*(db: DbConn, migrationsTable = "ormin_migrations", 
                         migrationsDir = "migrations"): MigrationManager =
  ## Creates a new migration manager
  result = MigrationManager(
    db: db,
    migrationsTable: migrationsTable,
    migrationsDir: migrationsDir
  )
  
  # Create migrations directory if it doesn't exist
  if not dirExists(migrationsDir):
    createDir(migrationsDir)
  
  # Create migrations table if it doesn't exist
  let createTableSql = """
  CREATE TABLE IF NOT EXISTS $1 (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at TIMESTAMP NOT NULL,
    sql TEXT NOT NULL
  )
  """ % [migrationsTable]
  
  db.exec(sql(createTableSql))

proc createMigration*(mm: MigrationManager, name: string): string =
  ## Creates a new migration file with the given name
  let timestamp = now().format("yyyyMMddHHmmss")
  let filename = timestamp & "_" & name.replace(" ", "_") & ".sql"
  let filepath = mm.migrationsDir / filename
  
  let templateContent = """-- Migration: $1
-- Created at: $2

-- Write your UP migration here

-- @DOWN

-- Write your DOWN migration here
""" % [name, now().format("yyyy-MM-dd HH:mm:ss")]

  writeFile(filepath, templateContent)
  return filepath

proc getAppliedMigrations*(mm: MigrationManager): seq[Migration] =
  ## Returns all applied migrations
  result = @[]
  let query = "SELECT id, name, applied_at, sql FROM $1 ORDER BY id" % [mm.migrationsTable]
  
  for row in mm.db.fastRows(sql(query)):
    result.add(Migration(
      id: parseInt(row[0]),
      name: row[1],
      appliedAt: parse(row[2], "yyyy-MM-dd HH:mm:ss"),
      sql: row[3]
    ))

proc getPendingMigrations*(mm: MigrationManager): seq[string] =
  ## Returns all pending migration files
  result = @[]
  let appliedMigrations = mm.getAppliedMigrations()
  let appliedNames = appliedMigrations.mapIt(it.name)
  
  for file in walkFiles(mm.migrationsDir / "*.sql"):
    let filename = extractFilename(file)
    if filename notin appliedNames:
      result.add(file)
  
  # Sort by filename (which starts with timestamp)
  result.sort()

proc applyMigration*(mm: MigrationManager, filepath: string, down = false) =
  ## Applies a single migration
  let filename = extractFilename(filepath)
  let fileContent = readFile(filepath)
  
  # Parse the migration file to get UP and DOWN parts
  var upSql = ""
  var downSql = ""
  var currentSection = "up"
  
  for line in fileContent.splitLines():
    if line.startsWith("-- @DOWN"):
      currentSection = "down"
      continue
    
    if not line.startsWith("--"):
      if currentSection == "up":
        upSql.add(line & "\n")
      else:
        downSql.add(line & "\n")
  
  let sqlToExecute = if down: downSql else: upSql
  
  if sqlToExecute.strip() == "":
    echo "Warning: Empty SQL section in migration: " & filename
    return
  
  # Execute the SQL
  mm.db.exec(sql(sqlToExecute))
  
  if not down:
    # Record the migration in the migrations table
    let insertSql = """
    INSERT INTO $1 (name, applied_at, sql)
    VALUES (?, ?, ?)
    """ % [mm.migrationsTable]
    
    mm.db.exec(sql(insertSql), filename, now().format("yyyy-MM-dd HH:mm:ss"), sqlToExecute)
  else:
    # Remove the migration from the migrations table
    let deleteSql = "DELETE FROM $1 WHERE name = ?" % [mm.migrationsTable]
    mm.db.exec(sql(deleteSql), filename)

proc migrateUp*(mm: MigrationManager) =
  ## Applies all pending migrations
  let pendingMigrations = mm.getPendingMigrations()
  
  if pendingMigrations.len == 0:
    echo "No pending migrations"
    return
  
  echo "Applying " & $pendingMigrations.len & " migrations..."
  
  for migration in pendingMigrations:
    echo "Applying migration: " & extractFilename(migration)
    mm.applyMigration(migration)
  
  echo "Migrations completed successfully"

proc migrateDown*(mm: MigrationManager, steps = 1) =
  ## Rolls back the specified number of migrations
  let appliedMigrations = mm.getAppliedMigrations()
  
  if appliedMigrations.len == 0:
    echo "No migrations to roll back"
    return
  
  let migrationsToRollback = min(steps, appliedMigrations.len)
  echo "Rolling back " & $migrationsToRollback & " migrations..."
  
  for i in 0..<migrationsToRollback:
    let migration = appliedMigrations[^(i+1)]
    let migrationFile = mm.migrationsDir / migration.name
    
    if not fileExists(migrationFile):
      echo "Warning: Migration file not found: " & migration.name
      continue
    
    echo "Rolling back migration: " & migration.name
    mm.applyMigration(migrationFile, down = true)
  
  echo "Rollback completed successfully"