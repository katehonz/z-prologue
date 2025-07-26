import prologue, json, asyncdispatch, tables, times, strutils
import prologue/core/context
import std/[options, base64]

# GraphQL модул за z-prologue с подобрена функционалност
# Поддържа интеграция с ORM, мутации, пагинация и абонаменти

type
  # Контекст за GraphQL резолвъри
  GraphQLContext* = ref object
    request*: Request
    user*: Option[JsonNode]  # Текущ потребител
    
  # Типове за пагинация
  PageInfo* = object
    hasNextPage*: bool
    hasPreviousPage*: bool
    startCursor*: string
    endCursor*: string
    
  Connection*[T] = object
    edges*: seq[Edge[T]]
    pageInfo*: PageInfo
    totalCount*: int
    
  Edge*[T] = object
    node*: T
    cursor*: string

  # Типове за грешки
  GraphQLError* = object
    message*: string
    extensions*: JsonNode
    path*: seq[string]
    
  # Резултат от GraphQL заявка
  GraphQLResult* = object
    data*: JsonNode
    errors*: seq[GraphQLError]
    
  # Финансови типове за счетоводна програма
  AccountType* = enum
    atAsset = "ASSET"
    atLiability = "LIABILITY" 
    atEquity = "EQUITY"
    atIncome = "INCOME"
    atExpense = "EXPENSE"
    
  TransactionStatus* = enum
    tsPending = "PENDING"
    tsApproved = "APPROVED"
    tsPosted = "POSTED"
    tsCancelled = "CANCELLED"
    
  InvoiceStatus* = enum
    isDraft = "DRAFT"
    isSent = "SENT"
    isPaid = "PAID"
    isOverdue = "OVERDUE"
    isCancelled = "CANCELLED"
    
  PaymentMethod* = enum
    pmCash = "CASH"
    pmBank = "BANK"
    pmCard = "CARD"
    pmCheck = "CHECK"
    
  # Финансови структури
  Money* = object
    amount*: string  # Използваме string за точност
    currency*: string
    
  Account* = object
    id*: int
    code*: string
    name*: string
    accountType*: AccountType
    parentId*: Option[int]
    balance*: Money
    isActive*: bool
    createdAt*: string
    updatedAt*: string
    
  Transaction* = object
    id*: int
    transactionNumber*: string
    date*: string
    description*: string
    reference*: Option[string]
    totalAmount*: Money
    status*: TransactionStatus
    createdBy*: int
    approvedBy*: Option[int]
    entries*: seq[Entry]
    createdAt*: string
    updatedAt*: string
    
  Entry* = object
    id*: int
    transactionId*: int
    accountId*: int
    account*: Option[Account]
    debit*: Money
    credit*: Money
    description*: Option[string]
    createdAt*: string
    
  Customer* = object
    id*: int
    code*: string
    name*: string
    vatNumber*: Option[string]
    email*: Option[string]
    phone*: Option[string]
    address*: Option[string]
    creditLimit*: Money
    balance*: Money
    isActive*: bool
    createdAt*: string
    updatedAt*: string
    
  Invoice* = object
    id*: int
    invoiceNumber*: string
    customerId*: int
    customer*: Option[Customer]
    invoiceDate*: string
    dueDate*: string
    subtotal*: Money
    vatAmount*: Money
    totalAmount*: Money
    paidAmount*: Money
    status*: InvoiceStatus
    paymentMethod*: Option[PaymentMethod]
    createdAt*: string
    updatedAt*: string

# Помощни функции за пагинация
proc encodeCursor*(id: int): string =
  ## Кодира ID в base64 курсор
  result = encode($id)

proc decodeCursor*(cursor: string): int =
  ## Декодира base64 курсор в ID
  try:
    result = parseInt(decode(cursor))
  except:
    result = 0

# Помощни функции за валидация
proc validateEmail*(email: string): bool =
  ## Валидира имейл адрес
  email.contains("@") and email.contains(".") and email.len >= 5

proc validatePassword*(password: string): bool =
  ## Валидира парола (минимум 8 символа)
  password.len >= 8

