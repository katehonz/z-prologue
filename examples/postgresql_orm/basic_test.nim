# Basic PostgreSQL Connection Test
# 
# This test verifies that we can connect to PostgreSQL database
# and perform basic operations without the complex ORM layer.

import std/[asyncdispatch, logging, strutils]
import db_connector/db_postgres

# Configure logging
addHandler(newConsoleLogger(fmtStr="[$time] - $levelname: "))
setLogFilter(lvlInfo)

proc testPostgreSQLConnection() {.async.} =
  echo "🚀 Starting Basic PostgreSQL Connection Test..."
  
  try:
    # Connection parameters
    let 
      host = "localhost"
      port = 5432
      database = "ex-orm"
      username = "postgres"
      password = "azina681024"
    
    echo "📡 Connecting to PostgreSQL..."
    echo "🔗 Connection: ", host, ":", port, "/", database
    
    # Open connection using separate parameters
    let db = open(host, username, password, database)
    
    echo "✅ Connection established successfully!"
    
    # Test basic query
    echo "🔍 Testing basic query..."
    let version = db.getValue(sql"SELECT version()")
    echo "📊 PostgreSQL version: ", version[0..50], "..."
    
    # Test current database
    let currentDb = db.getValue(sql"SELECT current_database()")
    echo "💾 Current database: ", currentDb
    
    # Test current user
    let currentUser = db.getValue(sql"SELECT current_user")
    echo "👤 Current user: ", currentUser
    
    # Test table creation
    echo "🏗️ Testing table creation..."
    
    # Drop table if exists
    db.exec(sql"DROP TABLE IF EXISTS test_connection")
    
    # Create test table
    db.exec(sql"""
      CREATE TABLE test_connection (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    """)
    echo "✅ Test table created successfully"
    
    # Test insert
    echo "➕ Testing insert operation..."
    db.exec(sql"INSERT INTO test_connection (name) VALUES (?)", "Test User 1")
    db.exec(sql"INSERT INTO test_connection (name) VALUES (?)", "Test User 2")
    echo "✅ Insert operations completed"
    
    # Test select
    echo "🔍 Testing select operation..."
    let rows = db.getAllRows(sql"SELECT id, name, created_at FROM test_connection ORDER BY id")
    echo "📋 Found ", rows.len, " rows:"
    
    for row in rows:
      if row.len >= 3:
        echo "  ID: ", row[0], ", Name: ", row[1], ", Created: ", row[2][0..18]
    
    # Test count
    let count = db.getValue(sql"SELECT COUNT(*) FROM test_connection")
    echo "📊 Total rows: ", count
    
    # Test update
    echo "🔄 Testing update operation..."
    db.exec(sql"UPDATE test_connection SET name = ? WHERE id = ?", "Updated User", "1")
    
    let updatedName = db.getValue(sql"SELECT name FROM test_connection WHERE id = 1")
    echo "✅ Updated name: ", updatedName
    
    # Test delete
    echo "🗑️ Testing delete operation..."
    db.exec(sql"DELETE FROM test_connection WHERE id = ?", "2")
    
    let finalCount = db.getValue(sql"SELECT COUNT(*) FROM test_connection")
    echo "📊 Final count after delete: ", finalCount
    
    # Cleanup
    echo "🧹 Cleaning up..."
    db.exec(sql"DROP TABLE test_connection")
    echo "✅ Test table dropped"
    
    # Close connection
    db.close()
    echo "🔌 Connection closed"
    
    echo "🎉 All basic tests completed successfully!"
    
  except Exception as e:
    echo "❌ Test failed with error: ", e.msg
    echo "📋 Error type: ", $e.name
    
    # Additional troubleshooting info
    echo ""
    echo "🔧 Troubleshooting tips:"
    echo "  1. Make sure PostgreSQL server is running"
    echo "  2. Check if database 'ex-orm' exists"
    echo "  3. Verify username 'postgres' and password"
    echo "  4. Check if PostgreSQL is listening on port 5432"
    echo "  5. Ensure db_connector package is installed: nimble install db_connector"

proc main() {.async.} =
  echo "=" .repeat(60)
  echo "PostgreSQL Basic Connection Test"
  echo "=" .repeat(60)
  
  await testPostgreSQLConnection()
  
  echo "=" .repeat(60)
  echo "Test completed"
  echo "=" .repeat(60)

when isMainModule:
  waitFor main()