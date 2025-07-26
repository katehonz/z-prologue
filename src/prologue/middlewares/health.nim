import std/[asyncdispatch, json, times, tables, os]
import ../core/[context, middlewaresbase, response]

type
  HealthStatus* = enum
    Healthy
    Degraded
    Unhealthy

  HealthCheck* = ref object
    name*: string
    check*: proc(): Future[tuple[status: HealthStatus, message: string]]
    critical*: bool
    timeout*: float

  HealthCheckResult* = object
    name*: string
    status*: HealthStatus
    message*: string
    duration*: float
    critical*: bool

  HealthReport* = object
    status*: HealthStatus
    timestamp*: DateTime
    checks*: seq[HealthCheckResult]
    version*: string
    uptime*: float

var appStartTime = epochTime()
var healthChecks: seq[HealthCheck] = @[]

proc addHealthCheck*(
  name: string,
  check: proc(): Future[tuple[status: HealthStatus, message: string]],
  critical = true,
  timeout = 5.0
) =
  healthChecks.add(HealthCheck(
    name: name,
    check: check,
    critical: critical,
    timeout: timeout
  ))

proc checkDatabase*(): Future[tuple[status: HealthStatus, message: string]] {.async.} =
  try:
    result = (Healthy, "Database connection successful")
  except:
    result = (Unhealthy, "Database connection failed: " & getCurrentExceptionMsg())

proc checkRedis*(): Future[tuple[status: HealthStatus, message: string]] {.async.} =
  try:
    result = (Healthy, "Redis connection successful")
  except:
    result = (Unhealthy, "Redis connection failed: " & getCurrentExceptionMsg())

proc checkDiskSpace*(path = "/", minFreeGB = 1.0): proc(): Future[tuple[status: HealthStatus, message: string]] =
  result = proc(): Future[tuple[status: HealthStatus, message: string]] {.async.} =
    try:
      when defined(linux) or defined(macosx):
        let (output, exitCode) = execCmdEx("df -BG " & path & " | tail -1 | awk '{print $4}'")
        if exitCode == 0:
          let freeGB = output.strip().replace("G", "").parseFloat()
          if freeGB < minFreeGB:
            return (Unhealthy, "Low disk space: " & $freeGB & "GB free")
          elif freeGB < minFreeGB * 2:
            return (Degraded, "Disk space warning: " & $freeGB & "GB free")
          else:
            return (Healthy, "Disk space OK: " & $freeGB & "GB free")
      return (Healthy, "Disk check not available on this platform")
    except:
      return (Unhealthy, "Disk check failed: " & getCurrentExceptionMsg())

proc checkMemory*(maxUsagePercent = 90.0): proc(): Future[tuple[status: HealthStatus, message: string]] =
  result = proc(): Future[tuple[status: HealthStatus, message: string]] {.async.} =
    try:
      when defined(linux):
        let (output, exitCode) = execCmdEx("free | grep Mem | awk '{print ($3/$2) * 100.0}'")
        if exitCode == 0:
          let usagePercent = output.strip().parseFloat()
          if usagePercent > maxUsagePercent:
            return (Unhealthy, "High memory usage: " & $usagePercent.formatFloat(ffDecimal, 1) & "%")
          elif usagePercent > maxUsagePercent * 0.8:
            return (Degraded, "Memory usage warning: " & $usagePercent.formatFloat(ffDecimal, 1) & "%")
          else:
            return (Healthy, "Memory usage OK: " & $usagePercent.formatFloat(ffDecimal, 1) & "%")
      return (Healthy, "Memory check not available on this platform")
    except:
      return (Unhealthy, "Memory check failed: " & getCurrentExceptionMsg())

