# main_ormin_example.nim
# Стартиращ пример за интеграция на Ormin ORM с приложение на Prologue

import std/[asyncdispatch, logging]
import src/prologue/db/dbconfig
import src/prologue/db/bormin/models

# 1. Дефинирай моделите (пример)
proc defineModels*() =
  let userModel = newModelBuilder("User")
  discard userModel.column("id", dbInt).primaryKey()
  discard userModel.column("username", dbVarchar).notNull()
  discard userModel.column("email", dbVarchar).notNull()
  discard userModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  userModel.build()

defineModels()

# 2. Свържи се с базата (пример с PostgreSQL)
let orm = connectDb(host = "localhost", username = "postgres", password = "pas+123", database = "prologue")

# 3. Създай таблиците автоматично при старт
let sql = generateSql(modelRegistry)
orm.conn.exec(sql)

# 4. Примерен handler за Prologue (ако ползваш framework)
# (Може да се интегрира в твоя routing logic)
# proc getUsersHandler(ctx: Context) {.async.} =
#   let users = orm.conn.fastRows("SELECT * FROM User")
#   ctx.respond($users)

# 5. Примерен main за standalone тест
proc main() {.async.} =
  logging.setLogFilter(lvlAll)
  echo "Таблиците са създадени. Ormin ORM е готов за работа!"
  # Тук може да добавиш CRUD операции, заявки, и т.н.

waitFor main()
