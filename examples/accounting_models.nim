import ../src/prologue/db/bormin/models
import std/asyncdispatch, std/strutils

# Примерни модели за счетоводна програма с подобрения Bormin ORM

proc createAccountingModels*() =
  ## Създава модели за счетоводна програма
  echo "Creating accounting models with enhanced Bormin ORM..."
  
  # Модел за сметкоплан (Chart of Accounts)
  let accountModel = newModelBuilder("accounts")
  discard accountModel.column("id", dbInt).primaryKey()
  discard accountModel.column("code", dbVarchar).notNull().unique()
    .check("LENGTH(code) >= 4 AND LENGTH(code) <= 10")  # Бизнес правило за кода
  discard accountModel.column("name", dbVarchar).notNull()
  discard accountModel.column("account_type", dbVarchar).notNull()
    .check("account_type IN ('asset', 'liability', 'equity', 'income', 'expense')")
  discard accountModel.column("parent_id", dbInt).foreignKey("accounts", "id")
  discard accountModel.column("balance", dbDecimal, 15, 2).notNull().default("0.00")
    .check("balance IS NOT NULL")  # Финансови суми с точност
  discard accountModel.column("is_active", dbBool).notNull().default("true")
  discard accountModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  discard accountModel.column("updated_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  accountModel.build()
  
  # Модел за транзакции (Financial Transactions)
  let transactionModel = newModelBuilder("transactions")
  discard transactionModel.column("id", dbInt).primaryKey()
  discard transactionModel.column("transaction_number", dbVarchar).notNull().unique()
  discard transactionModel.column("date", dbTimestamp).notNull()
  discard transactionModel.column("description", dbVarchar).notNull()
  discard transactionModel.column("reference", dbVarchar)
  discard transactionModel.column("total_amount", dbDecimal, 15, 2).notNull()
    .check("total_amount > 0")  # Бизнес правило - сумата трябва да е положителна
  discard transactionModel.column("status", dbVarchar).notNull().default("'pending'")
    .check("status IN ('pending', 'approved', 'posted', 'cancelled')")
  discard transactionModel.column("created_by", dbInt).notNull()
  discard transactionModel.column("approved_by", dbInt)
  discard transactionModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  discard transactionModel.column("updated_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  transactionModel.build()
  
  # Модел за счетоводни записи (Journal Entries)
  let entryModel = newModelBuilder("entries")
  discard entryModel.column("id", dbInt).primaryKey()
  discard entryModel.column("transaction_id", dbInt).notNull()
    .foreignKey("transactions", "id")
  discard entryModel.column("account_id", dbInt).notNull()
    .foreignKey("accounts", "id")
  discard entryModel.column("debit", dbDecimal, 15, 2).notNull().default("0.00")
    .check("debit >= 0")  # Дебитът не може да е отрицателен
  discard entryModel.column("credit", dbDecimal, 15, 2).notNull().default("0.00")
    .check("credit >= 0")  # Кредитът не може да е отрицателен
  discard entryModel.column("description", dbVarchar)
  discard entryModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  entryModel.build()
  
  # Модел за клиенти (Customers)
  let customerModel = newModelBuilder("customers")
  discard customerModel.column("id", dbInt).primaryKey()
  discard customerModel.column("code", dbVarchar).notNull().unique()
  discard customerModel.column("name", dbVarchar).notNull()
  discard customerModel.column("vat_number", dbVarchar).unique()
    .check("vat_number IS NULL OR LENGTH(vat_number) >= 9")  # ДДС номер валидация
  discard customerModel.column("email", dbVarchar)
    .check("email IS NULL OR email LIKE '%@%.%'")  # Email валидация
  discard customerModel.column("phone", dbVarchar)
  discard customerModel.column("address", dbVarchar)
  discard customerModel.column("credit_limit", dbDecimal, 15, 2).default("0.00")
    .check("credit_limit >= 0")
  discard customerModel.column("balance", dbDecimal, 15, 2).default("0.00")
  discard customerModel.column("is_active", dbBool).notNull().default("true")
  discard customerModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  discard customerModel.column("updated_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  customerModel.build()
  
  # Модел за доставчици (Suppliers)
  let supplierModel = newModelBuilder("suppliers")
  discard supplierModel.column("id", dbInt).primaryKey()
  discard supplierModel.column("code", dbVarchar).notNull().unique()
  discard supplierModel.column("name", dbVarchar).notNull()
  discard supplierModel.column("vat_number", dbVarchar).unique()
    .check("vat_number IS NULL OR LENGTH(vat_number) >= 9")
  discard supplierModel.column("email", dbVarchar)
    .check("email IS NULL OR email LIKE '%@%.%'")
  discard supplierModel.column("phone", dbVarchar)
  discard supplierModel.column("address", dbVarchar)
  discard supplierModel.column("payment_terms", dbInt).default("30")
    .check("payment_terms > 0 AND payment_terms <= 365")  # Срок на плащане 1-365 дни
  discard supplierModel.column("balance", dbDecimal, 15, 2).default("0.00")
  discard supplierModel.column("is_active", dbBool).notNull().default("true")
  discard supplierModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  discard supplierModel.column("updated_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  supplierModel.build()
  
  # Модел за фактури (Invoices)
  let invoiceModel = newModelBuilder("invoices")
  discard invoiceModel.column("id", dbInt).primaryKey()
  discard invoiceModel.column("invoice_number", dbVarchar).notNull().unique()
  discard invoiceModel.column("customer_id", dbInt).notNull()
    .foreignKey("customers", "id")
  discard invoiceModel.column("supplier_id", dbInt)
    .foreignKey("suppliers", "id")
  discard invoiceModel.column("invoice_date", dbTimestamp).notNull()
  discard invoiceModel.column("due_date", dbTimestamp).notNull()
  discard invoiceModel.column("subtotal", dbDecimal, 15, 2).notNull()
    .check("subtotal >= 0")
  discard invoiceModel.column("vat_amount", dbDecimal, 15, 2).notNull().default("0.00")
    .check("vat_amount >= 0")
  discard invoiceModel.column("total_amount", dbDecimal, 15, 2).notNull()
    .check("total_amount >= subtotal")  # Общата сума >= подсума
  discard invoiceModel.column("paid_amount", dbDecimal, 15, 2).default("0.00")
    .check("paid_amount >= 0 AND paid_amount <= total_amount")
  discard invoiceModel.column("status", dbVarchar).notNull().default("'draft'")
    .check("status IN ('draft', 'sent', 'paid', 'overdue', 'cancelled')")
  discard invoiceModel.column("payment_method", dbVarchar)
    .check("payment_method IS NULL OR payment_method IN ('cash', 'bank', 'card', 'check')")
  discard invoiceModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  discard invoiceModel.column("updated_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  invoiceModel.build()
  
  # Модел за audit trail (одит следа)
  let auditModel = newModelBuilder("audit_log")
  discard auditModel.column("id", dbInt).primaryKey()
  discard auditModel.column("table_name", dbVarchar).notNull()
  discard auditModel.column("record_id", dbInt).notNull()
  discard auditModel.column("operation", dbVarchar).notNull()
    .check("operation IN ('INSERT', 'UPDATE', 'DELETE')")
  discard auditModel.column("old_values", dbText)  # JSON със стари стойности
  discard auditModel.column("new_values", dbText)  # JSON с нови стойности
  discard auditModel.column("user_id", dbInt).notNull()
  discard auditModel.column("user_ip", dbVarchar)
  discard auditModel.column("created_at", dbTimestamp).default("CURRENT_TIMESTAMP")
  auditModel.build()
  
  echo "✅ All accounting models created successfully!"
  echo ""
  echo "Models created:"
  echo "  📊 accounts - Chart of accounts with decimal balance"
  echo "  💰 transactions - Financial transactions with ACID support"
  echo "  📝 entries - Double-entry journal entries"
  echo "  👤 customers - Customer management with credit limits"
  echo "  🏢 suppliers - Supplier management with payment terms"
  echo "  📄 invoices - Invoice management with payment tracking"
  echo "  🔍 audit_log - Complete audit trail for compliance"
  echo ""
  echo "Enhanced features:"
  echo "  ✅ DECIMAL types for precise financial calculations"
  echo "  ✅ CHECK constraints for business rule enforcement"
  echo "  ✅ UNIQUE constraints for data integrity"
  echo "  ✅ Foreign keys for relational integrity"
  echo "  ✅ Default values and timestamps"
  echo "  ✅ Ready for ACID transactions"

# Пример за използване на транзакции
proc demonstrateTransaction*() {.async.} =
  ## Демонстрира използването на ACID транзакции
  echo "\n🔄 Demonstrating ACID transaction..."
  
  # Simulate database connection
  let conn = DbConn()
  
  try:
    # Manual transaction management
    let transaction = await beginTransaction(conn, ilReadCommitted)
    
    try:
      # Създаване на счетоводна проводка
      await createAccountingEntry(transaction, "1100", "2100", "1000.00", 
                                 "Payment from customer ABC", "INV-001")
      
      # Проверка на баланса
      let isBalanced = await validateAccountingBalance(transaction)
      if not isBalanced:
        raise newException(TransactionError, "Accounting entries are not balanced!")
      
      await transaction.commit()
      echo "✅ Transaction completed successfully"
    except Exception as e:
      await transaction.rollback()
      raise e
      
  except TransactionError as e:
    echo "❌ Transaction failed: ", e.msg
  except Exception as e:
    echo "❌ Unexpected error: ", e.msg

when isMainModule:
  # Създаване на моделите
  createAccountingModels()
  
  # Генериране на SQL
  echo "\n📝 Generated SQL:"
  echo repeat("=", 50)
  echo generateSql(modelRegistry)
  
  # Демонстрация на транзакция (само симулация)
  echo "\n🔄 Transaction demonstration:"
  echo repeat("=", 50)
  echo "Note: This is a simulation - actual database connection needed for real transactions"