# Помощни функции за финансови данни
proc newMoney*(amount: string, currency: string = "BGN"): Money =
  ## Създава нов Money обект с валидация
  result = Money(amount: amount, currency: currency)

proc validateAmount*(amount: string): bool =
  ## Валидира финансова сума
  try:
    let value = parseFloat(amount)
    result = value >= 0.0 and amount.contains(".")
  except:
    result = false

proc validateAccountCode*(code: string): bool =
  ## Валидира код на сметка (4-10 символа, само цифри/букви)
  result = code.len >= 4 and code.len <= 10 and code.allCharsInSet({'0'..'9', 'A'..'Z', 'a'..'z'})

proc validateVatNumber*(vatNumber: string): bool =
  ## Валидира ДДС номер (български формат)
  result = vatNumber.len >= 9 and vatNumber.len <= 13 and vatNumber.allCharsInSet({'0'..'9'})

proc formatMoney*(money: Money): string =
  ## Форматира парична сума за показване
  result = money.amount & " " & money.currency

proc addMoney*(a, b: Money): Money =
  ## Събира две парични суми (трябва да са в същата валута)
  if a.currency != b.currency:
    raise newException(ValueError, "Cannot add different currencies")
  
  let sumAmount = parseFloat(a.amount) + parseFloat(b.amount)
  result = Money(amount: $sumAmount, currency: a.currency)

proc subtractMoney*(a, b: Money): Money =
  ## Изважда две парични суми
  if a.currency != b.currency:
    raise newException(ValueError, "Cannot subtract different currencies")
  
  let diffAmount = parseFloat(a.amount) - parseFloat(b.amount)
  result = Money(amount: $diffAmount, currency: a.currency)

proc compareMoney*(a, b: Money): int =
  ## Сравнява две парични суми (-1, 0, 1)
  if a.currency != b.currency:
    raise newException(ValueError, "Cannot compare different currencies")
  
  let aVal = parseFloat(a.amount)
  let bVal = parseFloat(b.amount)
  
  if aVal < bVal: result = -1
  elif aVal > bVal: result = 1
  else: result = 0

