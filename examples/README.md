# Примери за z-prologue

Този директория съдържа примери за използване на z-prologue с фокус върху счетоводни системи.

## Файлове

### 📋 accounting_models.nim
Демонстрира подобрения Bormin ORM за счетоводни програми:

- **Финансови типове** - DECIMAL(15,2) за точни парични суми
- **ACID транзакции** - пълна транзакционна поддръжка  
- **Business rules** - CHECK и UNIQUE constraints
- **Счетоводни модели** - accounts, transactions, entries, customers, invoices
- **Audit trail** - пълен одит лог

**Стартиране:**
```bash
nim r examples/accounting_models.nim
```

**Резултат:**
- Създава 7 модела за пълноценна счетоводна система
- Генерира SQL с constraints и relationships
- Демонстрира ACID транзакции (симулация)

### 🚀 accounting_graphql_server.nim
Работещ GraphQL сървър за счетоводни операции:

- **Типово-безопасно API** - GraphQL schema за финансови данни
- **Relay-style пагинация** - Connection/Edge pattern
- **Финансови resolvers** - accounts, transactions, trial balance
- **Валидации** - бизнес правила и constraint проверки
- **Real-time поддръжка** - subscription система (демо)

**Стартиране:**
```bash
nim r examples/accounting_graphql_server.nim
```

**Функционалности:**
- ✅ Получаване на сметки по ID/код
- ✅ Списък със сметки с пагинация
- ✅ Оборотна ведомост с правилни дебити/кредити
- ✅ Финансови изчисления с точност

## Ключови характеристики

### 💰 Финансова точност
- String представяне на суми (не float)
- DECIMAL типове в базата данни
- Точни математически операции

### 🔒 ACID транзакции
```nim
let transaction = await beginTransaction(conn, ilReadCommitted)
try:
  await createAccountingEntry(transaction, "1100", "2100", "1000.00", "Плащане")
  await transaction.commit()
except:
  await transaction.rollback()
```

### 📊 GraphQL заявки
```graphql
query {
  trialBalance(asOfDate: "2024-12-31") {
    accounts {
      accountCode
      accountName
      debitBalance { amount, currency }
      creditBalance { amount, currency }
    }
    totalDebits { amount, currency }
    totalCredits { amount, currency }
    isBalanced
  }
}
```

### 🛡️ Бизнес правила
```sql
-- Генерирано SQL с constraints
CREATE TABLE accounts(
  balance DECIMAL(15,2) NOT NULL DEFAULT 0.00 CHECK (balance >= 0),
  code VARCHAR(255) NOT NULL UNIQUE CHECK (LENGTH(code) >= 4 AND LENGTH(code) <= 10),
  account_type VARCHAR(255) CHECK (account_type IN ('asset', 'liability', 'equity', 'income', 'expense'))
);
```

## Следващи стъпки

За production използване добавете:

1. **База данни** - PostgreSQL или MySQL с реални връзки
2. **Автентификация** - JWT токен система  
3. **Authorization** - role-based permissions
4. **Audit log** - пълен одит trail
5. **Backup/Restore** - автоматични backup процедури
6. **Performance** - indexing и query optimization

## Архитектура

```
Frontend (React/Vue) 
    ↓ GraphQL
GraphQL Layer (resolvers, validation)
    ↓ Function calls  
Business Logic (accounting rules)
    ↓ ORM calls
Bormin ORM (models, transactions)
    ↓ SQL
Database (PostgreSQL/SQLite)
```

## Документация

За пълна документация вижте:
- [docs/accounting-enhancements.md](../docs/accounting-enhancements.md) - пълно техническо описание
- [docs-bg/accounting-enhancements.md](../docs-bg/accounting-enhancements.md) - българска документация
- [docs/graphql.md](../docs/graphql.md) - GraphQL документация

---

**z-prologue** - мощна платформа за модерни счетоводни системи! 🎉