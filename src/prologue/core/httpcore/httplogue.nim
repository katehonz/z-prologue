#
#
#            Nim's Runtime Library
#        (c) Copyright 2016 Dominik Picheta
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
import std/[tables, httpcore, strutils, times, options]
import ./keepalive
import ./connectionpool
import ./timeouts
import ./optimizations

export httpcore, keepalive, connectionpool, timeouts, optimizations

type
  ResponseHeaders* = object
    table: TableRef[string, seq[string]]


func getTables*(headers: ResponseHeaders): TableRef[string, seq[string]] {.inline.} =
  ## Only for internal use, don't use it!
  headers.table

func toCaseInsensitive(s: string): string {.inline.} =
  result = toLowerAscii(s)

func initResponseHeaders*(): ResponseHeaders {.inline.} =
  ## Returns a new ``ResponseHeaders`` object.
  result.table = newTable[string, seq[string]]()

func initResponseHeaders*(keyValuePairs:
    openArray[tuple[key: string, val: string]]): ResponseHeaders =
  ## Returns a new ``ResponseHeaders`` object from an array.
  result.table = newTable[string, seq[string]]()
  for pair in keyValuePairs:
    let key = toCaseInsensitive(pair.key)
    if key in result.table:
      result.table[key].add(pair.val)
    else:
      result.table[key] = @[pair.val]

func `$`*(headers: ResponseHeaders): string {.inline.} =
  result = $headers.table

proc clear*(headers: ResponseHeaders) {.inline.} =
  headers.table.clear()

func `[]`*(headers: ResponseHeaders, key: string): seq[string] {.inline.} =
  ## Returns the values associated with the given ``key``. If there are
  ## no values associated with the key, an exception is raised.
  ##
  ## To access multiple values of a key, use the overloaded ``[]`` below or
  ## to get all of them access the ``table`` field directly.
  result = headers.table[toCaseInsensitive(key)]

func `[]`*(headers: ResponseHeaders, key: string, i: int): string {.inline.} =
  ## Returns the ``i``'th value associated with the given key. If there are
  ## no values associated with the key or the ``i``'th value doesn't exist,
  ## an exception is raised.
  result = headers.table[toCaseInsensitive(key)][i]

func `[]=`*(headers: var ResponseHeaders, key, value: string) {.inline.} =
  ## Sets the header entries associated with ``key`` to the specified value.
  ## Replaces any existing values.
  headers.table[toCaseInsensitive(key)] = @[value]

func `[]=`*(headers: var ResponseHeaders, key: string, value: seq[string]) {.inline.} =
  ## Sets the header entries associated with ``key`` to the specified list of values.
  ## Replaces any existing values.
  ## 
  ## If ``value`` is an empty sequence, the ``key`` will be removed from ``headers``.
  if value.len > 0:
    headers.table[toCaseInsensitive(key)] = value
  else:
    headers.table.del(toCaseInsensitive(key))

func add*(headers: var ResponseHeaders, key, value: string) {.inline.} =
  ## Adds the specified value to the specified key. Appends to any existing
  ## values associated with the key.
  if not headers.table.hasKey(toCaseInsensitive(key)):
    headers.table[toCaseInsensitive(key)] = @[value]
  else:
    headers.table[toCaseInsensitive(key)].add(value)

func del*(headers: var ResponseHeaders, key: string) {.inline.} =
  ## Delete the header entries associated with ``key``
  headers.table.del(toCaseInsensitive(key))

iterator pairs*(headers: ResponseHeaders): tuple[key, value: string] =
  ## Yields each key, value pair.
  for k, v in headers.table:
    for value in v:
      yield (k, value)

func hasKey*(headers: ResponseHeaders, key: string): bool {.inline.} =
  result = headers.table.hasKey(toCaseInsensitive(key))

func getOrDefault*(headers: ResponseHeaders, key: string,
    default = @[""]): seq[string] {.inline.} =
  ## Returns the values associated with the given ``key``. If there are no
  ## values associated with the key, then ``default`` is returned.
  if headers.hasKey(key):
    result = headers[key]
  else:
    result = default

func len*(headers: ResponseHeaders): int {.inline.} =
  result = headers.table.len

# Keep-Alive integration functions
proc addKeepAliveSupport*(headers: var ResponseHeaders, timeout: int = 15, maxRequests: int = 100) =
  ## Adds Keep-Alive headers to response
  headers["Connection"] = "keep-alive"
  headers["Keep-Alive"] = "timeout=" & $timeout & ", max=" & $maxRequests

proc shouldUseKeepAlive*(headers: ResponseHeaders): bool =
  ## Determines if Keep-Alive should be used based on request headers
  let connection = headers.getOrDefault("connection", @[""]).join(",").toLowerAscii()
  let httpVersion = headers.getOrDefault("http-version", @["1.1"]).join(",")
  
  # HTTP/1.1 defaults to keep-alive unless explicitly closed
  if httpVersion == "1.1":
    result = connection != "close"
  else:
    # HTTP/1.0 requires explicit keep-alive
    result = connection.contains("keep-alive")

proc optimizeHeaders*(headers: var ResponseHeaders, clientId: string = "") =
  ## Optimizes headers based on current optimization settings
  let optimizer = getGlobalHttpOptimizer()
  if optimizer != nil and optimizer.enabled:
    let requestTime = getTime()
    let (timeout, useKeepAlive) = optimizeRequest(clientId, requestTime)
    
    if useKeepAlive:
      addKeepAliveSupport(headers, timeout div 1000)  # Convert ms to seconds
    else:
      headers["Connection"] = "close"

# Enhanced ResponseHeaders with optimization support
type
  OptimizedResponseHeaders* = object
    headers*: ResponseHeaders
    clientId*: string
    optimized*: bool

proc initOptimizedResponseHeaders*(clientId: string = ""): OptimizedResponseHeaders =
  ## Creates optimized response headers
  result = OptimizedResponseHeaders(
    headers: initResponseHeaders(),
    clientId: clientId,
    optimized: false
  )

proc optimize*(headers: var OptimizedResponseHeaders) =
  ## Applies optimizations to headers
  if not headers.optimized:
    optimizeHeaders(headers.headers, headers.clientId)
    headers.optimized = true

proc `[]`*(headers: OptimizedResponseHeaders, key: string): seq[string] {.inline.} =
  result = headers.headers[key]

proc `[]=`*(headers: var OptimizedResponseHeaders, key, value: string) {.inline.} =
  headers.headers[key] = value
  headers.optimized = false  # Mark as needing re-optimization

proc add*(headers: var OptimizedResponseHeaders, key, value: string) {.inline.} =
  headers.headers.add(key, value)
  headers.optimized = false

proc hasKey*(headers: OptimizedResponseHeaders, key: string): bool {.inline.} =
  result = headers.headers.hasKey(key)

iterator pairs*(headers: OptimizedResponseHeaders): tuple[key, value: string] =
  for pair in headers.headers.pairs():
    yield pair

proc len*(headers: OptimizedResponseHeaders): int {.inline.} =
  result = headers.headers.len()
