import prologue, json, asyncdispatch, tables, times, strutils
import prologue/core/context
import std/[options, base64]

# Тестов файл за GraphQL модула
# Съдържа само основните типове и функции без ORM зависимости

type
  # Основни GraphQL типове
  GraphQLContext* = ref object
    request*: Request
    user*: Option[JsonNode]

  Money* = object
    amount*: string
    currency*: string

  Account* = object
    id*: int
    code*: string
    name*: string
    balance*: Money

# Основни функции
proc newMoney*(amount: string, currency: string = "BGN"): Money =
  result = Money(amount: amount, currency: currency)

proc validateAccountCode*(code: string): bool =
  result = code.len >= 4 and code.len <= 10

proc encodeCursor*(id: int): string =
  result = encode($id)

# Тестов resolver
proc resolveAccount*(ctx: GraphQLContext, args: JsonNode): Future[JsonNode] {.async.} =
  result = %* {
    "id": 1,
    "code": "1100",
    "name": "Каса",
    "balance": {"amount": "1500.00", "currency": "BGN"}
  }

# Основен handler
proc testGraphqlHandler*(ctx: Context) {.async.} =
  ctx.response.headers["Content-Type"] = "application/json"
  
  let graphqlCtx = GraphQLContext(
    request: ctx.request,
    user: none(JsonNode)
  )
  
  let result = await resolveAccount(graphqlCtx, %*{})
  ctx.response.body = $ %* {"data": {"account": result}}

when isMainModule:
  echo "GraphQL тест модул компилиран успешно!"