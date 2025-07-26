import json, asyncdispatch, tables, times, strutils, base64

# Опростен GraphQL сървър за счетоводна програма
# Демонстрира основните възможности без зависимости

type
  GraphQLContext = ref object
    user: string
    
  Money = object
    amount: string
    currency: string
    
  Account = object
    id: int
    code: string
    name: string
    accountType: string
    balance: Money
    isActive: bool

# Помощни функции
proc newMoney(amount: string, currency: string = "BGN"): Money =
  Money(amount: amount, currency: currency)

proc encodeCursor(id: int): string =
  encode($id)

# Sample data  
var accounts = @[
  Account(
    id: 1, code: "1100", name: "Каса", accountType: "ASSET",
    balance: newMoney("1500.00"), isActive: true
  ),
  Account(
    id: 2, code: "1200", name: "Банка", accountType: "ASSET", 
    balance: newMoney("25000.00"), isActive: true
  ),
  Account(
    id: 3, code: "2100", name: "Доставчици", accountType: "LIABILITY",
    balance: newMoney("8500.00"), isActive: true
  )
]

# GraphQL resolvers
proc resolveAccount(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let id = args{"id"}.getInt(0)
  let code = args{"code"}.getStr("")
  
  for account in accounts:
    if (id > 0 and account.id == id) or (code.len > 0 and account.code == code):
      return %* {
        "id": account.id,
        "code": account.code,
        "name": account.name,
        "accountType": account.accountType,
        "balance": {
          "amount": account.balance.amount,
          "currency": account.balance.currency
        },
        "isActive": account.isActive,
        "createdAt": $now(),
        "updatedAt": $now()
      }
  
  result = newJNull()

proc resolveAccounts(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let first = args{"first"}.getInt(10)
  
  var edges = newJArray()
  var count = 0
  
  for account in accounts:
    if count >= first: break
    
    edges.add(%* {
      "node": {
        "id": account.id,
        "code": account.code,
        "name": account.name,
        "accountType": account.accountType,
        "balance": {
          "amount": account.balance.amount,
          "currency": account.balance.currency
        },
        "isActive": account.isActive
      },
      "cursor": encodeCursor(account.id)
    })
    inc count
  
  result = %* {
    "edges": edges,
    "pageInfo": {
      "hasNextPage": count < accounts.len,
      "hasPreviousPage": false,
      "startCursor": if edges.len > 0: edges[0]{"cursor"}.getStr else: "",
      "endCursor": if edges.len > 0: edges[^1]{"cursor"}.getStr else: ""
    },
    "totalCount": accounts.len
  }

proc resolveTrialBalance(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  let asOfDate = args{"asOfDate"}.getStr($now())
  
  var accountBalances = newJArray()
  var totalDebits = 0.0
  var totalCredits = 0.0
  
  for account in accounts:
    let amount = parseFloat(account.balance.amount)
    
    if account.accountType in ["ASSET", "EXPENSE"]:
      accountBalances.add(%* {
        "accountCode": account.code,
        "accountName": account.name,
        "debitBalance": {"amount": account.balance.amount, "currency": "BGN"},
        "creditBalance": {"amount": "0.00", "currency": "BGN"}
      })
      totalDebits += amount
    else:
      accountBalances.add(%* {
        "accountCode": account.code,
        "accountName": account.name,
        "debitBalance": {"amount": "0.00", "currency": "BGN"},
        "creditBalance": {"amount": account.balance.amount, "currency": "BGN"}
      })
      totalCredits += amount
  
  result = %* {
    "asOfDate": asOfDate,
    "accounts": accountBalances,
    "totalDebits": {"amount": $totalDebits, "currency": "BGN"},
    "totalCredits": {"amount": $totalCredits, "currency": "BGN"},
    "isBalanced": abs(totalDebits - totalCredits) < 0.01
  }

proc executeGraphQL(query: string): Future[JsonNode] {.async.} =
  let ctx = GraphQLContext(user: "admin")
  
  # Опростен query parser
  if query.contains("trialBalance"):
    let args = %* {"asOfDate": $now()}
    let balanceData = await resolveTrialBalance(ctx, args)
    result = %* {"data": {"trialBalance": balanceData}}
    
  elif query.contains("account("):
    # Extract arguments
    let args = %* {"id": 1}
    let accountData = await resolveAccount(ctx, args)
    result = %* {"data": {"account": accountData}}
    
  elif query.contains("accounts"):
    let args = %* {"first": 10}
    let accountsData = await resolveAccounts(ctx, args)
    result = %* {"data": {"accounts": accountsData}}
    
  else:
    result = %* {
      "errors": [{
        "message": "Unknown query operation"
      }]
    }

# Test queries
proc testQueries() {.async.} =
  echo "🧪 Тестване на GraphQL заявки за счетоводна програма"
  echo repeat("=", 60)
  
  # Test 1: Get single account
  echo "\n📋 Test 1: Получаване на сметка"
  let query1 = """
    query {
      account(id: 1) {
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
  """
  
  let result1 = await executeGraphQL(query1)
  echo result1.pretty
  
  # Test 2: Get accounts list
  echo "\n📋 Test 2: Списък със сметки"
  let query2 = """
    query {
      accounts(first: 5) {
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
          totalCount
        }
      }
    }
  """
  
  let result2 = await executeGraphQL(query2)
  echo result2.pretty
  
  # Test 3: Trial balance
  echo "\n📋 Test 3: Оборотна ведомост"
  let query3 = """
    query {
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
  """
  
  let result3 = await executeGraphQL(query3)
  echo result3.pretty
  
  echo "\n✅ Всички тестове завършени успешно!"

when isMainModule:
  echo "🚀 Стартиране на GraphQL сървър за счетоводна програма"
  waitFor testQueries()