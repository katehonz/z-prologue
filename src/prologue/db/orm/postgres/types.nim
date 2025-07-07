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

## PostgreSQL Types for Prologue ORM
## 
## This module defines PostgreSQL-specific types and their mappings
## to Nim types for the ORM system.

import std/[times, json, options, strutils]

type
  # PostgreSQL field types
  PgFieldType* = enum
    pgInteger = "INTEGER"
    pgBigInt = "BIGINT"
    pgSerial = "SERIAL"
    pgBigSerial = "BIGSERIAL"
    pgVarchar = "VARCHAR"
    pgText = "TEXT"
    pgChar = "CHAR"
    pgBoolean = "BOOLEAN"
    pgDate = "DATE"
    pgTime = "TIME"
    pgTimestamp = "TIMESTAMP"
    pgTimestampTz = "TIMESTAMPTZ"
    pgNumeric = "NUMERIC"
    pgReal = "REAL"
    pgDoublePrecision = "DOUBLE PRECISION"
    pgJson = "JSON"
    pgJsonb = "JSONB"
    pgUuid = "UUID"
    pgBytea = "BYTEA"
    pgArray = "ARRAY"

  # Field constraints
  PgConstraint* = enum
    pgPrimaryKey = "PRIMARY KEY"
    pgUnique = "UNIQUE"
    pgNotNull = "NOT NULL"
    pgForeignKey = "FOREIGN KEY"
    pgCheck = "CHECK"
    pgDefault = "DEFAULT"

  # PostgreSQL connection configuration
  PgConfig* = object
    host*: string
    port*: int
    database*: string
    username*: string
    password*: string
    sslMode*: string
    maxConnections*: int
    minConnections*: int
    connectionTimeout*: int
    commandTimeout*: int

  # PostgreSQL connection string builder
  PgConnectionString* = object
    config*: PgConfig

# Default PostgreSQL configuration
proc newPgConfig*(
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
): PgConfig =
  result = PgConfig(
    host: host,
    port: port,
    database: database,
    username: username,
    password: password,
    sslMode: sslMode,
    maxConnections: maxConnections,
    minConnections: minConnections,
    connectionTimeout: connectionTimeout,
    commandTimeout: commandTimeout
  )

# Build PostgreSQL connection string
proc buildConnectionString*(config: PgConfig): string =
  result = "postgresql://" & config.username & ":" & config.password & 
           "@" & config.host & ":" & $config.port & "/" & config.database &
           "?sslmode=" & config.sslMode

# Type mapping from Nim to PostgreSQL
proc nimTypeToPgType*(nimType: string): PgFieldType =
  case nimType:
  of "int", "int32": pgInteger
  of "int64": pgBigInt
  of "string": pgText
  of "bool": pgBoolean
  of "float", "float32": pgReal
  of "float64": pgDoublePrecision
  of "DateTime": pgTimestamp
  of "JsonNode": pgJsonb
  else: pgText

# PostgreSQL type to Nim type conversion
proc pgTypeToNimType*(pgType: PgFieldType): string =
  case pgType:
  of pgInteger, pgSerial: "int"
  of pgBigInt, pgBigSerial: "int64"
  of pgVarchar, pgText, pgChar: "string"
  of pgBoolean: "bool"
  of pgReal: "float32"
  of pgDoublePrecision: "float64"
  of pgDate, pgTime, pgTimestamp, pgTimestampTz: "DateTime"
  of pgJson, pgJsonb: "JsonNode"
  of pgNumeric: "string"  # Handle as string for precision
  of pgUuid: "string"
  of pgBytea: "seq[byte]"
  of pgArray: "seq[string]"  # Generic array type

# SQL value escaping for PostgreSQL
proc escapePgValue*(value: string): string =
  result = "'" & value.replace("'", "''") & "'"

proc formatPgValue*(value: JsonNode): string =
  case value.kind:
  of JString:
    result = escapePgValue(value.getStr())
  of JInt:
    result = $value.getInt()
  of JFloat:
    result = $value.getFloat()
  of JBool:
    result = if value.getBool(): "TRUE" else: "FALSE"
  of JNull:
    result = "NULL"
  of JObject, JArray:
    result = escapePgValue($value)