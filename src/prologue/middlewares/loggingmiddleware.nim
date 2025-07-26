import std/[asyncdispatch, times, strutils]
import ../core/[context, middlewaresbase]
import ../logging/structured

type
  LoggingConfig* = object
    logger*: StructuredLogger
    skipPaths*: seq[string]
    skipMethods*: seq[string]
    includeHeaders*: seq[string]
    includeBody*: bool
    maxBodySize*: int

proc loggingMiddleware*(
  logger: StructuredLogger = nil,
  skipPaths: seq[string] = @["/health", "/metrics"],
  skipMethods: seq[string] = @[],
  includeHeaders: seq[string] = @[],
  includeBody = false,
  maxBodySize = 1024
): HandlerAsync =
  let log = if logger.isNil: defaultLogger else: logger
  
  result = proc(ctx: Context) {.async.} =
    let startTime = epochTime()
    
    let shouldSkip = ctx.request.path in skipPaths or 
                     ctx.request.reqMethod in skipMethods
    
    if not shouldSkip:
      var fields = @[
        field("method", ctx.request.reqMethod),
        field("path", ctx.request.path),
        field("ip", ctx.request.ip)
      ]
      
      if ctx.ctxData.hasKey("request_id"):
        fields.add(field("request_id", ctx.ctxData["request_id"]))
      
      for header in includeHeaders:
        if ctx.request.headers.hasKey(header):
          fields.add(field("header_" & header.toLowerAscii().replace("-", "_"), 
                          ctx.request.headers[header]))
      
      if includeBody and ctx.request.body.len > 0 and ctx.request.body.len <= maxBodySize:
        fields.add(field("request_body", ctx.request.body))
      
      log.info("Request started", fields)
    
    var errorOccurred = false
    var errorMsg = ""
    
    try:
      await switch(ctx)
    except:
      errorOccurred = true
      errorMsg = getCurrentExceptionMsg()
      log.error("Request error",
        field("error", errorMsg),
        field("method", ctx.request.reqMethod),
        field("path", ctx.request.path),
        field("ip", ctx.request.ip),
        field("request_id", ctx.ctxData.getOrDefault("request_id", ""))
      )
      raise
    finally:
      let duration = epochTime() - startTime
      
      if not shouldSkip and not errorOccurred:
        var fields = @[
          field("method", ctx.request.reqMethod),
          field("path", ctx.request.path),
          field("status", ctx.response.code.int),
          field("duration_ms", duration * 1000),
          field("ip", ctx.request.ip)
        ]
        
        if ctx.ctxData.hasKey("request_id"):
          fields.add(field("request_id", ctx.ctxData["request_id"]))
        
        if ctx.response.headers.hasKey("Content-Length"):
          fields.add(field("response_size", ctx.response.headers["Content-Length"]))
        
        log.info("Request completed", fields)