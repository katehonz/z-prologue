# Роутинг в Prologue

Prologue предоставя мощна и гъвкава система за маршрутизиране (routing), която позволява лесно дефиниране на HTTP маршрути, групиране, динамични параметри и интеграция с middleware.

---

## Основни концепции

- **Route**: Път, който съответства на определен HTTP handler.
- **Handler**: Процедура, която обработва заявката.
- **HTTP методи**: Поддържат се всички стандартни (GET, POST, PUT, DELETE, PATCH и др.).
- **Route групи**: За по-лесна организация на маршрути.
- **Reversed routes**: Позволяват генериране на URL по име.

---

## Пример: Дефиниране на маршрути

```nim
import src/prologue/core/application

proc home(ctx: Context) {.async.} =
  resp "<h1>Home</h1>"

let app = newApp()
app.addRoute("/", home, HttpGet)
app.run()
```

---

## Динамични параметри

```nim
proc helloName(ctx: Context) {.async.} =
  let name = ctx.getPathParams("name", "Guest")
  resp "<h1>Hello, " & name & "!</h1>"

app.addRoute("/hello/{name}", helloName, HttpGet)
```

---

## Групиране на маршрути

```nim
let group = app.group("/api")
group.get("/users", usersHandler)
group.post("/users", createUserHandler)
```

---

## Middleware за маршрути

Можеш да добавиш middleware към конкретен маршрут или група:

```nim
app.addRoute("/secure", secureHandler, HttpGet, middlewares = @[authMiddleware])
```

---

## Reversed Routes (Обратни маршрути)

Позволяват генериране на URL по име:

```nim
app.addRoute("/profile/{id}", profileHandler, HttpGet, name = "userProfile")
let url = app.reverse("userProfile", {"id": "42"})
```

---

За повече детайли виж документацията на модула `core/route.nim` или попитай за конкретен пример!
