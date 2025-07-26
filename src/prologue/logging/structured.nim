import std/[json, times, tables, os, asyncdispatch, locks, strtabs]
import ../core/[context, httpcore/httplogue]

type
  LogLevel* = enum
    Debug
    Info
    Warn
    Error
    Fatal

  LogFormat* = enum
    JSON
    Pretty

  LogOutput* = enum
    Stdout
    Stderr
    File
    Both

  LogField* = object
    key*: string
    value*: JsonNode

  LogEntry* = object
    timestamp*: DateTime
    level*: LogLevel
    message*: string
    fields*: seq[LogField]
    context*: JsonNode

  StructuredLogger* = ref object
    format*: LogFormat
    output*: LogOutput
    minLevel*: LogLevel
    filepath*: string
    file*: File
    buffer*: seq[string]
    bufferSize*: int
    lock: Lock
    asyncMode*: bool
    contextExtractor*: proc(ctx: Context): JsonNode

var defaultLogger*: StructuredLogger

proc initLock(logger: StructuredLogger) =
  initLock(logger.lock)

proc `$`(level: LogLevel): string =
  case level
  of Debug: "DEBUG"
  of Info: "INFO"
  of Warn: "WARN"
  of Error: "ERROR"
  of Fatal: "FATAL"

proc levelToInt(level: LogLevel): int =
  case level
  of Debug: 10
  of Info: 20
  of Warn: 30
  of Error: 40
  of Fatal: 50

proc defaultContextExtractor(ctx: Context): JsonNode =
  result = %*{
    "request_id": if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: "",
    "method": $ctx.request.reqMethod(),
    "path": ctx.request.path,
    "ip": ctx.request.ip,
    "user_agent": if ctx.request.headers.hasKey("User-Agent"): ctx.request.headers["User-Agent"] else: ""
  }

proc newStructuredLogger*(
  format = JSON,
  output = Stdout,
  minLevel = Info,
  filepath = "",
  bufferSize = 100,
  asyncMode = false,
  contextExtractor: proc(ctx: Context): JsonNode = nil
): StructuredLogger =
  new(result)
  result.format = format
  result.output = output
  result.minLevel = minLevel
  result.filepath = filepath
  result.buffer = @[]
  result.bufferSize = bufferSize
  result.asyncMode = asyncMode
  result.contextExtractor = if contextExtractor.isNil: defaultContextExtractor else: contextExtractor
  
  initLock(result)
  
  if output in {File, Both} and filepath != "":
    result.file = open(filepath, fmAppend)

proc formatJSON(entry: LogEntry): string =
  var jsonObj = %*{
    "timestamp": entry.timestamp.format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz"),
    "level": $entry.level,
    "message": entry.message
  }
  
  for field in entry.fields:
    jsonObj[field.key] = field.value
  
  if not entry.context.isNil:
    jsonObj["context"] = entry.context
  
  return $jsonObj

proc formatPretty(entry: LogEntry): string =
  result = entry.timestamp.format("yyyy-MM-dd HH:mm:ss.fff")
  result &= " [" & $entry.level & "] "
  result &= entry.message
  
  if entry.fields.len > 0:
    result &= " {"
    for i, field in entry.fields:
      if i > 0:
        result &= ", "
      result &= field.key & "=" & $field.value
    result &= "}"

proc writeLog(logger: StructuredLogger, formatted: string) =
  withLock logger.lock:
    case logger.output
    of Stdout:
      echo formatted
    of Stderr:
      stderr.writeLine(formatted)
    of File:
      if not logger.file.isNil:
        logger.file.writeLine(formatted)
        logger.file.flushFile()
    of Both:
      echo formatted
      if not logger.file.isNil:
        logger.file.writeLine(formatted)
        logger.file.flushFile()

proc flushBuffer(logger: StructuredLogger) =
  withLock logger.lock:
    for line in logger.buffer:
      case logger.output
      of Stdout:
        echo line
      of Stderr:
        stderr.writeLine(line)
      of File:
        if not logger.file.isNil:
          logger.file.writeLine(line)
      of Both:
        echo line
        if not logger.file.isNil:
          logger.file.writeLine(line)
    
    if not logger.file.isNil:
      logger.file.flushFile()
    
    logger.buffer = @[]

