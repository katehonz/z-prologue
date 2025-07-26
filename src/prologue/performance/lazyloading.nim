# Copyright 2025 Prologue Performance Optimizations
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

## Lazy Loading Implementation for Prologue
## 
## This module provides lazy loading capabilities that defer resource initialization
## until they are actually needed, improving application startup time and memory usage.

import std/[asyncdispatch, options, times, logging, tables, strutils]
import std/locks

type
  LazyResource*[T] = ref object
    ## Generic lazy resource container
    loader: proc(): Future[T] {.async.}
    value: Option[T]
    initialized: bool
    loading: bool
    lock: Lock
    loadTime: int64
    accessCount: int

  LazyResourceError* = object of CatchableError

  LazyResourceManager* = ref object
    ## Manager for multiple lazy resources
    resources: Table[string, pointer]
    lock: Lock

  LazyConfig* = object
    ## Configuration for lazy loading behavior
    timeout*: int  # milliseconds
    retryCount*: int
    cacheResult*: bool

var globalLazyManager = LazyResourceManager(
  resources: initTable[string, pointer]()
)
initLock(globalLazyManager.lock)

proc newLazyResource*[T](loader: proc(): Future[T] {.async.}, 
                        config: LazyConfig = LazyConfig(timeout: 30000, retryCount: 3, cacheResult: true)): LazyResource[T] =
  ## Creates a new lazy resource with the specified loader function
  result = LazyResource[T](
    loader: loader,
    value: none(T),
    initialized: false,
    loading: false,
    loadTime: 0,
    accessCount: 0
  )
  initLock(result.lock)
  logging.debug("Created new lazy resource")

proc get*[T](resource: LazyResource[T]): Future[T] {.async.} =
  ## Gets the value from the lazy resource, loading it if necessary
  acquire(resource.lock)
  defer: release(resource.lock)
  
  inc(resource.accessCount)
  
  # If already initialized, return cached value
  if resource.initialized and resource.value.isSome:
    logging.debug("Lazy resource: returning cached value (access #" & $resource.accessCount & ")")
    return resource.value.get
  
  # If currently loading, wait (simplified - in real implementation would use proper synchronization)
  if resource.loading:
    release(resource.lock)
    await sleepAsync(10)  # Small delay
    acquire(resource.lock)
    if resource.initialized and resource.value.isSome:
      return resource.value.get
  
  # Load the resource
  resource.loading = true
  let startTime = getTime().toUnix()
  
  try:
    logging.debug("Lazy resource: loading value...")
    release(resource.lock)  # Release lock during loading
    let value = await resource.loader()
    acquire(resource.lock)
    
    resource.value = some(value)
    resource.initialized = true
    resource.loadTime = getTime().toUnix() - startTime
    resource.loading = false
    
    logging.info("Lazy resource loaded successfully in " & $resource.loadTime & " seconds")
    return value
    
  except Exception as e:
    acquire(resource.lock)
    resource.loading = false
    logging.error("Failed to load lazy resource: " & e.msg)
    raise newException(LazyResourceError, "Failed to load lazy resource: " & e.msg)

proc isLoaded*[T](resource: LazyResource[T]): bool =
  ## Checks if the lazy resource has been loaded
  acquire(resource.lock)
  defer: release(resource.lock)
  result = resource.initialized

proc getStats*[T](resource: LazyResource[T]): tuple[loaded: bool, accessCount: int, loadTime: int64] =
  ## Gets statistics about the lazy resource
  acquire(resource.lock)
  defer: release(resource.lock)
  result = (
    loaded: resource.initialized,
    accessCount: resource.accessCount,
    loadTime: resource.loadTime
  )

proc reset*[T](resource: LazyResource[T]) =
  ## Resets the lazy resource to unloaded state
  acquire(resource.lock)
  defer: release(resource.lock)
  
  resource.value = none(T)
  resource.initialized = false
  resource.loading = false
  resource.loadTime = 0
  logging.debug("Lazy resource reset")

# Lazy Resource Manager
proc registerResource*[T](manager: LazyResourceManager, name: string, resource: LazyResource[T]) =
  ## Registers a lazy resource with the manager
  acquire(manager.lock)
  defer: release(manager.lock)
  
  manager.resources[name] = cast[pointer](resource)
  logging.debug("Registered lazy resource: " & name)

proc getResource*[T](manager: LazyResourceManager, name: string, typ: typedesc): LazyResource[T] =
  ## Gets a registered lazy resource by name
  acquire(manager.lock)
  defer: release(manager.lock)
  
  if not manager.resources.hasKey(name):
    raise newException(LazyResourceError, "Lazy resource not found: " & name)
  
  result = cast[LazyResource[T]](manager.resources[name])