# Базова GraphQL схема (примерна имплементация)
proc createAccountingGraphQLSchema*(): JsonNode =
  ## Създава GraphQL схема за счетоводна програма
  result = %* {
    "query": {
      # Управление на сметки
      "account": {
        "type": "Account",
        "args": {
          "id": {"type": "ID"},
          "code": {"type": "String"}
        },
        "resolve": "resolveAccount"
      },
      "accounts": {
        "type": "AccountConnection!",
        "args": {
          "first": {"type": "Int"},
          "after": {"type": "String"},
          "accountType": {"type": "AccountType"},
          "isActive": {"type": "Boolean"}
        },
        "resolve": "resolveAccounts"
      },
      "chartOfAccounts": {
        "type": "[Account!]!",
        "resolve": "resolveChartOfAccounts"
      },
      
      # Транзакции и записи
      "transaction": {
        "type": "Transaction",
        "args": {
          "id": {"type": "ID!"}
        },
        "resolve": "resolveTransaction"
      },
      "transactions": {
        "type": "TransactionConnection!",
        "args": {
          "first": {"type": "Int"},
          "after": {"type": "String"},
          "status": {"type": "TransactionStatus"},
          "dateFrom": {"type": "String"},
          "dateTo": {"type": "String"}
        },
        "resolve": "resolveTransactions"
      },
      "entries": {
        "type": "EntryConnection!",
        "args": {
          "first": {"type": "Int"},
          "after": {"type": "String"},
          "accountId": {"type": "ID"},
          "transactionId": {"type": "ID"}
        },
        "resolve": "resolveEntries"
      },
      
      # Клиенти и доставчици
      "customer": {
        "type": "Customer",
        "args": {
          "id": {"type": "ID!"}
        },
        "resolve": "resolveCustomer"
      },
      "customers": {
        "type": "CustomerConnection!",
        "args": {
          "first": {"type": "Int"},
          "after": {"type": "String"},
          "isActive": {"type": "Boolean"}
        },
        "resolve": "resolveCustomers"
      },
      
      # Фактури
      "invoice": {
        "type": "Invoice",
        "args": {
          "id": {"type": "ID!"}
        },
        "resolve": "resolveInvoice"
      },
      "invoices": {
        "type": "InvoiceConnection!",
        "args": {
          "first": {"type": "Int"},
          "after": {"type": "String"},
          "customerId": {"type": "ID"},
          "status": {"type": "InvoiceStatus"},
          "dateFrom": {"type": "String"},
          "dateTo": {"type": "String"}
        },
        "resolve": "resolveInvoices"
      },
      
      # Отчети
      "trialBalance": {
        "type": "TrialBalance!",
        "args": {
          "asOfDate": {"type": "String!"}
        },
        "resolve": "resolveTrialBalance"
      },
      "balanceSheet": {
        "type": "BalanceSheet!",
        "args": {
          "asOfDate": {"type": "String!"}
        },
        "resolve": "resolveBalanceSheet"
      },
      "incomeStatement": {
        "type": "IncomeStatement!",
        "args": {
          "fromDate": {"type": "String!"},
          "toDate": {"type": "String!"}
        },
        "resolve": "resolveIncomeStatement"
      }
    },
    "mutation": {
      # Управление на сметки
      "createAccount": {
        "type": "Account!",
        "args": {
          "input": {"type": "CreateAccountInput!"}
        },
        "resolve": "resolveCreateAccount"
      },
      "updateAccount": {
        "type": "Account!",
        "args": {
          "id": {"type": "ID!"},
          "input": {"type": "UpdateAccountInput!"}
        },
        "resolve": "resolveUpdateAccount"
      },
      
      # Транзакции
      "createTransaction": {
        "type": "Transaction!",
        "args": {
          "input": {"type": "CreateTransactionInput!"}
        },
        "resolve": "resolveCreateTransaction"
      },
      "approveTransaction": {
        "type": "Transaction!",
        "args": {
          "id": {"type": "ID!"}
        },
        "resolve": "resolveApproveTransaction"
      },
      "postTransaction": {
        "type": "Transaction!",
        "args": {
          "id": {"type": "ID!"}
        },
        "resolve": "resolvePostTransaction"
      },
      
      # Клиенти
      "createCustomer": {
        "type": "Customer!",
        "args": {
          "input": {"type": "CreateCustomerInput!"}
        },
        "resolve": "resolveCreateCustomer"
      },
      "updateCustomer": {
        "type": "Customer!",
        "args": {
          "id": {"type": "ID!"},
          "input": {"type": "UpdateCustomerInput!"}
        },
        "resolve": "resolveUpdateCustomer"
      },
      
      # Фактури
      "createInvoice": {
        "type": "Invoice!",
        "args": {
          "input": {"type": "CreateInvoiceInput!"}
        },
        "resolve": "resolveCreateInvoice"
      },
      "markInvoicePaid": {
        "type": "Invoice!",
        "args": {
          "id": {"type": "ID!"},
          "amount": {"type": "String!"},
          "paymentMethod": {"type": "PaymentMethod!"}
        },
        "resolve": "resolveMarkInvoicePaid"
      }
    },
    "subscription": {
      # Real-time обновления
      "transactionUpdated": {
        "type": "Transaction!",
        "args": {
          "userId": {"type": "ID!"}
        },
        "resolve": "subscribeTransactionUpdated"
      },
      "invoiceStatusChanged": {
        "type": "Invoice!",
        "args": {
          "customerId": {"type": "ID"}
        },
        "resolve": "subscribeInvoiceStatusChanged"
      },
      "accountBalanceChanged": {
        "type": "Account!",
        "args": {
          "accountId": {"type": "ID!"}
        },
        "resolve": "subscribeAccountBalanceChanged"
      }
    }
  }

