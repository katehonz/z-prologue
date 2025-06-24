# HTTP/2 Implementation for Prologue / Имплементация на HTTP/2 за Prologue

## English

### Overview

HTTP/2 is a major revision of the HTTP network protocol used by the World Wide Web. It focuses on performance improvements, including multiplexing, header compression, and server push. Implementing HTTP/2 support in Prologue would significantly improve the performance of applications built with the framework.

### Benefits of HTTP/2

1. **Multiplexing**: HTTP/2 allows multiple requests and responses to be sent in parallel over a single connection, eliminating the head-of-line blocking problem in HTTP/1.1.
2. **Header Compression**: HTTP/2 uses HPACK compression to reduce overhead from HTTP headers.
3. **Server Push**: HTTP/2 allows servers to proactively send resources to the client's cache before they are requested.
4. **Binary Protocol**: HTTP/2 uses a binary framing layer, which is more efficient to parse and less error-prone than the text-based HTTP/1.1.
5. **Stream Prioritization**: HTTP/2 allows clients to specify the priority of resources, ensuring critical resources are delivered first.

### Implementation Strategy

#### 1. Backend Selection

The first step is to select or implement an HTTP/2 capable backend. Options include:

- **Extending httpx**: The current httpx backend could be extended to support HTTP/2. This would require implementing the HTTP/2 protocol on top of the existing TCP socket handling.
- **Integrating with h2o**: The h2o HTTP/2 server could be integrated via its C API.
- **Using Nim HTTP/2 libraries**: If available, existing Nim HTTP/2 libraries could be integrated.

#### 2. Protocol Negotiation

Implement protocol negotiation to support both HTTP/1.1 and HTTP/2:

```nim
type ProtocolVersion = enum
  Http11, Http2

proc negotiateProtocol(request: Request): ProtocolVersion =
  if request.headers.hasKey("upgrade") and request.headers["upgrade"] == "h2c":
    return Http2
  elif request.headers.hasKey("connection") and "upgrade" in request.headers["connection"]:
    return Http2
  else:
    return Http11
```

#### 3. HTTP/2 Frame Handling

Implement handlers for different HTTP/2 frame types:

```nim
type FrameType = enum
  Data, Headers, Priority, RstStream, Settings, PushPromise, Ping, GoAway, WindowUpdate, Continuation

proc handleFrame(frameType: FrameType, frameData: string, connection: Http2Connection) {.async.} =
  case frameType:
  of Data:
    await handleDataFrame(frameData, connection)
  of Headers:
    await handleHeadersFrame(frameData, connection)
  # ... handlers for other frame types
```

#### 4. Stream Management

Implement stream management to handle multiple concurrent requests:

```nim
type Http2Stream = ref object
  id: int
  state: StreamState
  headers: HttpHeaders
  data: string
  priority: int

proc createStream(connection: Http2Connection, id: int): Http2Stream =
  result = Http2Stream(
    id: id,
    state: StreamState.Idle,
    headers: newHttpHeaders(),
    data: "",
    priority: 0
  )

proc processStream(stream: Http2Stream, app: Prologue) {.async.} =
  let request = createRequestFromStream(stream)
  let response = await app.handleRequest(request)
  await sendResponse(response, stream)
```

#### 5. HPACK Header Compression

Implement HPACK header compression for efficient header transmission:

```nim
proc encodeHeaders(headers: HttpHeaders): string =
  var encoder = newHpackEncoder()
  result = encoder.encode(headers)

proc decodeHeaders(data: string): HttpHeaders =
  var decoder = newHpackDecoder()
  result = decoder.decode(data)
```

#### 6. Server Push

Implement server push functionality to proactively send resources:

```nim
proc push(ctx: Context, path: string, headers: HttpHeaders = nil) {.async.} =
  if ctx.request.protocol == Http2:
    let pushHeaders = headers or newHttpHeaders()
    pushHeaders["path"] = path
    await sendPushPromise(ctx.connection, pushHeaders)
    let resource = await loadResource(path)
    await sendPushedResource(ctx.connection, resource)
```

#### 7. API Extensions

