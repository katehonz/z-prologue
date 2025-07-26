import std/[asyncdispatch, times]
import ../core/[context, middlewaresbase]
import ../core/uid

type
  RequestIDGenerator* = proc(): string

proc defaultRequestIDGenerator(): string =
  let timestamp = now().toTime().toUnixFloat()
  return genUid() & "-" & $timestamp.int64

proc requestIDMiddleware*(
  headerName = "X-Request-ID",
  generator: RequestIDGenerator = nil,
  trustProxy = true
): HandlerAsync =
  let genID = if generator.isNil: defaultRequestIDGenerator else: generator
  
  result = proc(ctx: Context) {.async.} =
    var requestID: string
    
    if trustProxy and ctx.request.headers.hasKey(headerName):
      requestID = ctx.request.headers[headerName]
    else:
      requestID = genID()
    
    ctx.ctxData["request_id"] = requestID
    
    ctx.response.headers[headerName] = requestID
    
    await switch(ctx)