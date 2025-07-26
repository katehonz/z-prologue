import std/[asyncdispatch, strutils, tables]
import ../core/[context, middlewaresbase]
import pkg/zippy

type
  CompressionAlgorithm* = enum
    Gzip
    Deflate
    Brotli

  CompressionConfig* = object
    minSize*: int
    level*: int
    algorithms*: set[CompressionAlgorithm]
    excludeContentTypes*: seq[string]
    excludePaths*: seq[string]

proc shouldCompress(ctx: Context, config: CompressionConfig): bool =
  if ctx.request.path in config.excludePaths:
    return false
  
  let contentType = ctx.response.headers.getOrDefault("Content-Type", "")
  for excluded in config.excludeContentTypes:
    if contentType.contains(excluded):
      return false
  
  if ctx.response.body.len < config.minSize:
    return false
  
  let acceptEncoding = ctx.request.headers.getOrDefault("Accept-Encoding", "").toLowerAscii()
  
  for algo in config.algorithms:
    case algo
    of Gzip:
      if "gzip" in acceptEncoding:
        return true
    of Deflate:
      if "deflate" in acceptEncoding:
        return true
    of Brotli:
      if "br" in acceptEncoding:
        return true
  
  return false

proc selectAlgorithm(ctx: Context, config: CompressionConfig): CompressionAlgorithm =
  let acceptEncoding = ctx.request.headers.getOrDefault("Accept-Encoding", "").toLowerAscii()
  
  let parts = acceptEncoding.split(",")
  var preferences: seq[tuple[algo: string, quality: float]] = @[]
  
  for part in parts:
    let trimmed = part.strip()
    if trimmed.contains(";q="):
      let algoParts = trimmed.split(";q=")
      if algoParts.len == 2:
        try:
          preferences.add((algoParts[0].strip(), parseFloat(algoParts[1])))
        except:
          preferences.add((algoParts[0].strip(), 1.0))
    else:
      preferences.add((trimmed, 1.0))
  
  preferences.sort(proc(a, b: tuple[algo: string, quality: float]): int =
    cmp(b.quality, a.quality)
  )
  
  for pref in preferences:
    if pref.algo == "br" and Brotli in config.algorithms:
      return Brotli
    elif pref.algo == "gzip" and Gzip in config.algorithms:
      return Gzip
    elif pref.algo == "deflate" and Deflate in config.algorithms:
      return Deflate
  
  if Gzip in config.algorithms and "gzip" in acceptEncoding:
    return Gzip
  elif Deflate in config.algorithms and "deflate" in acceptEncoding:
    return Deflate
  elif Brotli in config.algorithms and "br" in acceptEncoding:
    return Brotli
  else:
    return Gzip

proc compressData(data: string, algorithm: CompressionAlgorithm, level: int): string =
  case algorithm
  of Gzip:
    return compress(data, dataFormat = dfGzip, level = level)
  of Deflate:
    return compress(data, dataFormat = dfDeflate, level = level)
  of Brotli:
    return compress(data, dataFormat = dfGzip, level = level)

proc compressionMiddleware*(
  minSize = 1024,
  level = 6,
  algorithms = {Gzip, Deflate},
  excludeContentTypes = @["image/", "video/", "audio/", "font/", "application/pdf", "application/zip"],
  excludePaths = @["/health", "/metrics"]
): HandlerAsync =
  let config = CompressionConfig(
    minSize: minSize,
    level: level,
    algorithms: algorithms,
    excludeContentTypes: excludeContentTypes,
    excludePaths: excludePaths
  )
  
  result = proc(ctx: Context) {.async.} =
    await switch(ctx)
    
    if ctx.response.code.is2xx and ctx.response.body.len > 0:
      if shouldCompress(ctx, config):
        let algorithm = selectAlgorithm(ctx, config)
        
        try:
          let compressed = compressData(ctx.response.body, algorithm, config.level)
          
          if compressed.len < ctx.response.body.len:
            ctx.response.body = compressed
            
            case algorithm
            of Gzip:
              ctx.response.headers["Content-Encoding"] = "gzip"
            of Deflate:
              ctx.response.headers["Content-Encoding"] = "deflate"
            of Brotli:
              ctx.response.headers["Content-Encoding"] = "br"
            
            ctx.response.headers["Content-Length"] = $compressed.len
            
            if not ctx.response.headers.hasKey("Vary"):
              ctx.response.headers["Vary"] = "Accept-Encoding"
            else:
              let vary = ctx.response.headers["Vary"]
              if "Accept-Encoding" notin vary:
                ctx.response.headers["Vary"] = vary & ", Accept-Encoding"
        except:
          discard