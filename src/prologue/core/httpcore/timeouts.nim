# Copyright 2025 Prologue Timeout Optimizations
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

## Advanced Timeout Management for Prologue
## 
## This module provides sophisticated timeout management with:
## - Adaptive timeout algorithms based on network conditions
## - Per-client timeout customization
## - Circuit breaker patterns for failing connections
## - Timeout prediction based on historical data
## - Graceful degradation strategies

import std/[times, tables, math, logging, algorithm]
import std/locks

type
  TimeoutType* = enum
    ## Different types of timeouts
    ttConnection = "connection"      # Connection establishment timeout
    ttRead = "read"                 # Read operation timeout
    ttWrite = "write"               # Write operation timeout
    ttKeepAlive = "keepalive"       # Keep-alive timeout
    ttRequest = "request"           # Total request timeout
    ttResponse = "response"         # Response timeout

  TimeoutStrategy* = enum
    ## Timeout adaptation strategies
    tsFixed = "fixed"               # Fixed timeout values
    tsAdaptive = "adaptive"         # Adaptive based on history
    tsPredictive = "predictive"     # Predictive based on patterns
    tsCircuitBreaker = "circuit_breaker"  # Circuit breaker pattern

  CircuitState* = enum
    ## Circuit breaker states
    csClosed = "closed"             # Normal operation
    csOpen = "open"                 # Circuit is open (failing)
    csHalfOpen = "half_open"        # Testing if circuit can close

  TimeoutConfig* = object
    ## Configuration for specific timeout type
    timeoutType*: TimeoutType
    baseTimeout*: int               # Base timeout in milliseconds
    minTimeout*: int                # Minimum timeout
    maxTimeout*: int                # Maximum timeout
    strategy*: TimeoutStrategy
    adaptationFactor*: float        # How quickly to adapt (0.0-1.0)
    historySize*: int              # Size of history for adaptation
    circuitThreshold*: int         # Failures before opening circuit
    circuitRecoveryTime*: int      # Time before trying to close circuit

  TimeoutManager* = ref object
    ## Main timeout manager
    configs*: Table[TimeoutType, TimeoutConfig]
    histories*: Table[TimeoutType, seq[float]]  # Response time histories
    circuits*: Table[TimeoutType, CircuitBreaker]
    clientTimeouts*: Table[string, Table[TimeoutType, int]]  # Per-client timeouts
    statistics*: TimeoutStatistics
    lock*: Lock

  CircuitBreaker* = ref object
    ## Circuit breaker for timeout management
    state*: CircuitState
    failureCount*: int
    successCount*: int
    lastFailureTime*: Time
    recoveryTimeout*: int
    threshold*: int
    lock*: Lock

  TimeoutStatistics* = object
    ## Statistics for timeout management
    totalRequests*: int
    timeoutOccurrences*: Table[TimeoutType, int]
    avgResponseTimes*: Table[TimeoutType, float]
    adaptationCount*: int
    circuitOpenCount*: int
    lastStatsUpdate*: Time

  TimeoutPrediction* = object
    ## Prediction for optimal timeout
    predictedTimeout*: int
    confidence*: float              # 0.0-1.0
    basedOnSamples*: int
    trend*: float                   # Positive = increasing, negative = decreasing

  TimeoutError* = object of CatchableError

