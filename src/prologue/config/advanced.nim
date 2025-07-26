import std/[os, json, tables, strutils, parsecfg, streams, sequtils]

type
  ConfigSource* = enum
    Environment
    File
    Default

  ConfigValue* = object
    value*: JsonNode
    source*: ConfigSource

  AdvancedConfig* = ref object
    values*: Table[string, ConfigValue]
    envPrefix*: string
    configPaths*: seq[string]
    watchConfig*: bool
    onChangeCallbacks*: seq[proc(key: string, oldValue, newValue: JsonNode)]

proc newAdvancedConfig*(
  envPrefix = "APP_",
  configPaths = @["config.json", "config.ini", "/etc/app/config.json"],
  watchConfig = false
): AdvancedConfig =
  new(result)
  result.values = initTable[string, ConfigValue]()
  result.envPrefix = envPrefix
  result.configPaths = configPaths
  result.watchConfig = watchConfig
  result.onChangeCallbacks = @[]

proc loadEnvVars*(config: AdvancedConfig) =
  for key, value in envPairs():
    if key.startsWith(config.envPrefix):
      let configKey = key[config.envPrefix.len..^1].toLowerAscii()
      
      var jsonValue: JsonNode
      if value.toLowerAscii() in ["true", "false"]:
        jsonValue = %value.parseBool()
      elif value.len > 0 and value.allCharsInSet({'0'..'9'}):
        try:
          jsonValue = %value.parseInt()
        except:
          jsonValue = %value
      else:
        try:
          jsonValue = parseJson(value)
        except:
          jsonValue = %value
      
      config.values[configKey] = ConfigValue(
        value: jsonValue,
        source: Environment
      )

proc loadJsonFile*(config: AdvancedConfig, path: string) =
  if fileExists(path):
    let content = readFile(path)
    let jsonData = parseJson(content)
    
    for key, value in jsonData:
      if not config.values.hasKey(key) or config.values[key].source != Environment:
        config.values[key] = ConfigValue(
          value: value,
          source: File
        )

proc loadIniFile*(config: AdvancedConfig, path: string) =
  if fileExists(path):
    var f = newFileStream(path, fmRead)
    if f != nil:
      var p: CfgParser
      open(p, f, path)
      
      var currentSection = ""
      while true:
        var e = next(p)
        case e.kind
        of cfgEof:
          break
        of cfgSectionStart:
          currentSection = e.section
        of cfgKeyValuePair:
          let key = if currentSection == "": e.key else: currentSection & "." & e.key
          
          var jsonValue: JsonNode
          let value = e.value
          if value.toLowerAscii() in ["true", "false"]:
            jsonValue = %value.parseBool()
          elif value.len > 0 and value.allCharsInSet({'0'..'9'}):
            try:
              jsonValue = %value.parseInt()
            except:
              jsonValue = %value
          else:
            jsonValue = %value
          
          if not config.values.hasKey(key) or config.values[key].source != Environment:
            config.values[key] = ConfigValue(
              value: jsonValue,
              source: File
            )
        of cfgOption:
          discard
        of cfgError:
          echo "Config parse error: ", e.msg
      
      close(p)
      f.close()

proc loadConfigFiles*(config: AdvancedConfig) =
  for path in config.configPaths:
    if path.endsWith(".json"):
      config.loadJsonFile(path)
    elif path.endsWith(".ini") or path.endsWith(".cfg"):
      config.loadIniFile(path)

proc load*(config: AdvancedConfig) =
  config.loadConfigFiles()
  config.loadEnvVars()

proc get*(config: AdvancedConfig, key: string, default: JsonNode = nil): JsonNode =
  if config.values.hasKey(key):
    return config.values[key].value
  return default

proc getString*(config: AdvancedConfig, key: string, default = ""): string =
  let value = config.get(key)
  if value.isNil:
    return default
  if value.kind == JString:
    return value.getStr()
  return $value

