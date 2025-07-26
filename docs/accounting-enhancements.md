# Подобрения за счетоводна програма

Този документ описва подобренията направени в z-prologue за поддръжка на счетоводни системи с фокус върху GraphQL API и Bormin ORM.

## Съдържание

1. [Преглед](#преглед)
2. [Bormin ORM подобрения](#bormin-orm-подобрения)
3. [GraphQL подобрения](#graphql-подобрения)
4. [Примери за използване](#примери-за-използване)
5. [Архитектура](#архитектура)

---

## Преглед

Разширихме z-prologue с мощни възможности за създаване на професионални счетоводни системи:

- **Финансови типове данни** - DECIMAL поддръжка за точни парични изчисления
- **ACID транзакции** - пълна транзакционна поддръжка с изолационни нива
- **Business rules валидации** - CHECK и UNIQUE constraints за бизнес логика
- **GraphQL API** - специализирано API за счетоводни операции
- **Real-time обновления** - WebSocket subscriptions за live данни

---

## Bormin ORM подобрения

### 1. Финансови типове данни

Добавени нови типове за точни финансови изчисления:

```nim
type
  DbTypeKind* = enum
    dbInt, dbFloat, dbVarchar, dbFixedChar, dbBool, dbTimestamp, 
    dbDateTime, dbText, dbDecimal, dbNumeric, dbMoney
```

#### DECIMAL типове с точност и мащаб

```nim
# Модел със DECIMAL колона
let accountModel = newModelBuilder("accounts")
discard accountModel.column("balance", dbDecimal, 15, 2)  # DECIMAL(15,2)
  .notNull().default("0.00")
```

#### Генерирано SQL

```sql
CREATE TABLE accounts(
  balance DECIMAL(15,2) NOT NULL DEFAULT 0.00
);
```

### 2. ACID транзакции

Пълна поддръжка за транзакции с различни изолационни нива:

```nim
# Създаване на транзакция
let transaction = await beginTransaction(conn, ilReadCommitted)

try:
  # Изпълнение на операции
  await transaction.execInTransaction(sql, params)
  await transaction.commit()
except Exception:
  await transaction.rollback()
  raise
```

#### Изолационни нива

```nim
type
  IsolationLevel* = enum
    ilReadUncommitted = "READ UNCOMMITTED"
    ilReadCommitted = "READ COMMITTED" 
    ilRepeatableRead = "REPEATABLE READ"
    ilSerializable = "SERIALIZABLE"
```

### 3. Constraints и валидации

#### CHECK constraints за бизнес правила

```nim
# Проверка за положителни суми
discard accountModel.column("balance", dbDecimal, 15, 2)
  .check("balance >= 0")

# Валидация на статус
discard transactionModel.column("status", dbVarchar)
  .check("status IN ('pending', 'approved', 'posted', 'cancelled')")
```

#### UNIQUE constraints

```nim
# Уникален код на сметка
discard accountModel.column("code", dbVarchar)
  .notNull().unique()
```

### 4. Счетоводни модели

Създадени готови модели за пълноценна счетоводна система:

#### Сметкоплан (Chart of Accounts)
```nim
# accounts таблица
- id (PRIMARY KEY)
- code (UNIQUE, VARCHAR) 
- name (VARCHAR)
- account_type (CHECK constraint)
- parent_id (FOREIGN KEY)
- balance (DECIMAL(15,2))
- is_active (BOOLEAN)
- created_at, updated_at (TIMESTAMP)
```

#### Транзакции
```nim
# transactions таблица  
- id (PRIMARY KEY)
- transaction_number (UNIQUE)
- date (TIMESTAMP)
- description (VARCHAR)
- total_amount (DECIMAL(15,2))
- status (CHECK constraint)
- created_by, approved_by (INTEGER)
```

#### Счетоводни записи
```nim
# entries таблица
- id (PRIMARY KEY)
- transaction_id (FOREIGN KEY)
- account_id (FOREIGN KEY) 
- debit (DECIMAL(15,2))
- credit (DECIMAL(15,2))
- description (VARCHAR)
```

### 5. Специализирани функции

#### Двойна проводка
```nim
proc createAccountingEntry*(transaction: Transaction, 
                           debitAccount: string, creditAccount: string,
                           amount: string, description: string): Future[void] {.async.}
```

#### Валидация на баланс
```nim
proc validateAccountingBalance*(transaction: Transaction): Future[bool] {.async.}
```

---

## GraphQL подобрения

### 1. Финансови типове

Специализирани GraphQL типове за счетоводни операции:

```nim
type
  Money* = object
    amount*: string  # String за точност
    currency*: string
    
  Account* = object
    id*: int
    code*: string
    name*: string
    accountType*: AccountType
    balance*: Money
    
  Transaction* = object
    id*: int
    transactionNumber*: string
    totalAmount*: Money
    status*: TransactionStatus
    entries*: seq[Entry]
```

### 2. GraphQL Schema за счетоводни операции

#### Query операции
```graphql
type Query {
  # Управление на сметки
  account(id: ID, code: String): Account
  accounts(first: Int, accountType: AccountType): AccountConnection!
  chartOfAccounts: [Account!]!
  
  # Транзакции
  transaction(id: ID!): Transaction
  transactions(first: Int, status: TransactionStatus): TransactionConnection!
  
  # Отчети
  trialBalance(asOfDate: String!): TrialBalance!
  balanceSheet(asOfDate: String!): BalanceSheet!
  incomeStatement(fromDate: String!, toDate: String!): IncomeStatement!
}
```

#### Mutation операции
```graphql
type Mutation {
  # Сметки
  createAccount(input: CreateAccountInput!): Account!
  updateAccount(id: ID!, input: UpdateAccountInput!): Account!
  
  # Транзакции
  createTransaction(input: CreateTransactionInput!): Transaction!
  approveTransaction(id: ID!): Transaction!
  postTransaction(id: ID!): Transaction!
  
  # Фактури
  createInvoice(input: CreateInvoiceInput!): Invoice!
  markInvoicePaid(id: ID!, amount: String!, paymentMethod: PaymentMethod!): Invoice!
}
```

#### Subscription операции
```graphql
type Subscription {
  transactionUpdated(userId: ID!): Transaction!
  invoiceStatusChanged(customerId: ID): Invoice!
  accountBalanceChanged(accountId: ID!): Account!
}
```

### 3. Специализирани resolvers

#### Сметки
```nim
proc resolveAccount*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
proc resolveAccounts*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
proc resolveCreateAccount*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
```

#### Транзакции
```nim
proc resolveTransaction*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
proc resolveCreateTransaction*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
```

#### Отчети
```nim
proc resolveTrialBalance*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
```

### 4. Валидации и бизнес логика

#### Финансови валидации
```nim
proc validateAmount*(amount: string): bool
proc validateAccountCode*(code: string): bool  
proc validateVatNumber*(vatNumber: string): bool
```

#### Money операции
```nim
proc addMoney*(a, b: Money): Money
proc subtractMoney*(a, b: Money): Money
proc compareMoney*(a, b: Money): int
```

### 5. Rate limiting и сигурност

#### Query complexity analysis
```nim
const MAX_QUERY_COMPLEXITY = 100

proc calculateQueryComplexity*(query: string): int
proc validateQueryComplexity*(query: string): bool
```

#### Сложност на операции
- Основни queries: 1-5 точки
- Mutations: 5-10 точки  
- Финансови отчети: 20 точки
- Connections/pagination: 3-5 точки

### 6. Real-time subscriptions

#### WebSocket поддръжка
```nim
proc subscribeTransactionUpdated*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.}
proc notifyTransactionUpdate*(userId: string, transaction: JsonNode)
```

### 7. GraphQL Playground

Специализиран интерфейс за разработка с примерни заявки:

```javascript
// Endpoint: /accounting/graphql
// Playground: /accounting/playground

// Примерни заявки
query GetAccount {
  account(code: "1100") {
    id, code, name, accountType
    balance { amount, currency }
  }
}

mutation CreateTransaction {
  createTransaction(input: {
    description: "Покупка материали"
    totalAmount: "1000.00"
    entries: [...]
  }) {
    id, transactionNumber, status
  }
}
```

---

## Примери за използване

### 1. Основна настройка

```nim
import prologue
import prologue/db/bormin/models
import graphql

# Настройка на ORM
let conn = open("accounting.db", "", "", "")

# Създаване на модели
createAccountingModels()

# GraphQL сървър
let app = newApp()
app.use(accountingGraphqlCorsMiddleware())
app.post("/accounting/graphql", accountingGraphqlHandler)
app.get("/accounting/playground", accountingGraphqlPlaygroundHandler)

app.run()
```

### 2. Създаване на сметка

```graphql
mutation CreateAccount {
  createAccount(input: {
    code: "1500"
    name: "Материали"
    accountType: ASSET
  }) {
    id
    code
    name
    balance {
      amount
      currency
    }
  }
}
```

### 3. Създаване на транзакция

```graphql
mutation CreateTransaction {
  createTransaction(input: {
    description: "Покупка материали"
    totalAmount: "1000.00"
    reference: "INV-123"
    entries: [
      {
        accountId: 1
        debit: "1000.00"
        credit: "0.00"
        description: "Материали"
      },
      {
        accountId: 2
        debit: "0.00" 
        credit: "1000.00"
        description: "Плащане в брой"
      }
    ]
  }) {
    id
    transactionNumber
    status
    entries {
      accountId
      debit { amount, currency }
      credit { amount, currency }
    }
  }
}
```

### 4. Оборотна ведомост

```graphql
query TrialBalance {
  trialBalance(asOfDate: "2024-12-31") {
    asOfDate
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

### 5. Real-time обновления

```graphql
subscription TransactionUpdates {
  transactionUpdated(userId: "1") {
    id
    transactionNumber
    status
    totalAmount { amount, currency }
  }
}
```

---

## Архитектура

### Слоеве на системата

```
┌─────────────────────────────────────┐
│           Frontend App              │
│     (React/Vue/Angular)            │
└─────────────────────────────────────┘
                  │
                  │ GraphQL over HTTP/WebSocket
                  ▼
┌─────────────────────────────────────┐
│         GraphQL Layer               │
│  • Resolvers                       │
│  • Rate limiting                   │
│  • Subscriptions                   │
│  • Validation                      │
└─────────────────────────────────────┘
                  │
                  │ Function calls
                  ▼
┌─────────────────────────────────────┐
│        Business Logic               │
│  • Accounting rules                │
│  • Validation logic                │
│  • Calculations                    │
└─────────────────────────────────────┘
                  │
                  │ ORM calls
                  ▼
┌─────────────────────────────────────┐
│         Bormin ORM                  │
│  • Models & Migrations             │
│  • ACID Transactions               │
│  • Constraints                     │
└─────────────────────────────────────┘
                  │
                  │ SQL
                  ▼
┌─────────────────────────────────────┐
│          Database                   │
│  • PostgreSQL/SQLite               │
│  • Financial data                  │
│  • Audit logs                      │
└─────────────────────────────────────┘
```

### Основни компоненти

1. **GraphQL API слой**
   - Тип-безопасни заявки
   - Автоматично генерирана документация
   - Единична endpoint архитектура

2. **Bormin ORM слой**  
   - DECIMAL подтъжка за финанси
   - ACID транзакции
   - Constraint валидации

3. **Business Logic слой**
   - Счетоводни правила
   - Двойна проводка  
   - Финансови изчисления

4. **Database слой**
   - Нормализирана структура
   - Foreign key integrity
   - Audit trail support

### Performance оптимизации

- **Query complexity limiting** - предотвратява скъпи заявки
- **Connection pooling** - ефективно използване на database връзки  
- **Lazy loading** - зареждане на данни при нужда
- **Caching** - кеширане на често използвани данни

### Сигурност

- **Input validation** - всички входни данни се валидират
- **SQL injection protection** - parameterized queries
- **Rate limiting** - защита от abuse
- **Authentication/Authorization** - JWT токен базирана автентификация

---

## Заключение

Подобренията в z-prologue осигуряват пълноценна платформа за създаване на професионални счетоводни системи. Комбинацията от типово-безопасен GraphQL API и мощен Bormin ORM с финансова специализация прави платформата подходяща за production използване в счетоводни фирми и предприятия.

**Ключови предимства:**

✅ **Точност** - DECIMAL типове за финансови данни  
✅ **Надеждност** - ACID транзакции и constraints  
✅ **Производителност** - Rate limiting и query optimization  
✅ **Гъвкавост** - GraphQL schema и real-time subscriptions  
✅ **Сигурност** - Input validation и business rules  
✅ **Мащабируемост** - Connection pooling и caching

Платформата е готова за използване в production среда за създаване на модерни, мащабируеми счетоводни системи.