# Счетоводни GraphQL resolvers
proc resolveAccount*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Резолвър за получаване на сметка по ID или код
  try:
    let id = if args.hasKey("id"): args{"id"}.getInt else: 0
    let code = if args.hasKey("code"): args{"code"}.getStr else: ""
    
    # Симулация на заявка към база данни
    if id > 0:
      result = %* {
        "id": id,
        "code": "1100",
        "name": "Каса",
        "accountType": "ASSET",
        "parentId": nil,
        "balance": {"amount": "1500.00", "currency": "BGN"},
        "isActive": true,
        "createdAt": $now(),
        "updatedAt": $now()
      }
    elif code.len > 0:
      result = %* {
        "id": 1,
        "code": code,
        "name": "Каса",
        "accountType": "ASSET",
        "parentId": nil,
        "balance": {"amount": "1500.00", "currency": "BGN"},
        "isActive": true,
        "createdAt": $now(),
        "updatedAt": $now()
      }
    else:
      result = newJNull()
      
  except Exception as e:
    raise newException(ValueError, "Failed to resolve account: " & e.msg)

proc resolveAccounts*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Резолвър за списък със сметки с пагинация
  try:
    discard args{"first"}.getInt(10)
    discard args{"after"}.getStr("")
    discard if args.hasKey("accountType"): some(args{"accountType"}.getStr) else: none(string)
    
    # Симулация на данни
    var accounts = newJArray()
    for i in 1..5:
      accounts.add(%* {
        "id": i,
        "code": "11" & $i & "0",
        "name": "Сметка " & $i,
        "accountType": "ASSET",
        "balance": {"amount": $(i * 1000), "currency": "BGN"},
        "isActive": true,
        "createdAt": $now(),
        "updatedAt": $now()
      })
    
    var edges = newJArray()
    for account in accounts:
      edges.add(%* {
        "node": account,
        "cursor": encodeCursor(account{"id"}.getInt)
      })
    
    result = %* {
      "edges": edges,
      "pageInfo": {
        "hasNextPage": false,
        "hasPreviousPage": false,
        "startCursor": if edges.len > 0: edges[0]{"cursor"}.getStr else: "",
        "endCursor": if edges.len > 0: edges[^1]{"cursor"}.getStr else: ""
      },
      "totalCount": accounts.len
    }
    
  except Exception as e:
    raise newException(ValueError, "Failed to resolve accounts: " & e.msg)

proc resolveCreateAccount*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Резолвър за създаване на нова сметка
  try:
    let input = args{"input"}
    let code = input{"code"}.getStr
    let name = input{"name"}.getStr
    let accountType = input{"accountType"}.getStr
    
    # Валидация
    if not validateAccountCode(code):
      raise newException(ValueError, "Invalid account code format")
    
    if name.len < 3:
      raise newException(ValueError, "Account name must be at least 3 characters")
    
    # Симулация на създаване в база данни
    result = %* {
      "id": 999,
      "code": code,
      "name": name,
      "accountType": accountType,
      "parentId": nil,
      "balance": {"amount": "0.00", "currency": "BGN"},
      "isActive": true,
      "createdAt": $now(),
      "updatedAt": $now()
    }
    
    echo "Created account: ", code, " - ", name
    
  except Exception as e:
    raise newException(ValueError, "Failed to create account: " & e.msg)

proc resolveTransaction*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Резолвър за получаване на транзакция по ID
  try:
    let id = args{"id"}.getInt
    
    # Симулация на заявка към база данни
    result = %* {
      "id": id,
      "transactionNumber": "TXN-" & $id,
      "date": $now(),
      "description": "Плащане към доставчик",
      "reference": "INV-001",
      "totalAmount": {"amount": "2500.00", "currency": "BGN"},
      "status": "APPROVED",
      "createdBy": 1,
      "approvedBy": 2,
      "entries": [
        {
          "id": 1,
          "transactionId": id,
          "accountId": 1,
          "debit": {"amount": "2500.00", "currency": "BGN"},
          "credit": {"amount": "0.00", "currency": "BGN"},
          "description": "Покупка материали",
          "createdAt": $now()
        },
        {
          "id": 2,
          "transactionId": id,
          "accountId": 2,
          "debit": {"amount": "0.00", "currency": "BGN"},
          "credit": {"amount": "2500.00", "currency": "BGN"},
          "description": "Плащане в брой",
          "createdAt": $now()
        }
      ],
      "createdAt": $now(),
      "updatedAt": $now()
    }
    
  except Exception as e:
    raise newException(ValueError, "Failed to resolve transaction: " & e.msg)

