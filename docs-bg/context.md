# Контекст в Prologue

Контекстът (Context) е сърцето на обработката на заявки в Prologue. Той инкапсулира цялото състояние на HTTP заявка и отговор, и се подава на всеки handler и middleware. Чрез контекста имаш достъп до данните на заявката, можеш да управляваш отговора, да използваш сесии и flash съобщения, както и да контролираш потока на middleware-ите.

---

## Основни концепции

- **Контекст**: Представлява състоянието за всеки HTTP request/response цикъл.
- **Handler**: Получава Context обект и обработва заявката.
- **Middleware**: Функции, които могат да инспектират или променят контекста преди или след основния handler.
- **Глобален обхват (Global Scope)**: Данни, достъпни във всеки контекст.

---

## Пример: Използване на Context в handler

```nim
proc hello(ctx: Context) {.async.} =
  let userAgent = ctx.request.headers["User-Agent"]
  ctx.response.body = "<h1>Здравей!</h1><p>Браузър: " & userAgent & "</p>"
```

---

## Достъп до заявка и отговор

- `ctx.request`: Всички данни за заявката (headers, params, body и др.)
- `ctx.response`: Задаване на тяло, статус, headers и др.

```nim
proc info(ctx: Context) {.async.} =
  let method = ctx.request.httpMethod
  let path = ctx.request.url.path
  resp "<b>Метод:</b> " & $method & "<br><b>Път:</b> " & path
```

---

## Middleware и Context

Middleware процедурите също получават контекста и могат да го четат или променят. Middleware може да е глобален или само за конкретен маршрут.

```nim
proc logMiddleware(ctx: Context) {.async.} =
  echo "Заявка: ", ctx.request.url
  await switch(ctx) # продължава към следващия middleware/handler

app.use(logMiddleware)
```

---

## Сесии и Flash съобщения

Контекстът предоставя достъп до сесии и flash съобщения за съхранение на състояние и нотификации за потребителя.

```nim
ctx.session["userId"] = "42"
ctx.flash("Добре дошъл!", category = Info)
```

---

## Глобален обхват

Можеш да съхраняваш данни за цялото приложение в глобалния обхват, достъпни чрез `ctx.gScope`.

---

За повече информация виж модула `core/context.nim` или попитай за напреднали примери!