# Default configurations for different timeout types
const DefaultTimeoutConfigs* = {
  ttConnection: TimeoutConfig(
    timeoutType: ttConnection,
    baseTimeout: 5000,
    minTimeout: 1000,
    maxTimeout: 30000,
    strategy: tsAdaptive,
    adaptationFactor: 0.1,
    historySize: 50,
    circuitThreshold: 5,
    circuitRecoveryTime: 30000
  ),
  ttRead: TimeoutConfig(
    timeoutType: ttRead,
    baseTimeout: 10000,
    minTimeout: 2000,
    maxTimeout: 60000,
    strategy: tsAdaptive,
    adaptationFactor: 0.15,
    historySize: 100,
    circuitThreshold: 3,
    circuitRecoveryTime: 15000
  ),
  ttWrite: TimeoutConfig(
    timeoutType: ttWrite,
    baseTimeout: 8000,
    minTimeout: 1500,
    maxTimeout: 45000,
    strategy: tsAdaptive,
    adaptationFactor: 0.12,
    historySize: 75,
    circuitThreshold: 4,
    circuitRecoveryTime: 20000
  ),
  ttKeepAlive: TimeoutConfig(
    timeoutType: ttKeepAlive,
    baseTimeout: 15000,
    minTimeout: 5000,
    maxTimeout: 300000,
    strategy: tsPredictive,
    adaptationFactor: 0.05,
    historySize: 200,
    circuitThreshold: 10,
    circuitRecoveryTime: 60000
  ),
  ttRequest: TimeoutConfig(
    timeoutType: ttRequest,
    baseTimeout: 30000,
    minTimeout: 5000,
    maxTimeout: 120000,
    strategy: tsCircuitBreaker,
    adaptationFactor: 0.2,
    historySize: 150,
    circuitThreshold: 5,
    circuitRecoveryTime: 30000
  ),
  ttResponse: TimeoutConfig(
    timeoutType: ttResponse,
    baseTimeout: 25000,
    minTimeout: 3000,
    maxTimeout: 90000,
    strategy: tsAdaptive,
    adaptationFactor: 0.18,
    historySize: 120,
    circuitThreshold: 6,
    circuitRecoveryTime: 25000
  )
}.toTable

proc initCircuitBreaker*(threshold: int, recoveryTimeout: int): CircuitBreaker =
  ## Initializes a new circuit breaker
  result = CircuitBreaker(
    state: csClosed,
    failureCount: 0,
    successCount: 0,
    lastFailureTime: getTime(),
    recoveryTimeout: recoveryTimeout,
    threshold: threshold
  )
  initLock(result.lock)

proc initTimeoutManager*(customConfigs: Table[TimeoutType, TimeoutConfig] = initTable[TimeoutType, TimeoutConfig]()): TimeoutManager =
  ## Initializes timeout manager with optional custom configurations
  result = TimeoutManager(
    configs: DefaultTimeoutConfigs,
    histories: initTable[TimeoutType, seq[float]](),
    circuits: initTable[TimeoutType, CircuitBreaker](),
    clientTimeouts: initTable[string, Table[TimeoutType, int]](),
    statistics: TimeoutStatistics(
      timeoutOccurrences: initTable[TimeoutType, int](),
      avgResponseTimes: initTable[TimeoutType, float](),
      lastStatsUpdate: getTime()
    )
  )
  initLock(result.lock)
  
  # Override with custom configurations
  for timeoutType, config in customConfigs:
    result.configs[timeoutType] = config
  
  # Initialize circuit breakers
  for timeoutType, config in result.configs:
    result.circuits[timeoutType] = initCircuitBreaker(config.circuitThreshold, config.circuitRecoveryTime)
    result.histories[timeoutType] = @[]
    result.statistics.timeoutOccurrences[timeoutType] = 0
    result.statistics.avgResponseTimes[timeoutType] = 0.0
  
  logging.info("Initialized timeout manager with " & $result.configs.len & " timeout types")

