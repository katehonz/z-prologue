import std/[asyncdispatch, strutils, tables, times]
import ../core/[context, middlewaresbase]

type
  SecurityHeadersConfig* = object
    hsts*: bool
    hstsMaxAge*: int
    hstsIncludeSubdomains*: bool
    hstsPreload*: bool
    xFrameOptions*: string
    xContentTypeOptions*: bool
    xXssProtection*: bool
    referrerPolicy*: string
    contentSecurityPolicy*: string
    permissionsPolicy*: string
    crossOriginEmbedderPolicy*: string
    crossOriginOpenerPolicy*: string
    crossOriginResourcePolicy*: string
    strictTransportSecurity*: string
    expectCT*: tuple[enabled: bool, maxAge: int, enforce: bool, reportUri: string]

proc defaultCSP*(): string =
  "default-src 'self'; " &
  "script-src 'self' 'unsafe-inline' 'unsafe-eval'; " &
  "style-src 'self' 'unsafe-inline'; " &
  "img-src 'self' data: https:; " &
  "font-src 'self'; " &
  "connect-src 'self'; " &
  "media-src 'self'; " &
  "object-src 'none'; " &
  "child-src 'self'; " &
  "frame-ancestors 'self'; " &
  "form-action 'self'; " &
  "upgrade-insecure-requests; " &
  "block-all-mixed-content"

proc strictCSP*(): string =
  "default-src 'none'; " &
  "script-src 'self'; " &
  "style-src 'self'; " &
  "img-src 'self'; " &
  "font-src 'self'; " &
  "connect-src 'self'; " &
  "media-src 'none'; " &
  "object-src 'none'; " &
  "child-src 'none'; " &
  "frame-ancestors 'none'; " &
  "form-action 'self'; " &
  "upgrade-insecure-requests; " &
  "block-all-mixed-content"

proc defaultPermissionsPolicy*(): string =
  "accelerometer=(), " &
  "camera=(), " &
  "geolocation=(), " &
  "gyroscope=(), " &
  "magnetometer=(), " &
  "microphone=(), " &
  "payment=(), " &
  "usb=()"

proc securityHeadersMiddleware*(
  hsts = true,
  hstsMaxAge = 31536000,
  hstsIncludeSubdomains = true,
  hstsPreload = false,
  xFrameOptions = "DENY",
  xContentTypeOptions = true,
  xXssProtection = true,
  referrerPolicy = "strict-origin-when-cross-origin",
  contentSecurityPolicy = "",
  permissionsPolicy = "",
  crossOriginEmbedderPolicy = "require-corp",
  crossOriginOpenerPolicy = "same-origin",
  crossOriginResourcePolicy = "same-origin",
  expectCT = (enabled: false, maxAge: 86400, enforce: false, reportUri: "")
): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if hsts:
      var hstsValue = "max-age=" & $hstsMaxAge
      if hstsIncludeSubdomains:
        hstsValue &= "; includeSubDomains"
      if hstsPreload:
        hstsValue &= "; preload"
      ctx.response.headers["Strict-Transport-Security"] = hstsValue
    
    if xFrameOptions != "":
      ctx.response.headers["X-Frame-Options"] = xFrameOptions
    
    if xContentTypeOptions:
      ctx.response.headers["X-Content-Type-Options"] = "nosniff"
    
    if xXssProtection:
      ctx.response.headers["X-XSS-Protection"] = "1; mode=block"
    
    if referrerPolicy != "":
      ctx.response.headers["Referrer-Policy"] = referrerPolicy
    
    let csp = if contentSecurityPolicy == "": defaultCSP() else: contentSecurityPolicy
    if csp != "":
      ctx.response.headers["Content-Security-Policy"] = csp
    
    let pp = if permissionsPolicy == "": defaultPermissionsPolicy() else: permissionsPolicy
    if pp != "":
      ctx.response.headers["Permissions-Policy"] = pp
    
    if crossOriginEmbedderPolicy != "":
      ctx.response.headers["Cross-Origin-Embedder-Policy"] = crossOriginEmbedderPolicy
    
    if crossOriginOpenerPolicy != "":
      ctx.response.headers["Cross-Origin-Opener-Policy"] = crossOriginOpenerPolicy
    
    if crossOriginResourcePolicy != "":
      ctx.response.headers["Cross-Origin-Resource-Policy"] = crossOriginResourcePolicy
    
    if expectCT.enabled:
      var expectCTValue = "max-age=" & $expectCT.maxAge
      if expectCT.enforce:
        expectCTValue &= ", enforce"
      if expectCT.reportUri != "":
        expectCTValue &= ", report-uri=\"" & expectCT.reportUri & "\""
      ctx.response.headers["Expect-CT"] = expectCTValue
    
    await switch(ctx)

proc removeServerHeader*(): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    await switch(ctx)
    ctx.response.headers.del("Server")

proc addSecurityHeaders*(app: var auto, config: SecurityHeadersConfig = SecurityHeadersConfig()) =
  app.use(securityHeadersMiddleware(
    hsts = config.hsts,
    hstsMaxAge = config.hstsMaxAge,
    hstsIncludeSubdomains = config.hstsIncludeSubdomains,
    hstsPreload = config.hstsPreload,
    xFrameOptions = config.xFrameOptions,
    xContentTypeOptions = config.xContentTypeOptions,
    xXssProtection = config.xXssProtection,
    referrerPolicy = config.referrerPolicy,
    contentSecurityPolicy = config.contentSecurityPolicy,
    permissionsPolicy = config.permissionsPolicy,
    crossOriginEmbedderPolicy = config.crossOriginEmbedderPolicy,
    crossOriginOpenerPolicy = config.crossOriginOpenerPolicy,
    crossOriginResourcePolicy = config.crossOriginResourcePolicy,
    expectCT = config.expectCT
  ))
  app.use(removeServerHeader())