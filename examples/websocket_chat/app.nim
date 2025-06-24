import std/[asyncdispatch, strformat, options, json, times, strutils, random]
import prologue
import prologue/websocket
import prologue/websocket/rooms
import prologue/middlewares/staticfile

# Генерация уникального ID для клиента
proc generateClientId(): string =
  let timestamp = getTime().toUnix()
  let randomPart = rand(1000..9999)
  return fmt"{timestamp}-{randomPart}"

# Обработчик для главной страницы
proc home(ctx: Context) {.async.} =
  resp readFile("templates/chat.html")

# Инициализация приложения
proc main() =
  # Создаем сервер WebSocket
  let wsServer = newWebSocketServer()
  
  # Обработчик для WebSocket соединения
  proc chatHandler(ctx: Context) {.async, gcsafe.} =
    # Получаем параметры из запроса
    let
      username = ctx.getQueryParams("username", "anonymous")
      roomName = ctx.getQueryParams("room", "general")
    
    # Создаем WebSocket соединение
    var ws = await newWebSocket(ctx)
    
    # Генерируем ID для клиента
    let clientId = generateClientId()
    
    # Создаем клиента и добавляем его на сервер
    let clientData = %* {"username": username}
    let client = newWebSocketClient(clientId, ws, clientData)
    wsServer.addClient(client)
    
    # Создаем комнату, если она не существует
    if not wsServer.rooms.hasKey(roomName):
      discard wsServer.createRoom(roomName)
    
    # Добавляем клиента в комнату
    discard wsServer.joinRoom(roomName, clientId)
    
    # Отправляем приветственное сообщение клиенту
    await client.sendToClient(fmt"Добро пожаловать в комнату {roomName}, {username}!")
    
    # Отправляем уведомление всем в комнате о новом участнике
    let joinMessage = %* {
      "type": "system",
      "content": fmt"{username} присоединился к комнате",
      "timestamp": now().format("yyyy-MM-dd HH:mm:ss")
    }
    await wsServer.sendToRoom(roomName, $joinMessage, some(clientId))
    
    # Обрабатываем сообщения от клиента
    try:
      while ws.readyState == Open:
        let packet = await ws.receiveStrPacket()
        
        # Парсим JSON сообщение
        let messageData = try:
          parseJson(packet)
        except:
          %* {"type": "text", "content": packet}
        
        # Добавляем информацию о пользователе и времени
        var fullMessage = messageData
        fullMessage["username"] = %username
        fullMessage["timestamp"] = %now().format("yyyy-MM-dd HH:mm:ss")
        
        # Отправляем сообщение всем в комнате
        await wsServer.sendToRoom(roomName, $fullMessage)
        
    except WebSocketError:
      # Соединение закрыто
      echo fmt"WebSocket connection closed for client {clientId}"
    finally:
      # Отправляем уведомление о выходе пользователя
      let leaveMessage = %* {
        "type": "system",
        "content": fmt"{username} покинул комнату",
        "timestamp": now().format("yyyy-MM-dd HH:mm:ss")
      }
      await wsServer.sendToRoom(roomName, $leaveMessage)
      
      # Удаляем клиента из комнаты и с сервера
      discard wsServer.leaveRoom(roomName, clientId)
      wsServer.removeClient(clientId)

  # Обработчик для получения списка комнат
  proc getRooms(ctx: Context) {.async, gcsafe.} =
    var rooms = newJArray()
    for roomName, room in wsServer.rooms.pairs:
      var roomInfo = %* {
        "name": roomName,
        "users": room.clients.len
      }
      rooms.add(roomInfo)
    
    ctx.response.setHeader("Content-Type", "application/json")
    resp $rooms

  # Загружаем настройки из .env файла
  let env = loadPrologueEnv(".env")
  let settings = newSettings(
    appName = env.getOrDefault("appName", "WebSocketChat"),
    debug = env.getOrDefault("debug", true),
    port = Port(env.getOrDefault("port", 8080))
  )
  
  var app = newApp(settings = settings)
  
  # Добавляем middleware для статических файлов
  app.use(staticFileMiddleware("static"))
  
  # Добавляем маршруты
  app.get("/", home)
  app.get("/ws", chatHandler)
  app.get("/api/rooms", getRooms)
  
  # Запускаем приложение
  app.run()

when isMainModule:
  randomize()  # Инициализация генератора случайных чисел
  main()