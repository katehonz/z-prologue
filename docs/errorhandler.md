# Error Handling in Prologue

Prologue provides a powerful and flexible error handling system, allowing you to define custom error handlers, custom error pages, and centralized error logging.

---

## Main Concepts

- **Error Handler:** A procedure executed for a specific HTTP error (404, 500, etc.).
- **Global Error Table:** Register handlers for different HTTP codes.
- **Custom Pages:** Return HTML, JSON, or other responses on errors.

---

## Example: Custom Error Handler

```nim
proc custom404(ctx: Context) {.async.} =
  resp "<h1>Page not found!</h1>", code = Http404

app.registerErrorHandler(Http404, custom404)
```

---

## Centralized Error Logging

Use middleware to log all errors:

```nim
proc errorLogger(ctx: Context) {.async.} =
  if ctx.response.code >= 400:
    echo "Error: ", ctx.response.code, " - ", ctx.response.body
  await switch(ctx)

app.use(errorLogger)
```

---

## Built-in Error Pages

Prologue provides ready-made templates for 404 and 500 errors, which you can customize.

---

## Practical Tips

- Register handlers for common HTTP codes (404, 401, 500, etc.).
- Use logging for easy debugging in production.
- Return different responses based on request type (HTML, JSON, text).

---

For more, see the `core/httpexception.nim` and `core/application.nim` modules or ask for specific examples!
## User-defined error pages

When web application encounters some unexpected situations, it may send 404 response to the client.
You may want to use user-defined 404 pages, then you can use `resp` to return 404 response.


```nim
proc hello(ctx: Context) {.async.} =
  resp "Something is wrong, please retry.", Http404
```

`Prologue` also provides an `error404` helper function to create a 404 response.

```nim
proc hello(ctx: Context) {.async.} =
  resp error404(headers = ctx.response.headers)
```

Or use `errorPage` to create a more descriptive error page.

```nim
proc hello(ctx: Context) {.async.} =
  resp errorPage("Something is wrong"), Http404
```

## Default error handler

Users can also set the default error handler. When `ctx.response.body` is empty, web application will use the default error handler.

The basic example with `respDefault` which is equal to `resp errorPage("Something is wrong"), Http404`.

```nim
proc hello(ctx: Context) {.async.} =
  respDefault Http404
```

`Prologue` has registered two error handlers before application starts, namely `default404Handler` for `Http404` and `default500Handler` for `Http500`. You can change them using `registerErrorHandler`.

```nim
proc go404*(ctx: Context) {.async.} =
  resp "Something wrong!", Http404

proc go20x*(ctx: Context) {.async.} =
  resp "Ok!", Http200

proc go30x*(ctx: Context) {.async.} =
  resp "EveryThing else?", Http301

app.registerErrorHandler(Http404, go404)
app.registerErrorHandler({Http200 .. Http204}, go20x)
app.registerErrorHandler(@[Http301, Http304, Http307], go30x)
```

If you don't want to use the default Error handler, you could clear the whole error handler table.

```nim
var app = newApp(errorHandlerTable = newErrorHandlerTable())
```

## HTTP 500 handler

`Http 500` indicates the internal error of the framework. In debug mode(`settings.debug = true`), the framework will send the exception msgs to the web browser if the length of error msgs is greater than zero. 
Otherwise, the framework will use the default error handled which has been registered before the application starts. Users could cover this handler by using their own error handler.