Extend the Prologue API to support HTTP/2 specific features:

```nim
type Http2Settings = object
  enablePush: bool
  maxConcurrentStreams: int
  initialWindowSize: int
  maxFrameSize: int
  maxHeaderListSize: int

proc newApp*(settings: Settings, http2Settings: Http2Settings = defaultHttp2Settings()): Prologue =
  result = newPrologue(settings)
  result.http2Settings = http2Settings
```

#### 8. Middleware Support

Adapt middleware to work with HTTP/2 streams:

```nim
proc http2Middleware*(next: HandlerAsync): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if ctx.request.protocol == Http2:
      # HTTP/2 specific processing
      ctx.response.headers["content-encoding"] = "br"  # Prefer Brotli for HTTP/2
    await next(ctx)
```

### Testing and Benchmarking

1. **Conformance Testing**: Test against the official HTTP/2 specification to ensure compliance.
2. **Interoperability Testing**: Test with popular HTTP/2 clients like modern browsers.
3. **Performance Benchmarking**: Compare performance with HTTP/1.1 to quantify improvements.
4. **Load Testing**: Test under high concurrency to ensure stability.

### Example Usage

```nim
import prologue
import prologue/http2

let settings = newSettings(appName = "HTTP/2 Example")
let http2Settings = newHttp2Settings(
  enablePush = true,
  maxConcurrentStreams = 100
)

var app = newApp(settings, http2Settings)

proc index(ctx: Context) {.async.} =
  # Push CSS and JS before they're requested
  await ctx.push("/static/css/style.css")
  await ctx.push("/static/js/script.js")
  
  resp "<html>...</html>"

app.get("/", index)
app.run()
```

## Български

### Преглед

HTTP/2 е основна ревизия на мрежовия протокол HTTP, използван от World Wide Web. Той се фокусира върху подобрения в производителността, включително мултиплексиране, компресия на заглавия и сървърно избутване. Имплементирането на поддръжка на HTTP/2 в Prologue значително би подобрило производителността на приложенията, изградени с фреймуърка.

### Предимства на HTTP/2

1. **Мултиплексиране**: HTTP/2 позволява множество заявки и отговори да се изпращат паралелно по една връзка, елиминирайки проблема с блокирането на опашката в HTTP/1.1.
2. **Компресия на заглавия**: HTTP/2 използва HPACK компресия за намаляване на натоварването от HTTP заглавия.
3. **Сървърно избутване**: HTTP/2 позволява на сървърите проактивно да изпращат ресурси в кеша на клиента, преди те да бъдат поискани.
4. **Бинарен протокол**: HTTP/2 използва бинарен слой за кадриране, който е по-ефективен за анализ и по-малко склонен към грешки от текстово базирания HTTP/1.1.
5. **Приоритизация на потоци**: HTTP/2 позволява на клиентите да определят приоритета на ресурсите, гарантирайки, че критичните ресурси се доставят първи.

### Стратегия за имплементация

#### 1. Избор на бекенд

Първата стъпка е да се избере или имплементира бекенд, способен на HTTP/2. Опциите включват:

- **Разширяване на httpx**: Текущият httpx бекенд може да бъде разширен, за да поддържа HTTP/2. Това би изисквало имплементиране на протокола HTTP/2 върху съществуващата обработка на TCP сокети.
- **Интегриране с h2o**: HTTP/2 сървърът h2o може да бъде интегриран чрез неговото C API.
- **Използване на Nim HTTP/2 библиотеки**: Ако са налични, съществуващи Nim HTTP/2 библиотеки могат да бъдат интегрирани.

#### 2. Договаряне на протокола

Имплементиране на договаряне на протокола за поддръжка както на HTTP/1.1, така и на HTTP/2:

```nim
type ProtocolVersion = enum
  Http11, Http2

proc negotiateProtocol(request: Request): ProtocolVersion =
  if request.headers.hasKey("upgrade") and request.headers["upgrade"] == "h2c":
    return Http2
  elif request.headers.hasKey("connection") and "upgrade" in request.headers["connection"]:
    return Http2
  else:
    return Http11
```

#### 3. Обработка на HTTP/2 кадри

