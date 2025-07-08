# Ormin ORM (bormin) Documentation

## Overview
Ormin ORM (`bormin`) is a custom, extensible Object-Relational Mapping library for Nim, designed for flexible model definition, schema management, and efficient database access. It supports both PostgreSQL and SQLite backends, and is easily integrated with your Nim applications.

---

## Quickstart

1. **Define your models:**
```nim
import src/prologue/db/bormin/models

proc defineModels*() =
  let userModel = newModelBuilder("User")
  discard userModel.column("id", dbInt).primaryKey()
  discard userModel.column("username", dbVarchar).notNull()
  userModel.build()
defineModels()
```

2. **Connect to the database:**
```nim
import src/prologue/db/dbconfig
let orm = connectDb(database = "mydb", username = "user", password = "secret")
```

3. **Create tables:**
```nim
let sql = generateSql(modelRegistry)
orm.conn.exec(sql)
```

4. **CRUD operations:**
```nim
# Example: Fetch all users
echo orm.conn.fastRows("SELECT * FROM User")
```

---

## Model Definition
- Use `newModelBuilder("TableName")` to define models programmatically.
- Chain `.column`, `.primaryKey()`, `.notNull()`, `.default()`, `.foreignKey()` for column constraints.
- Register models globally with `.build()`.

## Database Configuration
- Centralized in `src/prologue/db/dbconfig.nim`.
- Use `connectDb()` to create an `ORM` object with connection and registry.
- Supports setting host, port, database, username, password, pool size.

## Connection Pooling
- Efficient async pooling available (see `connectionpool.nim`).
- Use for scalable, concurrent applications.

## CRUD Operations
- Use `orm.conn.exec()` for SQL commands.
- Use `orm.conn.fastRows()` for query results.
- Extend with your own query helpers as needed.

## Migrations
- Define and run migrations using the `migrations.nim` module.
- Supports schema evolution and versioning.

## Integration
- Import `bormin/models` and call `defineModels()` at app startup.
- Connect using `connectDb` and use the ORM in your business logic or handlers.

## Extending
- Add new backends by implementing the required DbConn interface.
- Extend the model registry or query builder as needed.

## FAQ & Troubleshooting
- **Q:** How do I add a new column?  
  **A:** Update your model definition and re-run migrations or SQL generation.
- **Q:** How do I switch database backends?  
  **A:** Import the relevant backend module and adjust your connection string.

---

For more examples, see `main_ormin_example.nim` and the `examples/` folder.