proc recordResponseTime*(manager: TimeoutManager, timeoutType: TimeoutType, 
                        responseTime: float, success: bool, clientId: string = "") =
  ## Records response time for timeout adaptation
  acquire(manager.lock)
  defer: release(manager.lock)
  
  inc(manager.statistics.totalRequests)
  
  # Update history
  if not manager.histories.hasKey(timeoutType):
    manager.histories[timeoutType] = @[]
  
  manager.histories[timeoutType].add(responseTime)
  let config = manager.configs[timeoutType]
  
  # Keep history size manageable
  if manager.histories[timeoutType].len > config.historySize:
    manager.histories[timeoutType].delete(0)
  
  # Update circuit breaker
  if manager.circuits.hasKey(timeoutType):
    let circuit = manager.circuits[timeoutType]
    acquire(circuit.lock)
    defer: release(circuit.lock)
    
    if success:
      inc(circuit.successCount)
      if circuit.state == csHalfOpen and circuit.successCount >= 3:
        circuit.state = csClosed
        circuit.failureCount = 0
        logging.info("Circuit breaker closed for " & $timeoutType)
    else:
      inc(circuit.failureCount)
      inc(manager.statistics.timeoutOccurrences[timeoutType])
      
      if circuit.state == csClosed and circuit.failureCount >= circuit.threshold:
        circuit.state = csOpen
        circuit.lastFailureTime = getTime()
        inc(manager.statistics.circuitOpenCount)
        logging.warn("Circuit breaker opened for " & $timeoutType)
  
  # Update average response time
  let currentAvg = manager.statistics.avgResponseTimes[timeoutType]
  let totalSamples = manager.histories[timeoutType].len
  if totalSamples > 0:
    manager.statistics.avgResponseTimes[timeoutType] = 
      (currentAvg * float(totalSamples - 1) + responseTime) / float(totalSamples)
  
  logging.debug("Recorded response time for " & $timeoutType & ": " & $responseTime & "ms")

proc calculateAdaptiveTimeout*(manager: TimeoutManager, timeoutType: TimeoutType): int =
  ## Calculates adaptive timeout based on historical data
  acquire(manager.lock)
  defer: release(manager.lock)
  
  let config = manager.configs[timeoutType]
  
  if not manager.histories.hasKey(timeoutType) or manager.histories[timeoutType].len < 5:
    return config.baseTimeout
  
  let history = manager.histories[timeoutType]
  
  case config.strategy:
  of tsFixed:
    result = config.baseTimeout
  
  of tsAdaptive:
    # Use percentile-based adaptation
    var sortedHistory = history
    sortedHistory.sort()
    
    let p95Index = int(float(sortedHistory.len) * 0.95)
    let p95Time = sortedHistory[min(p95Index, sortedHistory.len - 1)]
    
    # Adapt based on 95th percentile with smoothing
    let adaptedTimeout = int(p95Time * (1.0 + config.adaptationFactor))
    result = max(config.minTimeout, min(config.maxTimeout, adaptedTimeout))
  
  of tsPredictive:
    # Use trend analysis for prediction - will be implemented after predictOptimalTimeout is defined
    # For now, use adaptive approach
    var sortedHistory = history
    sortedHistory.sort()
    
    let p90Index = int(float(sortedHistory.len) * 0.90)
    let p90Time = sortedHistory[min(p90Index, sortedHistory.len - 1)]
    
    let adaptedTimeout = int(p90Time * (1.0 + config.adaptationFactor))
    result = max(config.minTimeout, min(config.maxTimeout, adaptedTimeout))
  
  of tsCircuitBreaker:
    # Use circuit breaker state to determine timeout
    let circuit = manager.circuits[timeoutType]
    acquire(circuit.lock)
    defer: release(circuit.lock)
    
    case circuit.state:
    of csClosed:
      result = config.baseTimeout
    of csOpen:
      # Check if we should try half-open
      let timeSinceFailure = (getTime() - circuit.lastFailureTime).inMilliseconds
      if timeSinceFailure >= circuit.recoveryTimeout:
        circuit.state = csHalfOpen
        circuit.successCount = 0
        result = config.maxTimeout  # Use longer timeout when testing
        logging.info("Circuit breaker half-open for " & $timeoutType)
      else:
        result = 0  # Fail fast
    of csHalfOpen:
      result = config.maxTimeout  # Use longer timeout when testing

