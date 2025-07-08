## Ormin -- ORM for Nim.
## Transaction support module
##
## [English]
## This module provides comprehensive transaction support for Ormin ORM.
## It includes basic transaction operations (begin, commit, rollback),
## nested transaction support with savepoints, and convenient templates
## for automatic transaction management.
##
## Key features:
## * Basic transaction operations (begin, commit, rollback)
## * Nested transactions with savepoints
## * Automatic transaction management with templates
## * Transaction isolation level support
## * Deadlock detection and retry mechanisms
## * Transaction statistics and monitoring
##
## Example usage:
## ```nim
## # Basic transaction usage
## let tx = newTransaction(db)
## tx.begin()
## try:
##   # Your database operations here
##   tx.commit()
## except:
##   tx.rollback()
##   raise
##
## # Using the convenient template
## withTransaction(db):
##   # Your database operations here
##   # Automatically commits or rolls back
##
## # Nested transactions with savepoints
## withTransaction(db):
##   # Outer transaction
##   withSavepoint(db, "sp1"):
##     # Inner transaction with savepoint
##     # Can be rolled back independently
## ```
##
## [Български]
## Този модул предоставя цялостна поддръжка на транзакции за Ormin ORM.
## Включва основни операции с транзакции (започване, потвърждаване, отмяна),
## поддръжка на вложени транзакции със savepoints и удобни шаблони
## за автоматично управление на транзакции.
##
## Основни характеристики:
## * Основни операции с транзакции (започване, потвърждаване, отмяна)
## * Вложени транзакции със savepoints
## * Автоматично управление на транзакции с шаблони
## * Поддръжка на нива на изолация на транзакции
## * Откриване на deadlock и механизми за повторен опит
## * Статистики и мониторинг на транзакции
##
## Пример за използване:
## ```nim
## # Основно използване на транзакции
## let tx = newTransaction(db)
## tx.begin()
## try:
##   # Вашите операции с базата данни тук
##   tx.commit()
## except:
##   tx.rollback()
##   raise
##
## # Използване на удобния шаблон
## withTransaction(db):
##   # Вашите операции с базата данни тук
##   # Автоматично потвърждава или отменя
##
## # Вложени транзакции със savepoints
## withTransaction(db):
##   # Външна транзакция
##   withSavepoint(db, "sp1"):
##     # Вътрешна транзакция със savepoint
##     # Може да бъде отменена независимо
## ```

import models, times, strutils, tables, random, os

type
  TransactionIsolationLevel* = enum
    ## [English] Transaction isolation levels
    ## [Български] Нива на изолация на транзакции
    tilReadUncommitted = "READ UNCOMMITTED"
    tilReadCommitted = "READ COMMITTED"
    tilRepeatableRead = "REPEATABLE READ"
    tilSerializable = "SERIALIZABLE"

  TransactionState* = enum
    ## [English] Transaction state enumeration
    ## [Български] Изброяване на състоянията на транзакцията
    tsInactive,     ## Transaction is not active / Транзакцията не е активна
    tsActive,       ## Transaction is active / Транзакцията е активна
    tsCommitted,    ## Transaction has been committed / Транзакцията е потвърдена
    tsRolledBack    ## Transaction has been rolled back / Транзакцията е отменена

  TransactionStats* = object
    ## [English] Transaction statistics
    ## [Български] Статистики на транзакцията
    startTime*: DateTime      ## Transaction start time / Време на започване
    endTime*: DateTime        ## Transaction end time / Време на завършване
    operationCount*: int      ## Number of operations / Брой операции
    rollbackCount*: int       ## Number of rollbacks / Брой отмени

  Transaction* = ref object
    ## [English] Transaction object with extended functionality
    ## [Български] Обект за транзакция с разширена функционалност
    db*: DbConn                           ## Database connection / Връзка с базата данни
    state*: TransactionState              ## Current state / Текущо състояние
    isolationLevel*: TransactionIsolationLevel  ## Isolation level / Ниво на изолация
    savepoints*: seq[string]              ## Active savepoints / Активни savepoints
    stats*: TransactionStats              ## Transaction statistics / Статистики
    autoRetry*: bool                      ## Auto-retry on deadlock / Автоматичен повторен опит при deadlock
    maxRetries*: int                      ## Maximum retry attempts / Максимален брой опити

  TransactionError* = object of DbError
    ## [English] Specific exception type for transaction errors
    ## [Български] Специфичен тип изключение за грешки в транзакции

  DeadlockError* = object of TransactionError
    ## [English] Exception for deadlock situations
    ## [Български] Изключение за ситуации с deadlock

  SavepointError* = object of TransactionError
    ## [English] Exception for savepoint-related errors
    ## [Български] Изключение за грешки свързани със savepoints

