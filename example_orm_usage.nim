# example_orm_usage.nim
# Пример за работа с Prologue ORM и User модел

import std/[asyncdispatch, tables, logging]
import prologue/db/dbconfig
import prologue/db/orm/orm
import prologue/db/orm/user_model

proc main() {.async.} =
  logging.basicConfig()

  # Свържи се с базата
  let orm = connectDb(database = "testdb", username = "postgres", password = "pas+123")

  # Регистрирай модела
  orm.registerModel(UserModel)

  # Създай таблицата
  await orm.createTable("User")

  # Insert
  var userData = initTable[string, string]()
  userData["id"] = "1"
  userData["username"] = "alice"
  userData["email"] = "alice@example.com"
  userData["password"] = "secret"
  await orm.insert("User", userData)
  echo "User inserted."

  # Select by id
  let user = await orm.selectById("User", "1")
  echo "User by id: ", user

  # Update
  userData["email"] = "alice@newmail.com"
  await orm.updateById("User", "1", userData)
  echo "User updated."

  # Select all
  let users = await orm.selectAll("User")
  echo "All users: ", users

  # Delete
  await orm.deleteById("User", "1")
  echo "User deleted."

  # Drop table (cleanup)
  await orm.dropTable("User")
  echo "Table dropped."

waitFor main()