proc predictOptimalTimeout*(manager: TimeoutManager, timeoutType: TimeoutType): TimeoutPrediction =
  ## Predicts optimal timeout using trend analysis
  acquire(manager.lock)
  defer: release(manager.lock)
  
  let config = manager.configs[timeoutType]
  
  if not manager.histories.hasKey(timeoutType) or manager.histories[timeoutType].len < 10:
    return TimeoutPrediction(
      predictedTimeout: config.baseTimeout,
      confidence: 0.1,
      basedOnSamples: 0,
      trend: 0.0
    )
  
  let history = manager.histories[timeoutType]
  let samples = history.len
  
  # Calculate trend using linear regression
  var sumX: float = 0.0
  var sumY: float = 0.0
  var sumXY: float = 0.0
  var sumX2: float = 0.0
  
  for i in 0..<samples:
    let x = float(i)
    let y = history[i]
    sumX += x
    sumY += y
    sumXY += x * y
    sumX2 += x * x
  
  let n = float(samples)
  let slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
  let intercept = (sumY - slope * sumX) / n
  
  # Predict next timeout value
  let nextX = float(samples)
  let predictedValue = slope * nextX + intercept
  
  # Calculate confidence based on variance
  var variance: float = 0.0
  for i in 0..<samples:
    let predicted = slope * float(i) + intercept
    let actual = history[i]
    variance += (actual - predicted) * (actual - predicted)
  variance = variance / n
  
  let confidence = max(0.0, min(1.0, 1.0 - (variance / (predictedValue + 1.0))))
  
  # Apply safety margin
  let safetyMargin = 1.2  # 20% safety margin
  let predictedTimeout = int(predictedValue * safetyMargin)
  
  result = TimeoutPrediction(
    predictedTimeout: max(config.minTimeout, min(config.maxTimeout, predictedTimeout)),
    confidence: confidence,
    basedOnSamples: samples,
    trend: slope
  )
  
  logging.debug("Predicted timeout for " & $timeoutType & ": " & $result.predictedTimeout & 
                "ms (confidence: " & $(result.confidence * 100.0) & "%)")

proc getTimeoutForClient*(manager: TimeoutManager, clientId: string, 
                         timeoutType: TimeoutType): int =
  ## Gets timeout value for specific client
  acquire(manager.lock)
  defer: release(manager.lock)
  
  # Check if client has custom timeout
  if manager.clientTimeouts.hasKey(clientId) and 
     manager.clientTimeouts[clientId].hasKey(timeoutType):
    return manager.clientTimeouts[clientId][timeoutType]
  
  # Use adaptive timeout
  return calculateAdaptiveTimeout(manager, timeoutType)

proc setClientTimeout*(manager: TimeoutManager, clientId: string, 
                      timeoutType: TimeoutType, timeout: int) =
  ## Sets custom timeout for specific client
  acquire(manager.lock)
  defer: release(manager.lock)
  
  if not manager.clientTimeouts.hasKey(clientId):
    manager.clientTimeouts[clientId] = initTable[TimeoutType, int]()
  
  manager.clientTimeouts[clientId][timeoutType] = timeout
  logging.debug("Set custom timeout for client " & clientId & " (" & $timeoutType & "): " & $timeout & "ms")

proc removeClientTimeouts*(manager: TimeoutManager, clientId: string) =
  ## Removes all custom timeouts for client
  acquire(manager.lock)
  defer: release(manager.lock)
  
  if manager.clientTimeouts.hasKey(clientId):
    manager.clientTimeouts.del(clientId)
    logging.debug("Removed custom timeouts for client: " & clientId)

proc updateTimeoutConfig*(manager: TimeoutManager, timeoutType: TimeoutType, 
                         config: TimeoutConfig) =
  ## Updates configuration for specific timeout type
  acquire(manager.lock)
  defer: release(manager.lock)
  
  manager.configs[timeoutType] = config
  
  # Reinitialize circuit breaker if needed
  if manager.circuits.hasKey(timeoutType):
    manager.circuits[timeoutType] = initCircuitBreaker(config.circuitThreshold, config.circuitRecoveryTime)
  
  logging.info("Updated timeout configuration for " & $timeoutType)

