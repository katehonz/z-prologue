# JWT Authentication Example / Пример за JWT Аутентикация

## English

### Overview

This example demonstrates the use of JWT (JSON Web Tokens) for authentication and authorization in Prologue applications. It implements a simple authentication system with role-based access control.

### Features

- User authentication using JWT
- Route protection with JWT middleware
- Role-based authorization
- Configurable token parameters (lifetime, issuer, audience)
- Various token delivery methods (header, query parameter, cookie)

### Project Structure

- `app.nim` - main application file with JWT usage example
- `.env` - application settings file
- `README.md` - this documentation file

### Used Prologue Modules

- `prologue/auth/jwt` - JWT authentication module

### Running the Example

1. Make sure you have Nim and Prologue installed
2. Navigate to the example directory: `cd examples/jwt_auth`
3. Compile and run the application: `nim c -r app.nim`
4. Open your browser and go to: `http://localhost:8080`

### Usage

1. Open the main page and log in using one of the following accounts:
   - Regular user: username = "user1", password = "password1"
   - Administrator: username = "admin", password = "admin123"
2. After successful login, you will receive a JWT token
3. Use this token to access protected routes:
   - `/api/user` - accessible to all authenticated users
   - `/api/admin` - accessible only to users with the "admin" role

### Request Examples

#### Login

```bash
curl -X POST -d "username=admin&password=admin123" http://localhost:8080/login
```

#### Accessing a Protected Route

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/user
```

### Technical Details

The example uses the new `prologue/auth/jwt` module, which provides the following capabilities:

- Creating JWT tokens with customizable parameters
- Verifying JWT tokens
- Middleware for automatic token verification
- Extracting information from tokens (subject, roles, etc.)
- Support for various signature algorithms (HS256, HS384, HS512)

All JWT operations are performed using standard Nim libraries, without external dependencies.

### Security Considerations

In a real application, you should consider the following recommendations:

1. Use HTTPS to protect token transmission
2. Store the secret key in a secure location (not in code)
3. Set reasonable token lifetimes
4. Implement a token refresh mechanism
5. Store user passwords in hashed form
6. Use a token revocation mechanism if necessary

## Български

### Преглед

Този пример демонстрира използването на JWT (JSON Web Tokens) за аутентикация и авторизация в приложения с Prologue. Той реализира проста система за аутентикация с контрол на достъпа, базиран на роли.

### Функции

- Аутентикация на потребители с използване на JWT
- Защита на маршрути с JWT middleware
- Авторизация, базирана на роли
- Конфигурируеми параметри на токена (време на живот, издател, аудитория)
- Различни методи за доставка на токени (заглавие, параметър на заявката, бисквитка)

### Структура на проекта

- `app.nim` - основен файл на приложението с пример за използване на JWT
- `.env` - файл с настройки на приложението
- `README.md` - тази документация

### Използвани модули на Prologue

- `prologue/auth/jwt` - модул за JWT аутентикация

### Стартиране на примера

1. Уверете се, че имате инсталирани Nim и Prologue
2. Навигирайте до директорията на примера: `cd examples/jwt_auth`
3. Компилирайте и стартирайте приложението: `nim c -r app.nim`
4. Отворете браузъра си и отидете на: `http://localhost:8080`

### Използване

1. Отворете главната страница и влезте, използвайки една от следните акаунти:
   - Обикновен потребител: потребителско име = "user1", парола = "password1"
   - Администратор: потребителско име = "admin", парола = "admin123"
2. След успешно влизане ще получите JWT токен
3. Използвайте този токен за достъп до защитени маршрути:
   - `/api/user` - достъпен за всички аутентикирани потребители
   - `/api/admin` - достъпен само за потребители с роля "admin"

### Примери за заявки

#### Вход

```bash
curl -X POST -d "username=admin&password=admin123" http://localhost:8080/login
```

#### Достъп до защитен маршрут

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/user
```

### Технически детайли

Примерът използва новия модул `prologue/auth/jwt`, който предоставя следните възможности:

- Създаване на JWT токени с персонализируеми параметри
- Проверка на JWT токени
- Middleware за автоматична проверка на токени
- Извличане на информация от токени (subject, роли и т.н.)
- Поддръжка на различни алгоритми за подпис (HS256, HS384, HS512)

Всички JWT операции се извършват с използване на стандартни библиотеки на Nim, без външни зависимости.

### Съображения за сигурност

В реално приложение трябва да имате предвид следните препоръки:

1. Използвайте HTTPS за защита на предаването на токени
2. Съхранявайте тайния ключ на сигурно място (не в кода)
3. Задайте разумно време на живот на токените
4. Реализирайте механизъм за опресняване на токени
5. Съхранявайте паролите на потребителите в хеширана форма
6. Използвайте механизъм за отмяна на токени, ако е необходимо