proc writeBuffered(logger: StructuredLogger, formatted: string) =
  withLock logger.lock:
    logger.buffer.add(formatted)
    if logger.buffer.len >= logger.bufferSize:
      logger.flushBuffer()

proc log*(
  logger: StructuredLogger,
  level: LogLevel,
  message: string,
  fields: varargs[LogField],
  context: JsonNode = nil
) =
  if levelToInt(level) < levelToInt(logger.minLevel):
    return
  
  let entry = LogEntry(
    timestamp: now(),
    level: level,
    message: message,
    fields: @fields,
    context: context
  )
  
  let formatted = case logger.format
    of JSON: formatJSON(entry)
    of Pretty: formatPretty(entry)
  
  if logger.asyncMode:
    logger.writeBuffered(formatted)
  else:
    logger.writeLog(formatted)

proc field*(key: string, value: string): LogField =
  LogField(key: key, value: %value)

proc field*(key: string, value: int): LogField =
  LogField(key: key, value: %value)

proc field*(key: string, value: float): LogField =
  LogField(key: key, value: %value)

proc field*(key: string, value: bool): LogField =
  LogField(key: key, value: %value)

proc field*(key: string, value: JsonNode): LogField =
  LogField(key: key, value: value)

proc debug*(logger: StructuredLogger, message: string, fields: varargs[LogField]) =
  logger.log(Debug, message, fields)

proc info*(logger: StructuredLogger, message: string, fields: varargs[LogField]) =
  logger.log(Info, message, fields)

proc warn*(logger: StructuredLogger, message: string, fields: varargs[LogField]) =
  logger.log(Warn, message, fields)

proc error*(logger: StructuredLogger, message: string, fields: varargs[LogField]) =
  logger.log(Error, message, fields)

proc fatal*(logger: StructuredLogger, message: string, fields: varargs[LogField]) =
  logger.log(Fatal, message, fields)

proc logRequest*(logger: StructuredLogger, ctx: Context, duration: float, statusCode: int) =
  let contextData = if logger.contextExtractor.isNil: 
    nil 
  else: 
    logger.contextExtractor(ctx)
  
  logger.info("Request completed",
    field("method", $ctx.request.reqMethod()),
    field("path", ctx.request.path),
    field("status", statusCode),
    field("duration_ms", duration * 1000),
    field("ip", ctx.request.ip),
    field("user_agent", if ctx.request.headers.hasKey("User-Agent"): ctx.request.headers["User-Agent"] else: ""),
    field("request_id", if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: "")
  )

proc logError*(logger: StructuredLogger, ctx: Context, error: ref Exception) =
  let contextData = if logger.contextExtractor.isNil: 
    nil 
  else: 
    logger.contextExtractor(ctx)
  
  logger.error("Request error",
    field("error", error.msg),
    field("error_type", $error.name),
    field("method", $ctx.request.reqMethod()),
    field("path", ctx.request.path),
    field("ip", ctx.request.ip),
    field("request_id", if ctx.ctxData.hasKey("request_id"): ctx.ctxData["request_id"] else: "")
  )

proc close*(logger: StructuredLogger) =
  if logger.asyncMode:
    logger.flushBuffer()
  
  if not logger.file.isNil:
    logger.file.close()

proc initDefaultLogger*(
  format = JSON,
  output = Stdout,
  minLevel = Info,
  filepath = "",
  bufferSize = 100,
  asyncMode = false
) =
  defaultLogger = newStructuredLogger(format, output, minLevel, filepath, bufferSize, asyncMode)

proc debug*(message: string, fields: varargs[LogField]) =
  if not defaultLogger.isNil:
    defaultLogger.debug(message, fields)

proc info*(message: string, fields: varargs[LogField]) =
  if not defaultLogger.isNil:
    defaultLogger.info(message, fields)

proc warn*(message: string, fields: varargs[LogField]) =
  if not defaultLogger.isNil:
    defaultLogger.warn(message, fields)

proc error*(message: string, fields: varargs[LogField]) =
  if not defaultLogger.isNil:
    defaultLogger.error(message, fields)

proc fatal*(message: string, fields: varargs[LogField]) =
  if not defaultLogger.isNil:
    defaultLogger.fatal(message, fields)