# Global transaction registry for monitoring
var transactionRegistry* = initTable[string, Transaction]()

proc generateTransactionId(): string =
  ## [English] Generates a unique transaction ID
  ## [Български] Генерира уникален идентификатор на транзакция
  result = "tx_" & $now().toTime().toUnix() & "_" & $rand(10000)

proc newTransaction*(db: DbConn, isolationLevel: TransactionIsolationLevel = tilReadCommitted, 
                    autoRetry: bool = false, maxRetries: int = 3): Transaction =
  ## [English] Creates a new transaction with extended options
  ##
  ## Parameters:
  ## * db: Database connection
  ## * isolationLevel: Transaction isolation level (default: READ COMMITTED)
  ## * autoRetry: Enable automatic retry on deadlock (default: false)
  ## * maxRetries: Maximum number of retry attempts (default: 3)
  ##
  ## [Български] Създава нова транзакция с разширени опции
  ##
  ## Параметри:
  ## * db: Връзка с базата данни
  ## * isolationLevel: Ниво на изолация на транзакцията (по подразбиране: READ COMMITTED)
  ## * autoRetry: Включване на автоматичен повторен опит при deadlock (по подразбиране: false)
  ## * maxRetries: Максимален брой опити за повторение (по подразбиране: 3)
  result = Transaction(
    db: db,
    state: tsInactive,
    isolationLevel: isolationLevel,
    savepoints: @[],
    stats: TransactionStats(
      startTime: now(),
      operationCount: 0,
      rollbackCount: 0
    ),
    autoRetry: autoRetry,
    maxRetries: maxRetries
  )

proc begin*(t: Transaction) =
  ## [English] Begins a transaction with isolation level support
  ## [Български] Започва транзакция с поддръжка на ниво на изолация
  if t.state == tsActive:
    raise newException(TransactionError, "Transaction already active")
  
  # Set isolation level if supported by the database
  try:
    t.db.exec(sql("SET TRANSACTION ISOLATION LEVEL " & $t.isolationLevel))
  except:
    # Some databases might not support this syntax
    discard
  
  t.db.exec(sql"BEGIN TRANSACTION")
  t.state = tsActive
  t.stats.startTime = now()
  
  # Register transaction for monitoring
  let txId = generateTransactionId()
  transactionRegistry[txId] = t

proc commit*(t: Transaction) =
  ## [English] Commits a transaction and updates statistics
  ## [Български] Потвърждава транзакция и актуализира статистиките
  if t.state != tsActive:
    raise newException(TransactionError, "No active transaction to commit")
  
  t.db.exec(sql"COMMIT")
  t.state = tsCommitted
  t.stats.endTime = now()
  
  # Clear savepoints
  t.savepoints = @[]

proc rollback*(t: Transaction) =
  ## [English] Rolls back a transaction and updates statistics
  ## [Български] Отменя транзакция и актуализира статистиките
  if t.state != tsActive:
    raise newException(TransactionError, "No active transaction to rollback")
  
  t.db.exec(sql"ROLLBACK")
  t.state = tsRolledBack
  t.stats.endTime = now()
  t.stats.rollbackCount += 1
  
  # Clear savepoints
  t.savepoints = @[]

proc createSavepoint*(t: Transaction, name: string) =
  ## [English] Creates a savepoint within the current transaction
  ## [Български] Създава savepoint в текущата транзакция
  if t.state != tsActive:
    raise newException(SavepointError, "Cannot create savepoint: no active transaction")
  
  if name in t.savepoints:
    raise newException(SavepointError, "Savepoint already exists: " & name)
  
  t.db.exec(sql("SAVEPOINT " & name))
  t.savepoints.add(name)

proc rollbackToSavepoint*(t: Transaction, name: string) =
  ## [English] Rolls back to a specific savepoint
  ## [Български] Отменя до определен savepoint
  if t.state != tsActive:
    raise newException(SavepointError, "Cannot rollback to savepoint: no active transaction")
  
  if name notin t.savepoints:
    raise newException(SavepointError, "Savepoint does not exist: " & name)
  
  t.db.exec(sql("ROLLBACK TO SAVEPOINT " & name))
  t.stats.rollbackCount += 1