Имплементиране на обработчици за различни типове HTTP/2 кадри:

```nim
type FrameType = enum
  Data, Headers, Priority, RstStream, Settings, PushPromise, Ping, GoAway, WindowUpdate, Continuation

proc handleFrame(frameType: FrameType, frameData: string, connection: Http2Connection) {.async.} =
  case frameType:
  of Data:
    await handleDataFrame(frameData, connection)
  of Headers:
    await handleHeadersFrame(frameData, connection)
  # ... обработчици за други типове кадри
```

#### 4. Управление на потоци

Имплементиране на управление на потоци за обработка на множество едновременни заявки:

```nim
type Http2Stream = ref object
  id: int
  state: StreamState
  headers: HttpHeaders
  data: string
  priority: int

proc createStream(connection: Http2Connection, id: int): Http2Stream =
  result = Http2Stream(
    id: id,
    state: StreamState.Idle,
    headers: newHttpHeaders(),
    data: "",
    priority: 0
  )

proc processStream(stream: Http2Stream, app: Prologue) {.async.} =
  let request = createRequestFromStream(stream)
  let response = await app.handleRequest(request)
  await sendResponse(response, stream)
```

#### 5. HPACK компресия на заглавия

Имплементиране на HPACK компресия на заглавия за ефективно предаване на заглавия:

```nim
proc encodeHeaders(headers: HttpHeaders): string =
  var encoder = newHpackEncoder()
  result = encoder.encode(headers)

proc decodeHeaders(data: string): HttpHeaders =
  var decoder = newHpackDecoder()
  result = decoder.decode(data)
```

#### 6. Сървърно избутване

Имплементиране на функционалност за сървърно избутване за проактивно изпращане на ресурси:

```nim
proc push(ctx: Context, path: string, headers: HttpHeaders = nil) {.async.} =
  if ctx.request.protocol == Http2:
    let pushHeaders = headers or newHttpHeaders()
    pushHeaders["path"] = path
    await sendPushPromise(ctx.connection, pushHeaders)
    let resource = await loadResource(path)
    await sendPushedResource(ctx.connection, resource)
```

#### 7. Разширения на API

Разширяване на API на Prologue за поддръжка на специфични за HTTP/2 функции:

```nim
type Http2Settings = object
  enablePush: bool
  maxConcurrentStreams: int
  initialWindowSize: int
  maxFrameSize: int
  maxHeaderListSize: int

proc newApp*(settings: Settings, http2Settings: Http2Settings = defaultHttp2Settings()): Prologue =
  result = newPrologue(settings)
  result.http2Settings = http2Settings
```

#### 8. Поддръжка на middleware

Адаптиране на middleware за работа с HTTP/2 потоци:

```nim
proc http2Middleware*(next: HandlerAsync): HandlerAsync =
  result = proc(ctx: Context) {.async.} =
    if ctx.request.protocol == Http2:
      # Специфична за HTTP/2 обработка
      ctx.response.headers["content-encoding"] = "br"  # Предпочитане на Brotli за HTTP/2
    await next(ctx)
```

### Тестване и бенчмаркинг

1. **Тестване за съответствие**: Тестване спрямо официалната спецификация на HTTP/2 за осигуряване на съответствие.
2. **Тестване за оперативна съвместимост**: Тестване с популярни HTTP/2 клиенти като модерни браузъри.
3. **Бенчмаркинг на производителността**: Сравняване на производителността с HTTP/1.1 за количествено определяне на подобренията.
4. **Тестване на натоварването**: Тестване при висока едновременност за осигуряване на стабилност.

### Пример за използване

```nim
import prologue
import prologue/http2

let settings = newSettings(appName = "HTTP/2 Example")
let http2Settings = newHttp2Settings(
  enablePush = true,
  maxConcurrentStreams = 100
)

var app = newApp(settings, http2Settings)

proc index(ctx: Context) {.async.} =
  # Избутване на CSS и JS преди да бъдат поискани
  await ctx.push("/static/css/style.css")
  await ctx.push("/static/js/script.js")
  
  resp "<html>...</html>"

app.get("/", index)
app.run()