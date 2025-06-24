# Prologue WebSocket Chat / Prologue WebSocket Чат

## English

### Overview

This example demonstrates the use of WebSocket with rooms and channels in the Prologue framework. It implements a real-time chat application where users can join different rooms and communicate with each other.

### Features

- Multi-user chat with room support
- Dynamic room creation
- User join/leave notifications
- Fully asynchronous message handling
- Modern user interface

### Project Structure

- `app.nim` - main application file
- `templates/chat.html` - HTML template for the chat interface
- `.env` - application settings file
- `README.md` - this documentation file

### Used Prologue Modules

- `prologue/websocket` - basic WebSocket support
- `prologue/websocket/rooms` - WebSocket rooms and channels support
- `prologue/middlewares/staticfile` - middleware for static files

### Running the Example

1. Make sure you have Nim and Prologue installed
2. Navigate to the example directory: `cd examples/websocket_chat`
3. Compile and run the application: `nim c -r app.nim`
4. Open your browser and go to: `http://localhost:8080`

### Usage

1. Enter your name and room name (default is "general")
2. Click the "Join" button
3. Start chatting in the room
4. You can create a new room by entering its name in the "Create new room" field and clicking the "Create" button
5. You can switch between rooms by clicking on them in the room list

### Extending Functionality

This example can be extended by adding:

- Private messaging between users
- File attachment support
- Message history storage
- User authentication
- Message moderation

### Technical Details

The example uses the new `prologue/websocket/rooms` module, which provides the following capabilities:

- Creating and managing rooms
- Adding and removing clients from rooms
- Sending messages to rooms
- Creating and managing channels
- Sending messages to channels
- Broadcasting messages

All operations are performed asynchronously, ensuring high performance even with a large number of connected clients.

## Български

### Преглед

Този пример демонстрира използването на WebSocket със стаи и канали във фреймуърка Prologue. Той реализира приложение за чат в реално време, където потребителите могат да се присъединяват към различни стаи и да комуникират помежду си.

### Функции

- Многопотребителски чат с поддръжка на стаи
- Динамично създаване на стаи
- Известия за присъединяване/напускане на потребители
- Напълно асинхронна обработка на съобщения
- Модерен потребителски интерфейс

### Структура на проекта

- `app.nim` - основен файл на приложението
- `templates/chat.html` - HTML шаблон за интерфейса на чата
- `.env` - файл с настройки на приложението
- `README.md` - тази документация

### Използвани модули на Prologue

- `prologue/websocket` - базова поддръжка на WebSocket
- `prologue/websocket/rooms` - поддръжка на WebSocket стаи и канали
- `prologue/middlewares/staticfile` - middleware за статични файлове

### Стартиране на примера

1. Уверете се, че имате инсталирани Nim и Prologue
2. Навигирайте до директорията на примера: `cd examples/websocket_chat`
3. Компилирайте и стартирайте приложението: `nim c -r app.nim`
4. Отворете браузъра си и отидете на: `http://localhost:8080`

### Използване

1. Въведете вашето име и име на стая (по подразбиране е "general")
2. Кликнете върху бутона "Присъединяване"
3. Започнете да чатите в стаята
4. Можете да създадете нова стая, като въведете нейното име в полето "Създаване на нова стая" и кликнете върху бутона "Създаване"
5. Можете да превключвате между стаите, като кликвате върху тях в списъка със стаи

### Разширяване на функционалността

Този пример може да бъде разширен чрез добавяне на:

- Лични съобщения между потребители
- Поддръжка на прикачени файлове
- Съхранение на история на съобщенията
- Автентикация на потребители
- Модерация на съобщения

### Технически детайли

Примерът използва новия модул `prologue/websocket/rooms`, който предоставя следните възможности:

- Създаване и управление на стаи
- Добавяне и премахване на клиенти от стаи
- Изпращане на съобщения до стаи
- Създаване и управление на канали
- Изпращане на съобщения до канали
- Излъчване на съобщения

Всички операции се извършват асинхронно, осигурявайки висока производителност дори при голям брой свързани клиенти.