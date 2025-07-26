# Подобрения за счетоводна програма

Този документ описва подобренията направени в z-prologue за поддръжка на счетоводни системи.

## Кратък преглед

### Борmin ORM подобрения

**1. Финансови типове данни**
- Добавени `dbDecimal`, `dbNumeric`, `dbMoney` типове
- Поддръжка за точност и мащаб (DECIMAL(15,2))
- String представяне за точни финансови изчисления

**2. ACID транзакции**
- `beginTransaction()` с изолационни нива
- `commit()` и `rollback()` функции  
- `withTransaction` template за автоматично управление
- Поддръжка за nested transactions

**3. Constraints и валидации**
- CHECK constraints за бизнес правила
- UNIQUE constraints за интегритет
- Foreign key връзки
- Default стойности и timestamps

**4. Счетоводни модели**
- accounts (сметкоплан)
- transactions (транзакции)
- entries (счетоводни записи)
- customers (клиенти)
- suppliers (доставчици)
- invoices (фактури)
- audit_log (одит следа)

### GraphQL подобрения

**1. Финансови типове**
- `Money` обект за парични суми
- `Account`, `Transaction`, `Entry` модели
- Енумерации за статуси и типове

**2. Специализирани resolvers**
- `resolveAccount` - сметки по ID/код
- `resolveAccounts` - списък с пагинация
- `resolveTrialBalance` - оборотна ведомост
- `resolveCreateAccount` - създаване на сметка
- `resolveCreateTransaction` - създаване на транзакция

**3. Rate limiting**
- Query complexity анализ
- MAX_QUERY_COMPLEXITY ограничение
- Защита от сложни заявки

**4. Real-time subscriptions**
- WebSocket поддръжка
- Live обновления за транзакции
- Notification система

**5. GraphQL Playground**
- Специализиран интерфейс
- Примерни заявки за счетоводни операции
- CORS middleware

## Файлове

### Основни файлове
- `src/prologue/db/bormin/models.nim` - подобрен ORM
- `src/graphql.nim` - подобрен GraphQL модул
- `examples/accounting_models.nim` - примерни модели
- `examples/accounting_graphql_server.nim` - работещ пример

### Документация
- `docs/accounting-enhancements.md` - пълна документация (английски)
- `docs-bg/accounting-enhancements.md` - този файл (български)

## Примери за използване

### ORM модели
```nim
# Създаване на сметка с DECIMAL баланс
let accountModel = newModelBuilder("accounts")
discard accountModel.column("balance", dbDecimal, 15, 2)
  .notNull().default("0.00")
  .check("balance >= 0")
```

### GraphQL заявки
```graphql
# Получаване на сметка
query {
  account(code: "1100") {
    id, code, name
    balance { amount, currency }
  }
}

# Оборотна ведомост
query {
  trialBalance(asOfDate: "2024-12-31") {
    accounts {
      accountCode, accountName
      debitBalance { amount }
      creditBalance { amount }
    }
    isBalanced
  }
}
```

### ACID транзакции
```nim
let transaction = await beginTransaction(conn, ilReadCommitted)
try:
  await createAccountingEntry(transaction, "1100", "2100", "1000.00", "Плащане")
  let isBalanced = await validateAccountingBalance(transaction)
  if isBalanced:
    await transaction.commit()
  else:
    await transaction.rollback()
except:
  await transaction.rollback()
```

## Резултати

✅ **Финансова точност** - DECIMAL типове вместо FLOAT  
✅ **ACID транзакции** - пълна транзакционна поддръжка  
✅ **Бизнес правила** - CHECK constraints за валидации  
✅ **GraphQL API** - типово-безопасно API за счетоводни операции  
✅ **Real-time** - WebSocket subscriptions за live обновления  
✅ **Rate limiting** - защита от злоупотреба  
✅ **Готови модели** - пълен комплект за счетоводна система  

Платформата е готова за production използване в счетоводни програми.