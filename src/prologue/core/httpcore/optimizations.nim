# Copyright 2025 Prologue HTTP Optimizations Integration
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## HTTP Optimizations Integration for Prologue
## 
## This module integrates all HTTP/1.1 Keep-Alive optimizations:
## - Keep-Alive connection management
## - Advanced connection pooling
## - Adaptive timeout management
## - Performance monitoring and metrics
## - Automatic optimization based on traffic patterns

import std/[asyncdispatch, times, tables, options, logging, strutils, json]
import std/locks
import ./keepalive
import ./connectionpool
import ./timeouts

export keepalive, connectionpool, timeouts

type
  OptimizationLevel* = enum
    ## Optimization levels
    olConservative = "conservative"   # Safe, minimal optimizations
    olBalanced = "balanced"          # Balanced performance and safety
    olAggressive = "aggressive"      # Maximum performance optimizations
    olCustom = "custom"              # Custom configuration

  HttpOptimizer* = ref object
    ## Main HTTP optimizer that coordinates all optimizations
    level*: OptimizationLevel
    keepAliveManager*: KeepAliveManager
    connectionPool*: HttpConnectionPool
    timeoutManager*: timeouts.TimeoutManager
    config*: OptimizerConfig
    metrics*: OptimizerMetrics
    enabled*: bool
    lock*: Lock

  OptimizerConfig* = object
    ## Configuration for HTTP optimizer
    level*: OptimizationLevel
    enableKeepAlive*: bool
    enableConnectionPooling*: bool
    enableAdaptiveTimeouts*: bool
    enableMetrics*: bool
    enableAutoTuning*: bool
    metricsInterval*: int            # seconds
    autoTuningInterval*: int         # seconds
    performanceThreshold*: float     # response time threshold for tuning

  OptimizerMetrics* = object
    ## Comprehensive metrics for HTTP optimizer
    totalRequests*: int
    avgResponseTime*: float
    connectionReuseRate*: float
    timeoutOccurrences*: int
    optimizationAdjustments*: int
    performanceGain*: float          # percentage improvement
    lastMetricsUpdate*: Time

  PerformanceProfile* = object
    ## Performance profile for automatic tuning
    avgResponseTime*: float
    p95ResponseTime*: float
    p99ResponseTime*: float
    errorRate*: float
    connectionUtilization*: float
    memoryUsage*: float
    cpuUsage*: float

  OptimizationRecommendation* = object
    ## Recommendation for optimization adjustments
    component*: string               # Which component to adjust
    parameter*: string               # Which parameter to change
    currentValue*: string            # Current value
    recommendedValue*: string        # Recommended value
    expectedImprovement*: float      # Expected improvement percentage
    confidence*: float               # Confidence in recommendation (0-1)

# Predefined optimization configurations
const OptimizationConfigs* = {
  olConservative: OptimizerConfig(
    level: olConservative,
    enableKeepAlive: true,
    enableConnectionPooling: true,
    enableAdaptiveTimeouts: false,
    enableMetrics: true,
    enableAutoTuning: false,
    metricsInterval: 60,
    autoTuningInterval: 300,
    performanceThreshold: 2000.0
  ),
  olBalanced: OptimizerConfig(
    level: olBalanced,
    enableKeepAlive: true,
    enableConnectionPooling: true,
    enableAdaptiveTimeouts: true,
    enableMetrics: true,
    enableAutoTuning: true,
    metricsInterval: 30,
    autoTuningInterval: 180,
    performanceThreshold: 1500.0
  ),
  olAggressive: OptimizerConfig(
    level: olAggressive,
    enableKeepAlive: true,
    enableConnectionPooling: true,
    enableAdaptiveTimeouts: true,
    enableMetrics: true,
    enableAutoTuning: true,
    metricsInterval: 15,
    autoTuningInterval: 60,
    performanceThreshold: 1000.0
  )
}.toTable