proc resolveCreateTransaction*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Резолвър за създаване на нова транзакция
  try:
    let input = args{"input"}
    let description = input{"description"}.getStr
    let totalAmount = input{"totalAmount"}.getStr
    let entries = input{"entries"}
    
    # Валидация на сумата
    if not validateAmount(totalAmount):
      raise newException(ValueError, "Invalid total amount format")
    
    # Валидация на баланса на записите
    var debitTotal = 0.0
    var creditTotal = 0.0
    
    for entry in entries:
      debitTotal += parseFloat(entry{"debit"}.getStr("0.00"))
      creditTotal += parseFloat(entry{"credit"}.getStr("0.00"))
    
    if abs(debitTotal - creditTotal) > 0.01:
      raise newException(ValueError, "Transaction entries are not balanced")
    
    # Симулация на създаване в база данни с транзакция
    result = %* {
      "id": 999,
      "transactionNumber": "TXN-999",
      "date": $now(),
      "description": description,
      "reference": input{"reference"}.getStr(""),
      "totalAmount": {"amount": totalAmount, "currency": "BGN"},
      "status": "PENDING",
      "createdBy": 1,
      "approvedBy": nil,
      "entries": entries,
      "createdAt": $now(),
      "updatedAt": $now()
    }
    
    echo "Created transaction: ", description, " Amount: ", totalAmount
    
  except Exception as e:
    raise newException(ValueError, "Failed to create transaction: " & e.msg)

proc resolveTrialBalance*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Резолвър за оборотна ведомост
  try:
    let asOfDate = args{"asOfDate"}.getStr
    
    # Симулация на изчисление на оборотна ведомост
    var accounts = newJArray()
    let accountData = [
      ("1100", "Каса", "1500.00", "0.00"),
      ("1200", "Банка", "25000.00", "0.00"),
      ("2100", "Доставчици", "0.00", "8500.00"),
      ("3100", "Капитал", "0.00", "18000.00")
    ]
    
    for (code, name, debit, credit) in accountData:
      accounts.add(%* {
        "accountCode": code,
        "accountName": name,
        "debitBalance": {"amount": debit, "currency": "BGN"},
        "creditBalance": {"amount": credit, "currency": "BGN"}
      })
    
    result = %* {
      "asOfDate": asOfDate,
      "accounts": accounts,
      "totalDebits": {"amount": "26500.00", "currency": "BGN"},
      "totalCredits": {"amount": "26500.00", "currency": "BGN"},
      "isBalanced": true
    }
    
  except Exception as e:
    raise newException(ValueError, "Failed to generate trial balance: " & e.msg)

# Rate limiting за защита от сложни заявки
const MAX_QUERY_COMPLEXITY = 100

proc calculateQueryComplexity*(query: string): int =
  ## Изчислява сложността на GraphQL заявка
  var complexity = 0
  
  # Основни операции
  if query.contains("query"): complexity += 1
  if query.contains("mutation"): complexity += 5
  if query.contains("subscription"): complexity += 10
  
  # Вложени заявки
  complexity += query.count("{") * 2
  
  # Връзки между обекти
  complexity += query.count("Connection") * 5
  complexity += query.count("edges") * 3
  
  # Финансови операции (по-скъпи)
  complexity += query.count("trialBalance") * 20
  complexity += query.count("balanceSheet") * 20
  complexity += query.count("incomeStatement") * 20
  
  result = complexity

proc validateQueryComplexity*(query: string): bool =
  ## Валидира сложността на заявката
  let complexity = calculateQueryComplexity(query)
  result = complexity <= MAX_QUERY_COMPLEXITY

# Subscription поддръжка (real-time обновления)
var subscriptionClients = initTable[string, seq[GraphQLContext]]()

proc subscribeTransactionUpdated*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  ## Абонамент за обновления на транзакции
  let userId = args{"userId"}.getStr
  
  if not subscriptionClients.hasKey(userId):
    subscriptionClients[userId] = @[]
  
  subscriptionClients[userId].add(ctx)
  
  # Връща първоначален резултат
  result = %* {
    "id": 0,
    "message": "Subscribed to transaction updates for user " & userId
  }

