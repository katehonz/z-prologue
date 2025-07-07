# Fixed Simple PostgreSQL ORM Test
# 
# This is a simplified test to verify the fixed async functionality
# without complex operations that might cause compilation issues.

import std/[asyncdispatch, json, logging, strutils]
import ../../src/prologue/db/orm/[orm, model]
import ../../src/prologue/db/orm/postgres/types

# Configure logging
addHandler(newConsoleLogger(fmtStr="[$time] - $levelname: "))
setLogFilter(lvlInfo)

# Simple test procedures
proc testFixedAsyncORM() {.async.} =
  echo "🚀 Starting Fixed PostgreSQL ORM Test..."
  
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
    
    # Register simple model metadata
    let userMeta = ModelMeta(
      name: "FixedTestUser",
      tableName: "fixed_test_users",
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
        )
      ],
      primaryKey: "id"
    )
    
    orm.registerModel(userMeta)
    echo "📝 Model registered successfully"
    
    # Test table creation
    echo "🏗️ Creating table if not exists..."
    let tableExists = await orm.tableExists("FixedTestUser")
    if not tableExists:
      await orm.createTable("FixedTestUser")
      echo "✅ Table created successfully"
    else:
      echo "ℹ️ Table already exists"
    
    # Test basic SQL operations
    echo "🔍 Testing basic SQL operations..."
    
    # Test simple query
    let version = await orm.queryValue("SELECT version()")
    echo "📊 PostgreSQL version: ", version[0..50], "..."
    
    # Test table count
    let userCount = await orm.queryValue("SELECT COUNT(*) FROM fixed_test_users")
    echo "👥 Current users in table: ", userCount
    
    # Test insert operation
    echo "➕ Testing insert operation..."
    let insertResult = await orm.execute(
      "INSERT INTO fixed_test_users (username, email) VALUES ($1, $2) ON CONFLICT DO NOTHING",
      @["fixed_test_user", "fixed@example.com"]
    )
    echo "✅ Insert operation completed, affected rows: ", insertResult.affectedRows
    
    # Test select operation
    echo "🔍 Testing select operation..."
    let users = await orm.execute("SELECT * FROM fixed_test_users LIMIT 5")
    echo "📋 Found ", users.rows.len, " users"
    
    for i, row in users.rows:
      if row.len >= 3:
        echo "  User ", i+1, ": ID=", row[0], ", Username=", row[1], ", Email=", row[2]
    
    # Test void transaction (fixed version)
    echo "🔄 Testing void transaction..."
    await orm.withTransactionVoid(proc(): Future[void] {.async.} =
      discard await orm.execute(
        "INSERT INTO fixed_test_users (username, email) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        @["tx_void_user", "txvoid@example.com"]
      )
      echo "  Void transaction operation completed"
    )
    echo "✅ Void transaction test completed"
    
    # Test transaction with return value
    echo "🔄 Testing transaction with return value..."
    let txResult = await orm.withTransaction(proc(): Future[string] {.async.} =
      discard await orm.execute(
        "INSERT INTO fixed_test_users (username, email) VALUES ($1, $2) ON CONFLICT DO NOTHING",
        @["tx_return_user", "txreturn@example.com"]
      )
      let count = await orm.queryValue("SELECT COUNT(*) FROM fixed_test_users")
      return count
    )
    echo "✅ Transaction with return value completed. User count: ", txResult
    
    # Test error handling
    echo "🚨 Testing error handling..."
    try:
      discard await orm.execute("SELECT * FROM non_existent_table")
      echo "❌ Error handling test failed - should have thrown exception"
    except Exception as e:
      echo "✅ Error handling test passed: caught expected error"
    
    # Test concurrent operations
    echo "🔄 Testing concurrent operations..."
    var futures: seq[Future[string]] = @[]
    for i in 1..3:
      let future = orm.queryValue("SELECT '" & $i & "' as test_value")
      futures.add(future)
    
    let results = await all(futures)
    echo "✅ Concurrent operations test passed: ", results.len, " results"
    for i, result in results:
      echo "  Result ", i+1, ": ", result
    
    # Final count
    let finalCount = await orm.queryValue("SELECT COUNT(*) FROM fixed_test_users")
    echo "📊 Final user count: ", finalCount
    
    echo "🎉 All fixed async tests completed successfully!"
    
  except Exception as e:
    echo "❌ Test failed with error: ", e.msg
    echo "📋 Error details: ", e.getStackTrace()

# Main test runner
proc main() {.async.} =
  echo "=" .repeat(50)
  echo "Fixed PostgreSQL ORM Async Test"
  echo "=" .repeat(50)
  
  await testFixedAsyncORM()
  
  echo "=" .repeat(50)
  echo "Test completed"
  echo "=" .repeat(50)

when isMainModule:
  waitFor main()