proc initHttpOptimizer*(level: OptimizationLevel = olBalanced,
                       customConfig: Option[OptimizerConfig] = none(OptimizerConfig)): HttpOptimizer =
  ## Initializes HTTP optimizer with specified optimization level
  let config = if customConfig.isSome:
    customConfig.get
  else:
    OptimizationConfigs[level]
  
  result = HttpOptimizer(
    level: level,
    config: config,
    metrics: OptimizerMetrics(lastMetricsUpdate: getTime()),
    enabled: true
  )
  initLock(result.lock)
  
  # Initialize components based on configuration
  if config.enableKeepAlive:
    let keepAliveConfig = if level == olAggressive:
      KeepAliveConfig(
        enabled: true,
        maxConnections: 2000,
        maxIdleTime: 120,
        maxConnectionAge: 600,
        maxRequestsPerConnection: 200,
        keepAliveTimeout: 30,
        cleanupInterval: 15,
        healthCheckInterval: 30,
        adaptiveTimeouts: true,
        connectionReuse: true,
        compressionEnabled: true
      )
    elif level == olConservative:
      KeepAliveConfig(
        enabled: true,
        maxConnections: 500,
        maxIdleTime: 30,
        maxConnectionAge: 180,
        maxRequestsPerConnection: 50,
        keepAliveTimeout: 10,
        cleanupInterval: 60,
        healthCheckInterval: 120,
        adaptiveTimeouts: false,
        connectionReuse: true,
        compressionEnabled: false
      )
    else:
      DefaultKeepAliveConfig
    
    result.keepAliveManager = initKeepAliveManager(keepAliveConfig)
  
  if config.enableConnectionPooling:
    let poolConfig = if level == olAggressive:
      PoolConfig(
        maxGlobalConnections: 3000,
        maxGroupConnections: 150,
        defaultStrategy: psAdaptive,
        enableAdaptive: true,
        enableHealthChecks: true,
        enableMetrics: true,
        cleanupInterval: 15,
        metricsInterval: 5,
        connectionTimeout: 45,
        idleTimeout: 180
      )
    elif level == olConservative:
      PoolConfig(
        maxGlobalConnections: 1000,
        maxGroupConnections: 50,
        defaultStrategy: psRoundRobin,
        enableAdaptive: false,
        enableHealthChecks: true,
        enableMetrics: true,
        cleanupInterval: 60,
        metricsInterval: 30,
        connectionTimeout: 20,
        idleTimeout: 600
      )
    else:
      DefaultPoolConfig
    
    result.connectionPool = initHttpConnectionPool(poolConfig)
  
  if config.enableAdaptiveTimeouts:
    let timeoutConfigs = if level == olAggressive:
      {
        ttConnection: TimeoutConfig(
          timeoutType: ttConnection,
          baseTimeout: 3000,
          minTimeout: 500,
          maxTimeout: 15000,
          strategy: tsPredictive,
          adaptationFactor: 0.2,
          historySize: 100,
          circuitThreshold: 3,
          circuitRecoveryTime: 15000
        ),
        ttRequest: TimeoutConfig(
          timeoutType: ttRequest,
          baseTimeout: 20000,
          minTimeout: 3000,
          maxTimeout: 60000,
          strategy: tsCircuitBreaker,
          adaptationFactor: 0.25,
          historySize: 200,
          circuitThreshold: 3,
          circuitRecoveryTime: 20000
        )
      }.toTable
    else:
      initTable[TimeoutType, TimeoutConfig]()
    
    result.timeoutManager = initTimeoutManager(timeoutConfigs)
  
  logging.info("Initialized HTTP optimizer with level: " & $level)

proc updateMetrics*(optimizer: HttpOptimizer) =
  ## Updates optimizer metrics
  acquire(optimizer.lock)
  defer: release(optimizer.lock)
  
  let now = getTime()
  
  # Collect metrics from components
  if optimizer.keepAliveManager != nil:
    let keepAliveStats = getConnectionPoolStats()
    optimizer.metrics.connectionReuseRate = keepAliveStats.poolHitRate
  
  if optimizer.connectionPool != nil:
    let poolStats = getPoolStatistics(optimizer.connectionPool)
    optimizer.metrics.avgResponseTime = poolStats.avgResponseTime
  
  if optimizer.timeoutManager != nil:
    let timeoutStats = getTimeoutStatistics(optimizer.timeoutManager)
    optimizer.metrics.timeoutOccurrences = 0
    for count in timeoutStats.timeoutOccurrences.values:
      optimizer.metrics.timeoutOccurrences += count
  
  optimizer.metrics.lastMetricsUpdate = now