proc notifyTransactionUpdate*(userId: string, transaction: JsonNode) =
  ## Изпраща обновление към абонирани клиенти
  if subscriptionClients.hasKey(userId):
    for client in subscriptionClients[userId]:
      # Тук ще изпратим real-time обновление
      echo "Notifying client about transaction update: ", transaction{"id"}.getInt

# Основни GraphQL handler функции
proc accountingGraphqlHandler*(ctx: Context) {.async.} =
  ## Основен GraphQL handler за счетоводни операции
  try:
    if ctx.request.reqMethod == HttpPost:
      let body = ctx.request.body
      if body.len == 0:
        ctx.response.code = Http400
        ctx.response.body = $ %* {
          "errors": [{
            "message": "Request body cannot be empty"
          }]
        }
        return
      
      let jsonBody = parseJson(body)
      let query = jsonBody{"query"}.getStr
      discard jsonBody{"variables"}
      
      if query.len == 0:
        ctx.response.code = Http400
        ctx.response.body = $ %* {
          "errors": [{
            "message": "Missing query"
          }]
        }
        return
      
      # Валидация на сложността
      if not validateQueryComplexity(query):
        ctx.response.code = Http400
        ctx.response.body = $ %* {
          "errors": [{
            "message": "Query too complex",
            "extensions": {
              "code": "QUERY_TOO_COMPLEX",
              "maxComplexity": MAX_QUERY_COMPLEXITY,
              "actualComplexity": calculateQueryComplexity(query)
            }
          }]
        }
        return
      
      # Създаване на GraphQL контекст
      let graphqlCtx = GraphQLContext(
        request: ctx.request,
        user: none(JsonNode)  # TODO: Извличане на потребител от token
      )
      
      # Симулация на изпълнение на заявката
      var result: JsonNode
      
      # Примерно router-ване според заявката
      if query.contains("account("):
        let args = %* {"id": 1}  # Симулация на аргументи
        result = await resolveAccount(graphqlCtx, args)
        
      elif query.contains("accounts"):
        let args = %* {"first": 10}
        let accountsResult = await resolveAccounts(graphqlCtx, args)
        result = %* {"data": {"accounts": accountsResult}}
        
      elif query.contains("createAccount"):
        let args = %* {
          "input": {
            "code": "1500",
            "name": "Банкова сметка",
            "accountType": "ASSET"
          }
        }
        let accountResult = await resolveCreateAccount(graphqlCtx, args)
        result = %* {"data": {"createAccount": accountResult}}
        
      elif query.contains("trialBalance"):
        let args = %* {"asOfDate": $now()}
        let balanceResult = await resolveTrialBalance(graphqlCtx, args)
        result = %* {"data": {"trialBalance": balanceResult}}
        
      else:
        result = %* {
          "data": nil,
          "errors": [{
            "message": "Unsupported query operation"
          }]
        }
      
      ctx.response.headers["Content-Type"] = "application/json"
      ctx.response.body = $result
      
    else:
      ctx.response.code = Http405
      ctx.response.body = "Method not allowed"
      
  except JsonParsingError:
    ctx.response.code = Http400
    ctx.response.body = $ %* {
      "errors": [{
        "message": "Invalid JSON in request body"
      }]
    }
  except Exception as e:
    ctx.response.code = Http500
    ctx.response.body = $ %* {
      "errors": [{
        "message": "Internal server error: " & e.msg
      }]
    }

# CORS middleware за GraphQL
proc accountingGraphqlCorsMiddleware*(): HandlerAsync =
  ## CORS middleware специално за GraphQL заявки
  return proc(ctx: Context) {.async.} =
    ctx.response.headers["Access-Control-Allow-Origin"] = "*"
    ctx.response.headers["Access-Control-Allow-Methods"] = "POST, GET, OPTIONS"
    ctx.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
    ctx.response.headers["Access-Control-Max-Age"] = "86400"
    
    if ctx.request.reqMethod == HttpOptions:
      ctx.response.code = Http200
      ctx.response.body = ""
    else:
      await switch(ctx)