proc unregisterResource*(manager: LazyResourceManager, name: string) =
  ## Unregisters a lazy resource
  acquire(manager.lock)
  defer: release(manager.lock)
  
  if manager.resources.hasKey(name):
    manager.resources.del(name)
    logging.debug("Unregistered lazy resource: " & name)

# Global convenience functions
proc registerGlobalResource*[T](name: string, resource: LazyResource[T]) =
  ## Registers a resource with the global manager
  globalLazyManager.registerResource(name, resource)

proc getGlobalResource*[T](name: string, typ: typedesc): LazyResource[T] =
  ## Gets a resource from the global manager
  result = globalLazyManager.getResource(name, T)

# Specialized lazy loaders
proc newLazyFileLoader*(filePath: string): LazyResource[string] =
  ## Creates a lazy loader for file content
  result = newLazyResource(proc(): Future[string] {.async.} =
    logging.debug("Loading file: " & filePath)
    try:
      result = readFile(filePath)
      logging.debug("File loaded successfully: " & filePath)
    except IOError as e:
      logging.error("Failed to load file " & filePath & ": " & e.msg)
      raise
  )

proc newLazyConfigLoader*(configPath: string): LazyResource[Table[string, string]] =
  ## Creates a lazy loader for configuration files
  result = newLazyResource(proc(): Future[Table[string, string]] {.async.} =
    logging.debug("Loading config: " & configPath)
    result = initTable[string, string]()
    
    try:
      let content = readFile(configPath)
      # Simplified config parsing (key=value format)
      for line in content.splitLines():
        if line.len > 0 and not line.startsWith("#"):
          let parts = line.split("=", 1)
          if parts.len == 2:
            result[parts[0].strip()] = parts[1].strip()
      
      logging.info("Config loaded successfully: " & configPath & " (" & $result.len & " entries)")
    except IOError as e:
      logging.error("Failed to load config " & configPath & ": " & e.msg)
      raise
  )

proc newLazyDatabaseLoader*[A](connectionString: string, 
                              query: string,
                              parser: proc(data: string): A): LazyResource[A] =
  ## Creates a lazy loader for database data
  result = newLazyResource(proc(): Future[A] {.async.} =
    logging.debug("Loading database data with query: " & query)
    
    # В реална имплементация тук би се изпълнила заявката към базата данни
    # За демонстрация връщаме празен резултат
    let mockData = ""
    result = parser(mockData)
    
    logging.info("Database data loaded successfully")
  )

# Integration with Prologue Context
import ../core/context
import ../core/application

proc setLazyResource*[T](ctx: Context, name: string, resource: LazyResource[T]) =
  ## Sets a lazy resource in the context
  ctx.ctxData[name] = $cast[int](resource)

proc getLazyResource*[T](ctx: Context, name: string, typ: typedesc): LazyResource[T] =
  ## Gets a lazy resource from the context
  if not ctx.ctxData.hasKey(name):
    raise newException(LazyResourceError, "Lazy resource not found in context: " & name)
  
  let resourcePtr = parseInt(ctx.ctxData[name])
  result = cast[LazyResource[T]](resourcePtr)

# Middleware for lazy resource management
proc lazyResourceMiddleware*(resources: openArray[(string, pointer)]): HandlerAsync =
  ## Creates middleware that makes lazy resources available to handlers
  result = proc(ctx: Context) {.async.} =
    # Add lazy resources to context
    for (name, resourcePtr) in resources:
      ctx.ctxData[name] = $cast[int](resourcePtr)
    
    await switch(ctx)

# Utility macros and templates
template withLazyResource*[T](resource: LazyResource[T], body: untyped): untyped =
  ## Template for working with lazy resources
  let value {.inject.} = await resource.get()
  body

# Performance monitoring
type
  LazyResourceMetrics* = object
    totalResources*: int
    loadedResources*: int
    totalAccessCount*: int
    averageLoadTime*: float

proc getGlobalMetrics*(): LazyResourceMetrics =
  ## Gets global metrics for all lazy resources
  acquire(globalLazyManager.lock)
  defer: release(globalLazyManager.lock)
  
  result.totalResources = globalLazyManager.resources.len
  # В реална имплементация тук би се събрала статистика от всички ресурси
  result.loadedResources = 0
  result.totalAccessCount = 0
  result.averageLoadTime = 0.0
