# WebSocket Rooms / WebSocket Стаи

## English

### Overview

The WebSocket Rooms module provides functionality for organizing WebSocket connections into rooms and channels. This makes it easier to create chat applications, multiplayer games, and other applications that require group communication.

### Features

- Create and manage rooms for WebSocket clients
- Add and remove clients from rooms
- Send messages to specific rooms
- Create and manage channels (groups of rooms)
- Send messages to channels
- Broadcast messages to all connected clients

### Usage

```nim
import prologue
import prologue/websocket
import prologue/websocket/rooms

# Create a WebSocket server
let wsServer = newWebSocketServer()

# Create a room
let room = wsServer.createRoom("chatroom")

# Create a WebSocket client
let ws = await newWebSocket(ctx)
let client = newWebSocketClient("client1", ws)

# Add client to server
wsServer.addClient(client)

# Add client to room
discard wsServer.joinRoom("chatroom", "client1")

# Send message to room
await wsServer.sendToRoom("chatroom", "Hello everyone in the room!")

# Create a channel
let channel = wsServer.createChannel("news", @["chatroom"])

# Send message to channel
await wsServer.sendToChannel("news", "Breaking news!")

# Broadcast to all clients
await wsServer.broadcast("Server announcement")
```

### API Reference

#### Types

- `WebSocketClient`: Represents a WebSocket client
- `Room`: Represents a room that can contain multiple clients
- `Channel`: Represents a channel that can contain multiple rooms
- `WebSocketServer`: Manages rooms, channels, and clients

#### Functions

- `newWebSocketServer()`: Creates a new WebSocket server
- `newWebSocketClient(id, ws, data)`: Creates a new WebSocket client
- `newRoom(name, data)`: Creates a new room
- `newChannel(name, rooms)`: Creates a new channel
- `addClient(server, client)`: Adds a client to the server
- `removeClient(server, clientId)`: Removes a client from the server
- `createRoom(server, name, data)`: Creates a new room on the server
- `joinRoom(server, roomName, clientId)`: Adds a client to a room
- `leaveRoom(server, roomName, clientId)`: Removes a client from a room
- `createChannel(server, name, rooms)`: Creates a new channel on the server
- `addRoomToChannel(server, channelName, roomName)`: Adds a room to a channel
- `removeRoomFromChannel(server, channelName, roomName)`: Removes a room from a channel
- `sendToClient(client, message)`: Sends a message to a client
- `sendToRoom(server, roomName, message, excludeClientId)`: Sends a message to all clients in a room
- `sendToChannel(server, channelName, message, excludeClientId)`: Sends a message to all clients in all rooms of a channel
- `broadcast(server, message, excludeClientId)`: Sends a message to all connected clients

## Български

### Преглед

Модулът WebSocket Стаи предоставя функционалност за организиране на WebSocket връзки в стаи и канали. Това улеснява създаването на чат приложения, мултиплейър игри и други приложения, които изискват групова комуникация.

### Функции

- Създаване и управление на стаи за WebSocket клиенти
- Добавяне и премахване на клиенти от стаи
- Изпращане на съобщения до конкретни стаи
- Създаване и управление на канали (групи от стаи)
- Изпращане на съобщения до канали
- Излъчване на съобщения до всички свързани клиенти

### Използване

```nim
import prologue
import prologue/websocket
import prologue/websocket/rooms

# Създаване на WebSocket сървър
let wsServer = newWebSocketServer()

# Създаване на стая
let room = wsServer.createRoom("chatroom")

# Създаване на WebSocket клиент
let ws = await newWebSocket(ctx)
let client = newWebSocketClient("client1", ws)

# Добавяне на клиент към сървъра
wsServer.addClient(client)

# Добавяне на клиент към стая
discard wsServer.joinRoom("chatroom", "client1")

# Изпращане на съобщение до стая
await wsServer.sendToRoom("chatroom", "Здравейте на всички в стаята!")

# Създаване на канал
let channel = wsServer.createChannel("news", @["chatroom"])

# Изпращане на съобщение до канал
await wsServer.sendToChannel("news", "Последни новини!")

# Излъчване до всички клиенти
await wsServer.broadcast("Съобщение от сървъра")
```

### API Референция

#### Типове

- `WebSocketClient`: Представлява WebSocket клиент
- `Room`: Представлява стая, която може да съдържа множество клиенти
- `Channel`: Представлява канал, който може да съдържа множество стаи
- `WebSocketServer`: Управлява стаи, канали и клиенти

#### Функции

- `newWebSocketServer()`: Създава нов WebSocket сървър
- `newWebSocketClient(id, ws, data)`: Създава нов WebSocket клиент
- `newRoom(name, data)`: Създава нова стая
- `newChannel(name, rooms)`: Създава нов канал
- `addClient(server, client)`: Добавя клиент към сървъра
- `removeClient(server, clientId)`: Премахва клиент от сървъра
- `createRoom(server, name, data)`: Създава нова стая на сървъра
- `joinRoom(server, roomName, clientId)`: Добавя клиент към стая
- `leaveRoom(server, roomName, clientId)`: Премахва клиент от стая
- `createChannel(server, name, rooms)`: Създава нов канал на сървъра
- `addRoomToChannel(server, channelName, roomName)`: Добавя стая към канал
- `removeRoomFromChannel(server, channelName, roomName)`: Премахва стая от канал
- `sendToClient(client, message)`: Изпраща съобщение до клиент
- `sendToRoom(server, roomName, message, excludeClientId)`: Изпраща съобщение до всички клиенти в стая
- `sendToChannel(server, channelName, message, excludeClientId)`: Изпраща съобщение до всички клиенти във всички стаи на канал
- `broadcast(server, message, excludeClientId)`: Изпраща съобщение до всички свързани клиенти