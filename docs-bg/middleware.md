# Middleware в Prologue

Middleware в Prologue ти позволява да прихващаш, модифицираш или прекъсваш обработката на HTTP заявки и отговори. Middleware може да е глобален (за всички заявки) или към конкретен маршрут/група. Изпълняват се в реда, в който са регистрирани.

---

## Основни концепции

- **Middleware**: Функция, която получава `Context` и може да извърши действия преди или след основния handler.
- **Верижност (Chaining)**: Middleware извиква `await switch(ctx)`, за да предаде управлението нататък.
- **Глобален middleware**: Регистрира се с `app.use()` и важи за всички маршрути.
- **Middleware за маршрут**: Добавя се към конкретен маршрут или група.

---

## Пример: Глобален middleware

```nim
proc logMiddleware(ctx: Context) {.async.} =
  echo "Заявка: ", ctx.request.url
  await switch(ctx) # Продължава към следващия middleware или handler

app.use(logMiddleware)
```

---

## Пример: Middleware за маршрут

```nim
proc authMiddleware(ctx: Context) {.async.} =
  if not ctx.session.hasKey("userId"):
    resp "<h1>Нямаш достъп</h1>", code = Http401
  else:
    await switch(ctx)

app.addRoute("/secure", secureHandler, HttpGet, middlewares = @[authMiddleware])
```

---

## Верижност и ред на изпълнение

- Middleware се изпълняват в реда, в който са регистрирани.
- Ако даден middleware не извика `await switch(ctx)`, веригата спира и отговорът се връща веднага.
- Можеш да използваш както глобални, така и специфични за маршрут middleware-и.

---

## Практически съвети

- Използвай middleware за логване, автентикация, обработка на грешки, CORS и др.
- Middleware може да модифицира контекста, да задава response headers или директно да генерира отговор.
- Дръж middleware-ите фокусирани и лесни за комбиниране.

---

За повече информация виж модула `core/middlewaresbase.nim` или попитай за напреднали примери!