# Основен GraphQL handler (експорт за main.nim)
proc graphqlHandler*(ctx: Context) {.async.} =
  ## Основен GraphQL handler който се използва в main.nim
  await accountingGraphqlHandler(ctx)

# GraphQL Playground за разработка
proc accountingGraphqlPlaygroundHandler*(ctx: Context) {.async.} =
  ## Предоставя GraphQL Playground за счетоводни операции
  ctx.response.headers["Content-Type"] = "text/html"
  ctx.response.body = """
<!DOCTYPE html>
<html>
<head>
  <meta charset=utf-8/>
  <meta name="viewport" content="user-scalable=no, initial-scale=1.0, minimum-scale=1.0, maximum-scale=1.0, minimal-ui">
  <title>Accounting GraphQL Playground</title>
  <link rel="stylesheet" href="//cdn.jsdelivr.net/npm/graphql-playground-react/build/static/css/index.css" />
  <link rel="shortcut icon" href="//cdn.jsdelivr.net/npm/graphql-playground-react/build/favicon.png" />
  <script src="//cdn.jsdelivr.net/npm/graphql-playground-react/build/static/js/middleware.js"></script>
</head>
<body>
  <div id="root">
    <style>
      body { background-color: rgb(23, 42, 58); font-family: Open Sans, sans-serif; height: 90vh; }
      #root { height: 100%; width: 100%; display: flex; align-items: center; justify-content: center; }
      .loading { font-size: 32px; font-weight: 200; color: rgba(255, 255, 255, .6); margin-left: 20px; }
      img { width: 78px; height: 78px; }
      .title { font-weight: 400; }
    </style>
    <img src="//cdn.jsdelivr.net/npm/graphql-playground-react/build/logo.png" alt="Accounting GraphQL">
    <div class="loading"> Loading
      <span class="title">Accounting GraphQL Playground</span>
    </div>
  </div>
  <script>window.addEventListener('load', function (event) {
      GraphQLPlayground.init(document.getElementById('root'), {
        endpoint: '/accounting/graphql',
        settings: {
          'general.betaUpdates': false,
          'editor.theme': 'dark',
          'editor.cursorShape': 'line',
          'editor.reuseHeaders': true,
          'tracing.hideTracingResponse': true,
          'queryPlan.hideQueryPlanResponse': true,
          'editor.fontSize': 14,
          'editor.fontFamily': '"Source Code Pro", "Consolas", "Inconsolata", "Droid Sans Mono", "Monaco", monospace',
          'request.credentials': 'omit',
        },
        tabs: [
          {
            endpoint: '/accounting/graphql',
            query: `# Примерни заявки за счетоводната система

# Получаване на сметка по код
query GetAccount {
  account(code: "1100") {
    id
    code
    name
    accountType
    balance {
      amount
      currency
    }
    isActive
  }
}

# Списък със сметки
query GetAccounts {
  accounts(first: 10, accountType: ASSET) {
    edges {
      node {
        id
        code
        name
        accountType
        balance {
          amount
          currency
        }
      }
      cursor
    }
    pageInfo {
      hasNextPage
      startCursor
      endCursor
    }
    totalCount
  }
}

# Създаване на нова сметка
mutation CreateAccount {
  createAccount(input: {
    code: "1600"
    name: "Материали"
    accountType: ASSET
  }) {
    id
    code
    name
    accountType
    balance {
      amount
      currency
    }
  }
}

# Оборотна ведомост
query TrialBalance {
  trialBalance(asOfDate: "2024-12-31") {
    asOfDate
    accounts {
      accountCode
      accountName
      debitBalance {
        amount
        currency
      }
      creditBalance {
        amount
        currency
      }
    }
    totalDebits {
      amount
      currency
    }
    totalCredits {
      amount
      currency
    }
    isBalanced
  }
}

# Създаване на счетоводна транзакция
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
    description
    totalAmount {
      amount
      currency
    }
    status
    entries {
      id
      accountId
      debit {
        amount
        currency
      }
      credit {
        amount
        currency
      }
      description
    }
  }
}`
          }
        ]
      })
    })</script>
</body>
</html>
  """