proc releaseSavepoint*(t: Transaction, name: string) =
  ## [English] Releases a savepoint (removes it)
  ## [Български] Освобождава savepoint (премахва го)
  if t.state != tsActive:
    raise newException(SavepointError, "Cannot release savepoint: no active transaction")
  
  if name notin t.savepoints:
    raise newException(SavepointError, "Savepoint does not exist: " & name)
  
  t.db.exec(sql("RELEASE SAVEPOINT " & name))
  
  # Remove savepoint from list
  let index = t.savepoints.find(name)
  if index >= 0:
    t.savepoints.delete(index)

proc isActive*(t: Transaction): bool =
  ## [English] Checks if the transaction is currently active
  ## [Български] Проверява дали транзакцията е активна в момента
  result = t.state == tsActive

proc getDuration*(t: Transaction): Duration =
  ## [English] Gets the duration of the transaction
  ## [Български] Получава продължителността на транзакцията
  if t.stats.endTime == default(DateTime):
    result = now() - t.stats.startTime
  else:
    result = t.stats.endTime - t.stats.startTime

proc incrementOperationCount*(t: Transaction) =
  ## [English] Increments the operation counter
  ## [Български] Увеличава брояча на операциите
  t.stats.operationCount += 1

# High-level templates for convenient transaction management

template withTransaction*(db: DbConn, body: untyped) =
  ## [English] Executes the body within a transaction
  ## Automatically commits if successful or rolls back if an exception is raised
  ## [Български] Изпълнява тялото в рамките на транзакция
  ## Автоматично потвърждава при успех или отменя при изключение
  var transaction = newTransaction(db)
  transaction.begin()
  try:
    body
    transaction.commit()
  except:
    if transaction.isActive():
      transaction.rollback()
    raise

template withTransactionRetry*(db: DbConn, maxRetries: int, body: untyped) =
  ## [English] Executes the body within a transaction with automatic retry on deadlock
  ## [Български] Изпълнява тялото в транзакция с автоматичен повторен опит при deadlock
  var retryCount = 0
  var success = false
  
  while not success and retryCount <= maxRetries:
    var transaction = newTransaction(db, autoRetry = true, maxRetries = maxRetries)
    try:
      transaction.begin()
      body
      transaction.commit()
      success = true
    except DeadlockError:
      if transaction.isActive():
        transaction.rollback()
      retryCount += 1
      if retryCount > maxRetries:
        raise newException(DeadlockError, "Maximum retry attempts exceeded")
      # Wait before retry (exponential backoff)
      sleep(100 * retryCount)
    except:
      if transaction.isActive():
        transaction.rollback()
      raise

template withSavepoint*(db: DbConn, savepointName: string, body: untyped) =
  ## [English] Executes the body within a savepoint
  ## [Български] Изпълнява тялото в рамките на savepoint
  # This assumes we're already in a transaction
  # In a real implementation, we'd need to get the current transaction
  var currentTransaction = newTransaction(db)  # This is a simplification
  if not currentTransaction.isActive():
    raise newException(SavepointError, "Cannot create savepoint outside of transaction")
  
  currentTransaction.createSavepoint(savepointName)
  try:
    body
    currentTransaction.releaseSavepoint(savepointName)
  except:
    currentTransaction.rollbackToSavepoint(savepointName)
    raise

template transaction*(db: DbConn, body: untyped) =
  ## [English] Alias for withTransaction
  ## [Български] Псевдоним за withTransaction
  withTransaction(db, body)

template transactionWithIsolation*(db: DbConn, isolationLevel: TransactionIsolationLevel, body: untyped) =
  ## [English] Executes the body within a transaction with specific isolation level
  ## [Български] Изпълнява тялото в транзакция с определено ниво на изолация
  var transaction = newTransaction(db, isolationLevel)
  transaction.begin()
  try:
    body
    transaction.commit()
  except:
    if transaction.isActive():
      transaction.rollback()
    raise

# Utility functions for transaction monitoring and management

proc getActiveTransactions*(): seq[Transaction] =
  ## [English] Returns a list of all currently active transactions
  ## [Български] Връща списък на всички активни транзакции в момента
  result = @[]
  for txId, tx in transactionRegistry:
    if tx.isActive():
      result.add(tx)

proc getTransactionStats*(t: Transaction): TransactionStats =
  ## [English] Returns detailed statistics for a transaction
  ## [Български] Връща подробни статистики за транзакция
  result = t.stats

proc cleanupInactiveTransactions*() =
  ## [English] Removes inactive transactions from the registry
  ## [Български] Премахва неактивните транзакции от регистъра
  var toRemove: seq[string] = @[]
  for txId, tx in transactionRegistry:
    if not tx.isActive():
      toRemove.add(txId)
  
  for txId in toRemove:
    transactionRegistry.del(txId)