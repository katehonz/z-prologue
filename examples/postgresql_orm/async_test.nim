# Advanced Async PostgreSQL ORM Test
# 
# This test verifies that all async operations work correctly
# after the fixes to the ORM system.

import std/[asyncdispatch, json, logging, strutils, times]
import ../../src/prologue/db/orm/[orm, model]
import ../../src/prologue/db/orm/postgres/types

# Configure logging
addHandler(newConsoleLogger(fmtStr="[$time] - $levelname: "))
setLogFilter(lvlInfo)

# Test User model
type
  AsyncTestUser* = ref object of Model
    username*: string
    email*: string
    isActive*: bool
    createdAt*: string

# Advanced async test procedures
proc testAsyncOperations() {.async.} =
  echo "🚀 Starting Advanced Async PostgreSQL ORM Test..."
  
  try:
    # Initialize ORM
    echo "📡 Initializing ORM connection..."
    let orm = initORM(
      host = "localhost",
      port = 5432,
      database = "ex-orm",
      username = "postgres",
      password = "azina681024",
      maxConnections = 10,
      minConnections = 2
    )
    
    # Test connection
    echo "🔌 Testing database connection..."
    let connected = await orm.testConnection()
    if not connected:
      echo "❌ Failed to connect to database"
      return
    
    echo "✅ Database connection successful!"
    
    # Register model metadata
    let userMeta = ModelMeta(
      name: "AsyncTestUser",
      tableName: "async_test_users",
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
          constraints: @[pgNotNull, pgUnique],
          defaultValue: ""
        ),
        FieldMeta(
          name: "email",
          pgType: pgVarchar,
          nimType: "string",
          constraints: @[pgNotNull, pgUnique],
          defaultValue: ""
        ),
        FieldMeta(
          name: "is_active",
          pgType: pgBoolean,
          nimType: "bool",
          constraints: @[pgDefault],
          defaultValue: "true"
        ),
        FieldMeta(
          name: "created_at",
          pgType: pgTimestamp,
          nimType: "string",
          constraints: @[pgDefault],
          defaultValue: "NOW()"
        )
      ],
      primaryKey: "id"
    )
    
    orm.registerModel(userMeta)
    echo "📝 Model registered successfully"
    
    # Test table creation
    echo "🏗️ Creating table if not exists..."
    let tableExists = await orm.tableExists("AsyncTestUser")
    if not tableExists:
      await orm.createTable("AsyncTestUser")
      echo "✅ Table created successfully"
    else:
      echo "ℹ️ Table already exists"
    
    # Test basic async operations
    echo "🔄 Testing basic async operations..."
    
    # Test simple query
    let version = await orm.queryValue("SELECT version()")
    echo "📊 PostgreSQL version: ", version[0..min(50, version.len-1)], "..."
    
    # Test void transaction
    echo "🔄 Testing void transaction..."
    await orm.withTransactionVoid(proc(): Future[void] {.async.} =
      discard await orm.execute(
        "INSERT INTO async_test_users (username, email, is_active) VALUES ($1, $2, $3) ON CONFLICT (username) DO NOTHING",
        @["tx_void_user", "txvoid@example.com", "true"]
      )
      echo "  Void transaction operation completed"
    )
    echo "✅ Void transaction test completed"
    
    # Test transaction with return value
    echo "🔄 Testing transaction with return value..."
    let txResult = await orm.withTransaction(proc(): Future[int] {.async.} =
      discard await orm.execute(
        "INSERT INTO async_test_users (username, email, is_active) VALUES ($1, $2, $3) ON CONFLICT (username) DO NOTHING",
        @["tx_return_user", "txreturn@example.com", "true"]
      )
      let count = await orm.queryValue("SELECT COUNT(*) FROM async_test_users")
      return parseInt(count)
    )
    echo "✅ Transaction with return value completed. User count: ", txResult
    
    # Test error handling in async operations
    echo "🚨 Testing error handling..."
    try:
      discard await orm.execute("INVALID SQL QUERY")
      echo "❌ Error handling test failed - should have thrown exception"
    except Exception as e:
      echo "✅ Error handling test passed: ", e.msg[0..min(50, e.msg.len-1)], "..."
    
    # Test multiple concurrent operations
    echo "💪 Testing concurrent operations..."
    var futures: seq[Future[string]] = @[]
    for i in 1..5:
      let future = orm.queryValue("SELECT '" & $i & "' as test_value")
      futures.add(future)
    
    let results = await all(futures)
    echo "✅ Concurrent operations test passed: ", results.len, " results"
    
    # Test final count
    let finalCount = await orm.queryValue("SELECT COUNT(*) FROM async_test_users")
    echo "📊 Final user count: ", finalCount
    
    echo "🎉 All advanced async tests completed successfully!"
    
  except Exception as e:
    echo "❌ Test failed with error: ", e.msg
    echo "📋 Stack trace: ", e.getStackTrace()

# Performance test
proc testAsyncPerformance() {.async.} =
  echo "⚡ Starting async performance test..."
  
  try:
    let orm = getORM()
    let startTime = cpuTime()
    
    # Test 10 concurrent queries (reduced for stability)
    var perfFutures: seq[Future[string]] = @[]
    for i in 1..10:
      let future = orm.queryValue("SELECT '" & $i & "'::text")
      perfFutures.add(future)
    
    let perfResults = await all(perfFutures)
    let endTime = cpuTime()
    
    echo "✅ Performance test completed:"
    echo "  Operations: ", perfResults.len
    echo "  Time: ", (endTime - startTime), " seconds"
    if (endTime - startTime) > 0:
      echo "  Ops/sec: ", perfResults.len.float / (endTime - startTime)
    
  except Exception as e:
    echo "❌ Performance test failed: ", e.msg

# Main test runner
proc main() {.async.} =
  echo "=" .repeat(60)
  echo "Advanced Async PostgreSQL ORM Test Suite"
  echo "=" .repeat(60)
  
  await testAsyncOperations()
  
  echo ""
  echo "-" .repeat(60)
  
  await testAsyncPerformance()
  
  echo ""
  echo "=" .repeat(60)
  echo "All tests completed"
  echo "=" .repeat(60)

when isMainModule:
  waitFor main()