proc getTimeoutStatistics*(manager: TimeoutManager): TimeoutStatistics =
  ## Gets current timeout statistics
  acquire(manager.lock)
  defer: release(manager.lock)
  
  manager.statistics.lastStatsUpdate = getTime()
  return manager.statistics

proc resetTimeoutStatistics*(manager: TimeoutManager) =
  ## Resets timeout statistics
  acquire(manager.lock)
  defer: release(manager.lock)
  
  manager.statistics = TimeoutStatistics(
    timeoutOccurrences: initTable[TimeoutType, int](),
    avgResponseTimes: initTable[TimeoutType, float](),
    lastStatsUpdate: getTime()
  )
  
  # Reset circuit breakers
  for timeoutType, circuit in manager.circuits.mpairs:
    acquire(circuit.lock)
    circuit.state = csClosed
    circuit.failureCount = 0
    circuit.successCount = 0
    release(circuit.lock)
  
  logging.info("Reset timeout statistics and circuit breakers")

proc logTimeoutStatistics*(manager: TimeoutManager) =
  ## Logs current timeout statistics
  let stats = getTimeoutStatistics(manager)
  
  logging.info("Timeout Statistics:")
  logging.info("  Total Requests: " & $stats.totalRequests)
  logging.info("  Circuit Opens: " & $stats.circuitOpenCount)
  logging.info("  Adaptations: " & $stats.adaptationCount)
  
  for timeoutType, count in stats.timeoutOccurrences:
    let avgTime = stats.avgResponseTimes.getOrDefault(timeoutType, 0.0)
    logging.info("  " & $timeoutType & " - Timeouts: " & $count & 
                 ", Avg Response: " & $avgTime & "ms")

# Utility functions for timeout management
proc isCircuitOpen*(manager: TimeoutManager, timeoutType: TimeoutType): bool =
  ## Checks if circuit breaker is open for timeout type
  acquire(manager.lock)
  defer: release(manager.lock)
  
  if manager.circuits.hasKey(timeoutType):
    let circuit = manager.circuits[timeoutType]
    acquire(circuit.lock)
    defer: release(circuit.lock)
    return circuit.state == csOpen
  
  return false

proc getOptimalTimeouts*(manager: TimeoutManager): Table[TimeoutType, int] =
  ## Gets optimal timeouts for all types
  result = initTable[TimeoutType, int]()
  
  for timeoutType in TimeoutType:
    result[timeoutType] = calculateAdaptiveTimeout(manager, timeoutType)

# Global timeout manager
var globalTimeoutManager*: TimeoutManager

proc initGlobalTimeoutManager*(customConfigs: Table[TimeoutType, TimeoutConfig] = initTable[TimeoutType, TimeoutConfig]()) =
  ## Initializes global timeout manager
  globalTimeoutManager = initTimeoutManager(customConfigs)
  logging.info("Global timeout manager initialized")

proc getGlobalTimeoutManager*(): TimeoutManager =
  ## Gets global timeout manager
  if globalTimeoutManager == nil:
    initGlobalTimeoutManager()
  return globalTimeoutManager

# Convenience functions using global manager
proc recordGlobalResponseTime*(timeoutType: TimeoutType, responseTime: float, 
                              success: bool, clientId: string = "") =
  ## Records response time using global manager
  let manager = getGlobalTimeoutManager()
  recordResponseTime(manager, timeoutType, responseTime, success, clientId)

proc getGlobalTimeout*(timeoutType: TimeoutType, clientId: string = ""): int =
  ## Gets timeout using global manager
  let manager = getGlobalTimeoutManager()
  if clientId.len > 0:
    return getTimeoutForClient(manager, clientId, timeoutType)
  else:
    return calculateAdaptiveTimeout(manager, timeoutType)