import std/[asyncdispatch, times, os, tables]
import ../core/[context, application]
import ../logging/structured

type
  ShutdownState* = enum
    Running
    Draining
    Stopped

  GracefulShutdown* = ref object
    state*: ShutdownState
    maxDrainTime*: float
    activeRequests*: int
    shutdownHandlers*: seq[proc() {.async.}]
    logger*: StructuredLogger

var shutdownManager*: GracefulShutdown

proc newGracefulShutdown*(maxDrainTime = 30.0, logger: StructuredLogger = nil): GracefulShutdown =
  new(result)
  result.state = Running
  result.maxDrainTime = maxDrainTime
  result.activeRequests = 0
  result.shutdownHandlers = @[]
  result.logger = if logger.isNil: defaultLogger else: logger

proc addShutdownHandler*(gs: GracefulShutdown, handler: proc() {.async.}) =
  gs.shutdownHandlers.add(handler)

proc trackRequest*(gs: GracefulShutdown): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if gs.state == Stopped:
      ctx.response.code = Http503
      ctx.response.headers["Connection"] = "close"
      ctx.response.headers["Retry-After"] = "60"
      resp jsonResponse(%*{
        "error": "Service Unavailable",
        "message": "Server is shutting down"
      }, Http503)
      return
    
    inc gs.activeRequests
    try:
      await switch(ctx)
    finally:
      dec gs.activeRequests
      
      if gs.state == Draining:
        ctx.response.headers["Connection"] = "close"

proc waitForDrain*(gs: GracefulShutdown) {.async.} =
  let startTime = epochTime()
  
  while gs.activeRequests > 0 and epochTime() - startTime < gs.maxDrainTime:
    if not gs.logger.isNil:
      gs.logger.info("Waiting for requests to complete",
        field("active_requests", gs.activeRequests),
        field("elapsed_seconds", epochTime() - startTime)
      )
    await sleepAsync(1000)
  
  if gs.activeRequests > 0:
    if not gs.logger.isNil:
      gs.logger.warn("Force closing remaining connections",
        field("active_requests", gs.activeRequests)
      )

proc shutdown*(gs: GracefulShutdown) {.async.} =
  if gs.state != Running:
    return
  
  gs.state = Draining
  
  if not gs.logger.isNil:
    gs.logger.info("Starting graceful shutdown",
      field("max_drain_time", gs.maxDrainTime)
    )
  
  for handler in gs.shutdownHandlers:
    try:
      await handler()
    except:
      if not gs.logger.isNil:
        gs.logger.error("Shutdown handler failed",
          field("error", getCurrentExceptionMsg())
        )
  
  await gs.waitForDrain()
  
  gs.state = Stopped
  
  if not gs.logger.isNil:
    gs.logger.info("Graceful shutdown completed")

proc setupSignalHandlers*(gs: GracefulShutdown) =
  proc handleSignal() {.noconv.} =
    echo "\nReceived shutdown signal"
    asyncCheck gs.shutdown()
    quit(0)
  
  setControlCHook(handleSignal)

proc initGracefulShutdown*(app: var Prologue, maxDrainTime = 30.0) =
  shutdownManager = newGracefulShutdown(maxDrainTime)
  app.use(shutdownManager.trackRequest())
  shutdownManager.setupSignalHandlers()

proc onShutdown*(handler: proc() {.async.}) =
  if not shutdownManager.isNil:
    shutdownManager.addShutdownHandler(handler)

proc closeDatabase() {.async.} =
  echo "Closing database connections..."
  await sleepAsync(100)

proc saveCache() {.async.} =
  echo "Saving cache to disk..."
  await sleepAsync(100)

proc flushLogs() {.async.} =
  echo "Flushing logs..."
  if not shutdownManager.isNil and not shutdownManager.logger.isNil:
    shutdownManager.logger.close()

template registerDefaultShutdownHandlers*() =
  onShutdown(closeDatabase)
  onShutdown(saveCache)
  onShutdown(flushLogs)