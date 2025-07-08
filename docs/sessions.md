# Sessions and Flash Messages in Prologue

Prologue provides built-in support for sessions and flash messages, enabling you to store state between requests and send short-lived notifications to users.

---

## Main Concepts

- **Session:** Allows you to store data for each user across requests.
- **Flash messages:** One-time messages (e.g. for success or error) shown on the next request.

---

## Example: Using Sessions

```nim
proc login(ctx: Context) {.async.} =
  ctx.session["userId"] = "42"
  resp "<h1>Login successful!</h1>"

proc profile(ctx: Context) {.async.} =
  let userId = ctx.session.getOrDefault("userId", "Guest")
  resp "<h1>User profile: " & userId & "</h1>"
```

---

## Example: Flash Messages

```nim
proc register(ctx: Context) {.async.} =
  ctx.flash("Registration successful!", category = Info)
  redirect("/login")

proc login(ctx: Context) {.async.} =
  let msg = ctx.getMessage(Info)
  resp "<h1>Login</h1>" & (if msg.isSome: "<p>" & msg.get & "</p>" else: "")
```

---

## Practical Tips

- Use sessions for authentication, user preferences, and other per-user data that must persist between requests.
- Flash messages are ideal for one-time notifications after a redirect.
- Do not store sensitive data in session without encryption!

---

For more, see the `core/types.nim` and `core/context.nim` modules or ask for advanced examples!