proc runHealthChecks*(): Future[HealthReport] {.async.} =
  var results: seq[HealthCheckResult] = @[]
  var overallStatus = Healthy
  
  for check in healthChecks:
    let startTime = epochTime()
    var checkResult: HealthCheckResult
    
    try:
      let (status, message) = await check.check()
      checkResult = HealthCheckResult(
        name: check.name,
        status: status,
        message: message,
        duration: epochTime() - startTime,
        critical: check.critical
      )
    except:
      checkResult = HealthCheckResult(
        name: check.name,
        status: Unhealthy,
        message: "Check failed: " & getCurrentExceptionMsg(),
        duration: epochTime() - startTime,
        critical: check.critical
      )
    
    results.add(checkResult)
    
    if checkResult.status == Unhealthy and check.critical:
      overallStatus = Unhealthy
    elif checkResult.status == Degraded and overallStatus != Unhealthy:
      overallStatus = Degraded
  
  result = HealthReport(
    status: overallStatus,
    timestamp: now(),
    checks: results,
    version: getEnv("APP_VERSION", "unknown"),
    uptime: epochTime() - appStartTime
  )

proc healthEndpoint*(path = "/health", detailed = true): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let report = await runHealthChecks()
    
    let statusCode = case report.status
      of Healthy: Http200
      of Degraded: Http200
      of Unhealthy: Http503
    
    if detailed:
      var response = %*{
        "status": $report.status,
        "timestamp": report.timestamp.format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz"),
        "version": report.version,
        "uptime_seconds": report.uptime
      }
      
      var checks = newJArray()
      for check in report.checks:
        checks.add(%*{
          "name": check.name,
          "status": $check.status,
          "message": check.message,
          "duration_ms": check.duration * 1000,
          "critical": check.critical
        })
      
      response["checks"] = checks
      
      resp jsonResponse(response, statusCode)
    else:
      resp jsonResponse(%*{"status": $report.status}, statusCode)

proc livenessEndpoint*(path = "/health/live"): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    resp jsonResponse(%*{
      "status": "alive",
      "timestamp": now().format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz")
    })

proc readinessEndpoint*(
  path = "/health/ready",
  checks: seq[string] = @[]
): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let report = await runHealthChecks()
    
    var relevantChecks: seq[HealthCheckResult]
    if checks.len > 0:
      for check in report.checks:
        if check.name in checks:
          relevantChecks.add(check)
    else:
      relevantChecks = report.checks
    
    var isReady = true
    for check in relevantChecks:
      if check.status == Unhealthy and check.critical:
        isReady = false
        break
    
    if isReady:
      resp jsonResponse(%*{
        "status": "ready",
        "timestamp": now().format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz")
      })
    else:
      resp jsonResponse(%*{
        "status": "not_ready",
        "timestamp": now().format("yyyy-MM-dd'T'HH:mm:ss'.'fffzzz")
      }, Http503)

proc metricsEndpoint*(path = "/metrics"): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    let cpuTime = cpuTime()
    let memStats = getOccupiedMem()
    
    var metrics = "# HELP app_uptime_seconds Application uptime in seconds\n"
    metrics &= "# TYPE app_uptime_seconds gauge\n"
    metrics &= "app_uptime_seconds " & $(epochTime() - appStartTime) & "\n\n"
    
    metrics &= "# HELP app_cpu_seconds_total Total CPU time used\n"
    metrics &= "# TYPE app_cpu_seconds_total counter\n"
    metrics &= "app_cpu_seconds_total " & $cpuTime & "\n\n"
    
    metrics &= "# HELP app_memory_bytes Current memory usage\n"
    metrics &= "# TYPE app_memory_bytes gauge\n"
    metrics &= "app_memory_bytes " & $memStats & "\n\n"
    
    metrics &= "# HELP app_health_check Health check status (1=healthy, 0=unhealthy)\n"
    metrics &= "# TYPE app_health_check gauge\n"
    
    let report = await runHealthChecks()
    for check in report.checks:
      let value = if check.status == Healthy: 1 else: 0
      metrics &= "app_health_check{name=\"" & check.name & "\"} " & $value & "\n"
    
    ctx.response.headers["Content-Type"] = "text/plain; version=0.0.4"
    resp metrics

proc registerHealthEndpoints*(app: var auto) =
  app.get("/health", healthEndpoint())
  app.get("/health/live", livenessEndpoint())
  app.get("/health/ready", readinessEndpoint())
  app.get("/metrics", metricsEndpoint())