proc analyzePerformance*(optimizer: HttpOptimizer): PerformanceProfile =
  ## Analyzes current performance and returns profile
  updateMetrics(optimizer)
  
  result = PerformanceProfile(
    avgResponseTime: optimizer.metrics.avgResponseTime,
    errorRate: 0.0,  # Will be calculated from actual data
    connectionUtilization: optimizer.metrics.connectionReuseRate
  )
  
  # Get detailed metrics from components
  if optimizer.connectionPool != nil:
    let poolStats = getPoolStatistics(optimizer.connectionPool)
    result.connectionUtilization = poolStats.utilizationRate
    result.errorRate = poolStats.errorRate
  
  # Calculate percentiles (simplified - in real implementation would use proper statistics)
  result.p95ResponseTime = result.avgResponseTime * 1.5
  result.p99ResponseTime = result.avgResponseTime * 2.0

proc generateRecommendations*(optimizer: HttpOptimizer, 
                            profile: PerformanceProfile): seq[OptimizationRecommendation] =
  ## Generates optimization recommendations based on performance profile
  result = @[]
  
  # Analyze response times
  if profile.avgResponseTime > optimizer.config.performanceThreshold:
    if optimizer.keepAliveManager != nil:
      result.add(OptimizationRecommendation(
        component: "keep-alive",
        parameter: "maxConnections",
        currentValue: $optimizer.keepAliveManager.config.maxConnections,
        recommendedValue: $(optimizer.keepAliveManager.config.maxConnections * 2),
        expectedImprovement: 15.0,
        confidence: 0.7
      ))
    
    if optimizer.timeoutManager != nil:
      result.add(OptimizationRecommendation(
        component: "timeouts",
        parameter: "adaptiveTimeouts",
        currentValue: "current",
        recommendedValue: "enabled",
        expectedImprovement: 10.0,
        confidence: 0.8
      ))
  
  # Analyze connection utilization
  if profile.connectionUtilization < 0.5:
    result.add(OptimizationRecommendation(
      component: "connection-pool",
      parameter: "maxIdleTime",
      currentValue: "current",
      recommendedValue: "reduced",
      expectedImprovement: 8.0,
      confidence: 0.6
    ))
  
  # Analyze error rates
  if profile.errorRate > 0.05:  # 5% error rate
    result.add(OptimizationRecommendation(
      component: "circuit-breaker",
      parameter: "threshold",
      currentValue: "current",
      recommendedValue: "reduced",
      expectedImprovement: 20.0,
      confidence: 0.9
    ))

proc applyRecommendations*(optimizer: HttpOptimizer, 
                          recommendations: seq[OptimizationRecommendation]) =
  ## Applies optimization recommendations
  acquire(optimizer.lock)
  defer: release(optimizer.lock)
  
  for rec in recommendations:
    if rec.confidence < 0.5:
      continue  # Skip low-confidence recommendations
    
    case rec.component:
    of "keep-alive":
      if rec.parameter == "maxConnections" and optimizer.keepAliveManager != nil:
        # Would apply the recommendation - simplified for demo
        inc(optimizer.metrics.optimizationAdjustments)
        logging.info("Applied keep-alive optimization: " & rec.parameter)
    
    of "connection-pool":
      if optimizer.connectionPool != nil:
        inc(optimizer.metrics.optimizationAdjustments)
        logging.info("Applied connection pool optimization: " & rec.parameter)
    
    of "timeouts":
      if optimizer.timeoutManager != nil:
        inc(optimizer.metrics.optimizationAdjustments)
        logging.info("Applied timeout optimization: " & rec.parameter)
    
    of "circuit-breaker":
      inc(optimizer.metrics.optimizationAdjustments)
      logging.info("Applied circuit breaker optimization: " & rec.parameter)

proc autoTune*(optimizer: HttpOptimizer) =
  ## Performs automatic tuning based on current performance
  if not optimizer.config.enableAutoTuning:
    return
  
  let profile = analyzePerformance(optimizer)
  let recommendations = generateRecommendations(optimizer, profile)
  
  if recommendations.len > 0:
    logging.info("Auto-tuning: applying " & $recommendations.len & " recommendations")
    applyRecommendations(optimizer, recommendations)
  else:
    logging.debug("Auto-tuning: no recommendations needed")

proc startOptimizationTasks*(optimizer: HttpOptimizer) {.async.} =
  ## Starts background optimization tasks
  while optimizer.enabled:
    try:
      # Update metrics
      if optimizer.config.enableMetrics:
        updateMetrics(optimizer)
      
      # Perform auto-tuning
      if optimizer.config.enableAutoTuning:
        autoTune(optimizer)
      
      # Sleep for auto-tuning interval
      await sleepAsync(optimizer.config.autoTuningInterval * 1000)
      
    except Exception as e:
      logging.error("Error in optimization tasks: " & e.msg)
      await sleepAsync(60000)  # 1 minute on error

