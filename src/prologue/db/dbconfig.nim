# dbconfig.nim
# Конфигурация и инициализация на ORM връзка към база данни

import ./bormin/models

# Структура за централизирана конфигурация
const
  DefaultHost = "localhost"
  DefaultPort = 5432
  DefaultDatabase = "prologue"
  DefaultUsername = "postgres"
  DefaultPassword = "pas+123"
  DefaultMaxConnections = 10
  DefaultMinConnections = 2

# Функция за инициализация на ORM с параметри или дефолтни стойности
proc connectDb*(
  host: string = DefaultHost,
  port: int = DefaultPort,
  database: string = DefaultDatabase,
  username: string = DefaultUsername,
  password: string = DefaultPassword,
  maxConnections: int = DefaultMaxConnections,
  minConnections: int = DefaultMinConnections
): ORM =
  let conn = open(host, username, password, database)
  result = ORM(conn: conn, registry: modelRegistry)


# Пример за употреба:
# import prologue/db/dbconfig
# let orm = connectDb(database = "mydb", username = "user", password = "secret")
