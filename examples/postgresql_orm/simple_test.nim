# Simple PostgreSQL ORM Test
# 
# This is a simplified test to verify the basic ORM functionality
# without the complex web application setup.

import std/[asyncdispatch, json, logging, strutils]
import ../../src/prologue/db/orm/[orm, model]
import ../../src/prologue/db/orm/postgres/types

# Configure logging
addHandler(newConsoleLogger(fmtStr="[$time] - $levelname: "))
setLogFilter(lvlInfo)

# Simple User model for testing
type
  TestUser* = ref object of Model
    username*: string
    email*: string
    isActive*: bool

# Simple test procedures
proc testBasicORM() {.async.} =
  echo "🚀 Starting PostgreSQL ORM Test..."
  
  try:
    # Initialize ORM
    echo "📡 Initializing ORM connection..."
    let orm = initORM(
      host = "localhost",
      port = 5432,
      database = "ex-orm",
      username = "postgres",
      password = "azina681024",
      maxConnections = 5,
      minConnections = 1
    )
    
    # Test connection
    echo "🔌 Testing database connection..."
    let connected = await orm.testConnection()
    if not connected:
      echo "❌ Failed to connect to database"
      return
    
    echo "✅ Database connection successful!"
    
    # Register simple model metadata (simplified)
    let userMeta = ModelMeta(
      name: "TestUser",
      tableName: "test_users",
      fields: @[
        FieldMeta(
          name: "id",
          pgType: pgSerial,
          nimType: "int",
          constraints: @[pgPrimaryKey],
          defaultValue: ""
        ),
        FieldMeta(
          name: "username",
          pgType: pgVarchar,
          nimType: "string", 
          constraints: @[pgNotNull],
          defaultValue: ""
        ),
        FieldMeta(
          name: "email",
          pgType: pgVarchar,
          nimType: "string",
          constraints: @[pgNotNull],
          defaultValue: ""
        ),
        FieldMeta(
          name: "is_active",
          pgType: pgBoolean,
          nimType: "bool",
          constraints: @[pgDefault],
          defaultValue: "true"
        )
      ],
      primaryKey: "id"
    )
    
    orm.registerModel(userMeta)
    echo "📝 Model registered successfully"
    
    # Test table creation
    echo "🏗️ Creating table if not exists..."
    let tableExists = await orm.tableExists("TestUser")
    if not tableExists:
      await orm.createTable("TestUser")
      echo "✅ Table created successfully"
    else:
      echo "ℹ️ Table already exists"
    
    # Test basic SQL operations
    echo "🔍 Testing basic SQL operations..."
    
    # Test simple query
    let version = await orm.queryValue("SELECT version()")
    echo "📊 PostgreSQL version: ", version[0..50], "..."
    
    # Test table count
    let userCount = await orm.queryValue("SELECT COUNT(*) FROM test_users")
    echo "👥 Current users in table: ", userCount
    
    # Test insert (simplified)
    echo "➕ Testing insert operation..."
    let insertResult = await orm.execute(
      "INSERT INTO test_users (username, email, is_active) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
      @["test_user", "test@example.com", "true"]
    )
    echo "✅ Insert operation completed"
    
    # Test select
    echo "🔍 Testing select operation..."
    let users = await orm.execute("SELECT * FROM test_users LIMIT 5")
    echo "📋 Found ", users.rows.len, " users"
    
    for i, row in users.rows:
      if row.len >= 3:
        echo "  User ", i+1, ": ", row[1], " (", row[2], ")"
    
    # Test transaction
    echo "🔄 Testing transaction..."
    await orm.withTransaction(proc(): Future[void] {.async.} =
      discard await orm.execute(
        "INSERT INTO test_users (username, email, is_active) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING",
        @["tx_user", "tx@example.com", "true"]
      )
      echo "  Transaction operation completed"
    )
    echo "✅ Transaction test completed"
    
    # Final count
    let finalCount = await orm.queryValue("SELECT COUNT(*) FROM test_users")
    echo "📊 Final user count: ", finalCount
    
    echo "🎉 All tests completed successfully!"
    
  except Exception as e:
    echo "❌ Test failed with error: ", e.msg
    echo "📋 Error details: ", e.getStackTrace()

# Main test runner
proc main() {.async.} =
  echo "=" .repeat(50)
  echo "PostgreSQL ORM Basic Test"
  echo "=" .repeat(50)
  
  await testBasicORM()
  
  echo "=" .repeat(50)
  echo "Test completed"
  echo "=" .repeat(50)

when isMainModule:
  waitFor main()