proc getInt*(config: AdvancedConfig, key: string, default = 0): int =
  let value = config.get(key)
  if value.isNil:
    return default
  if value.kind == JInt:
    return value.getInt()
  try:
    return value.getStr().parseInt()
  except:
    return default

proc getBool*(config: AdvancedConfig, key: string, default = false): bool =
  let value = config.get(key)
  if value.isNil:
    return default
  if value.kind == JBool:
    return value.getBool()
  try:
    return value.getStr().parseBool()
  except:
    return default

proc getFloat*(config: AdvancedConfig, key: string, default = 0.0): float =
  let value = config.get(key)
  if value.isNil:
    return default
  if value.kind == JFloat:
    return value.getFloat()
  elif value.kind == JInt:
    return value.getInt().float
  try:
    return value.getStr().parseFloat()
  except:
    return default

proc getSeq*(config: AdvancedConfig, key: string): seq[string] =
  let value = config.get(key)
  if value.isNil:
    return @[]
  if value.kind == JArray:
    for item in value:
      if item.kind == JString:
        result.add(item.getStr())
      else:
        result.add($item)
  else:
    result = value.getStr().split(",").mapIt(it.strip())

proc set*(config: AdvancedConfig, key: string, value: JsonNode, source = Default) =
  let oldValue = if config.values.hasKey(key): config.values[key].value else: nil
  
  config.values[key] = ConfigValue(value: value, source: source)
  
  if oldValue != value:
    for callback in config.onChangeCallbacks:
      callback(key, oldValue, value)

proc onChange*(config: AdvancedConfig, callback: proc(key: string, oldValue, newValue: JsonNode)) =
  config.onChangeCallbacks.add(callback)

proc validate*(config: AdvancedConfig, schema: JsonNode): bool =
  for key, schemaValue in schema:
    if schemaValue.hasKey("required") and schemaValue["required"].getBool():
      if not config.values.hasKey(key):
        echo "Missing required config: ", key
        return false
    
    if config.values.hasKey(key):
      let value = config.values[key].value
      
      if schemaValue.hasKey("type"):
        let expectedType = schemaValue["type"].getStr()
        case expectedType
        of "string":
          if value.kind != JString:
            echo "Invalid type for ", key, ": expected string"
            return false
        of "int":
          if value.kind != JInt:
            echo "Invalid type for ", key, ": expected int"
            return false
        of "bool":
          if value.kind != JBool:
            echo "Invalid type for ", key, ": expected bool"
            return false
        of "float":
          if value.kind notin {JFloat, JInt}:
            echo "Invalid type for ", key, ": expected float"
            return false
        of "array":
          if value.kind != JArray:
            echo "Invalid type for ", key, ": expected array"
            return false
      
      if schemaValue.hasKey("min") and value.kind in {JInt, JFloat}:
        let minVal = schemaValue["min"].getFloat()
        let val = if value.kind == JInt: value.getInt().float else: value.getFloat()
        if val < minVal:
          echo "Value for ", key, " is below minimum: ", minVal
          return false
      
      if schemaValue.hasKey("max") and value.kind in {JInt, JFloat}:
        let maxVal = schemaValue["max"].getFloat()
        let val = if value.kind == JInt: value.getInt().float else: value.getFloat()
        if val > maxVal:
          echo "Value for ", key, " is above maximum: ", maxVal
          return false
      
      if schemaValue.hasKey("enum") and schemaValue["enum"].kind == JArray:
        var found = false
        for enumVal in schemaValue["enum"]:
          if value == enumVal:
            found = true
            break
        if not found:
          echo "Invalid value for ", key, ": not in enum"
          return false
  
  return true

proc toJson*(config: AdvancedConfig): JsonNode =
  result = newJObject()
  for key, value in config.values:
    result[key] = value.value

proc getSource*(config: AdvancedConfig, key: string): ConfigSource =
  if config.values.hasKey(key):
    return config.values[key].source
  return Default