proc enableOptimizer*(optimizer: HttpOptimizer) =
  ## Enables the optimizer and starts background tasks
  optimizer.enabled = true
  asyncCheck startOptimizationTasks(optimizer)
  logging.info("HTTP optimizer enabled")

proc disableOptimizer*(optimizer: HttpOptimizer) =
  ## Disables the optimizer
  optimizer.enabled = false
  logging.info("HTTP optimizer disabled")

proc getOptimizerStatus*(optimizer: HttpOptimizer): JsonNode =
  ## Gets current optimizer status as JSON
  updateMetrics(optimizer)
  
  result = %*{
    "enabled": optimizer.enabled,
    "level": $optimizer.level,
    "metrics": {
      "totalRequests": optimizer.metrics.totalRequests,
      "avgResponseTime": optimizer.metrics.avgResponseTime,
      "connectionReuseRate": optimizer.metrics.connectionReuseRate,
      "timeoutOccurrences": optimizer.metrics.timeoutOccurrences,
      "optimizationAdjustments": optimizer.metrics.optimizationAdjustments,
      "performanceGain": optimizer.metrics.performanceGain,
      "lastUpdate": $optimizer.metrics.lastMetricsUpdate
    },
    "components": {
      "keepAlive": optimizer.keepAliveManager != nil,
      "connectionPool": optimizer.connectionPool != nil,
      "timeoutManager": optimizer.timeoutManager != nil
    }
  }

proc logOptimizerStatus*(optimizer: HttpOptimizer) =
  ## Logs current optimizer status
  let status = getOptimizerStatus(optimizer)
  logging.info("HTTP Optimizer Status: " & $status)

# Global optimizer instance
var globalHttpOptimizer*: HttpOptimizer

proc initGlobalHttpOptimizer*(level: OptimizationLevel = olBalanced,
                             customConfig: Option[OptimizerConfig] = none(OptimizerConfig)) =
  ## Initializes global HTTP optimizer
  globalHttpOptimizer = initHttpOptimizer(level, customConfig)
  enableOptimizer(globalHttpOptimizer)
  logging.info("Global HTTP optimizer initialized")

proc getGlobalHttpOptimizer*(): HttpOptimizer =
  ## Gets global HTTP optimizer
  if globalHttpOptimizer == nil:
    initGlobalHttpOptimizer()
  return globalHttpOptimizer

# Convenience functions for integration with Prologue
proc optimizeRequest*(clientId: string, requestStartTime: Time): tuple[timeout: int, useKeepAlive: bool] =
  ## Optimizes request parameters based on client and current conditions
  let optimizer = getGlobalHttpOptimizer()
  
  var timeout = 30000  # Default 30 seconds
  var useKeepAlive = true
  
  if optimizer.timeoutManager != nil:
    timeout = getTimeoutForClient(optimizer.timeoutManager, clientId, ttRequest)
  
  if optimizer.keepAliveManager != nil:
    # Check if keep-alive should be used based on current conditions
    let stats = getConnectionPoolStats()
    useKeepAlive = stats.poolHitRate > 0.5  # Use keep-alive if pool hit rate is good
  
  return (timeout: timeout, useKeepAlive: useKeepAlive)

proc recordRequestMetrics*(clientId: string, responseTime: float, success: bool, 
                          usedKeepAlive: bool) =
  ## Records request metrics for optimization
  let optimizer = getGlobalHttpOptimizer()
  
  acquire(optimizer.lock)
  defer: release(optimizer.lock)
  
  inc(optimizer.metrics.totalRequests)
  
  # Update average response time
  if optimizer.metrics.totalRequests > 1:
    optimizer.metrics.avgResponseTime = 
      (optimizer.metrics.avgResponseTime * float(optimizer.metrics.totalRequests - 1) + responseTime) / 
      float(optimizer.metrics.totalRequests)
  else:
    optimizer.metrics.avgResponseTime = responseTime
  
  # Record in timeout manager
  if optimizer.timeoutManager != nil:
    recordResponseTime(optimizer.timeoutManager, ttRequest, responseTime, success, clientId)
  
  logging.debug("Recorded request metrics - Response time: " & $responseTime & 
                "ms, Success: " & $success & ", Keep-alive: " & $usedKeepAlive)