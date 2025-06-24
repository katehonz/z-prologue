# Copyright 2023 Prologue Contributors
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import std/[tables, asyncdispatch, options, json, logging, strformat]
import ./websocket

## Модуль для работы с комнатами и каналами WebSocket
## 
## Этот модуль предоставляет функциональность для организации WebSocket-соединений
## в комнаты и каналы, что упрощает создание чатов, многопользовательских игр
## и других приложений, требующих групповой коммуникации.

type
  WebSocketClient* = ref object
    ## Представляет клиента WebSocket
    id*: string
    ws*: WebSocket
    data*: JsonNode  # Дополнительные данные о клиенте

  Room* = ref object
    ## Представляет комнату, в которой могут находиться несколько клиентов
    name*: string
    clients*: Table[string, WebSocketClient]
    data*: JsonNode  # Метаданные комнаты

  Channel* = ref object
    ## Представляет канал для отправки сообщений определенной группе клиентов
    name*: string
    rooms*: seq[string]  # Список комнат, подписанных на канал

  WebSocketServer* = ref object
    ## Сервер WebSocket, управляющий комнатами и каналами
    rooms*: Table[string, Room]
    channels*: Table[string, Channel]
    clients*: Table[string, WebSocketClient]

proc newWebSocketClient*(id: string, ws: WebSocket, data: JsonNode = newJObject()): WebSocketClient =
  ## Создает нового клиента WebSocket
  WebSocketClient(id: id, ws: ws, data: data)

proc newRoom*(name: string, data: JsonNode = newJObject()): Room =
  ## Создает новую комнату
  Room(name: name, clients: initTable[string, WebSocketClient](), data: data)

proc newChannel*(name: string, rooms: seq[string] = @[]): Channel =
  ## Создает новый канал
  Channel(name: name, rooms: rooms)

proc newWebSocketServer*(): WebSocketServer =
  ## Создает новый сервер WebSocket
  WebSocketServer(
    rooms: initTable[string, Room](),
    channels: initTable[string, Channel](),
    clients: initTable[string, WebSocketClient]()
  )

proc addClient*(server: WebSocketServer, client: WebSocketClient) =
  ## Добавляет клиента на сервер
  server.clients[client.id] = client
  logging.debug fmt"Client {client.id} connected"

proc removeClient*(server: WebSocketServer, clientId: string) =
  ## Удаляет клиента с сервера и из всех комнат
  if server.clients.hasKey(clientId):
    let client = server.clients[clientId]
    
    # Удаляем клиента из всех комнат
    for roomName, room in server.rooms.pairs:
      if room.clients.hasKey(clientId):
        room.clients.del(clientId)
        logging.debug fmt"Client {clientId} removed from room {roomName}"
    
    # Удаляем клиента из списка клиентов
    server.clients.del(clientId)
    logging.debug fmt"Client {clientId} disconnected"

proc createRoom*(server: WebSocketServer, name: string, data: JsonNode = newJObject()): Room =
  ## Создает новую комнату на сервере
  if server.rooms.hasKey(name):
    return server.rooms[name]
  
  let room = newRoom(name, data)
  server.rooms[name] = room
  logging.debug fmt"Room {name} created"
  return room

proc joinRoom*(server: WebSocketServer, roomName: string, clientId: string): bool =
  ## Добавляет клиента в комнату
  if not server.clients.hasKey(clientId):
    logging.error fmt"Client {clientId} not found"
    return false
  
  if not server.rooms.hasKey(roomName):
    discard server.createRoom(roomName)
  
  let 
    client = server.clients[clientId]
    room = server.rooms[roomName]
  
  room.clients[clientId] = client
  logging.debug fmt"Client {clientId} joined room {roomName}"
  return true

proc leaveRoom*(server: WebSocketServer, roomName: string, clientId: string): bool =
  ## Удаляет клиента из комнаты
  if not server.rooms.hasKey(roomName):
    logging.error fmt"Room {roomName} not found"
    return false
  
  if not server.clients.hasKey(clientId):
    logging.error fmt"Client {clientId} not found"
    return false
  
  let room = server.rooms[roomName]
  if not room.clients.hasKey(clientId):
    logging.error fmt"Client {clientId} not in room {roomName}"
    return false
  
  room.clients.del(clientId)
  logging.debug fmt"Client {clientId} left room {roomName}"
  
  # Если комната пуста, удаляем ее
  if room.clients.len == 0:
    server.rooms.del(roomName)
    logging.debug fmt"Room {roomName} deleted (empty)"
  
  return true

proc createChannel*(server: WebSocketServer, name: string, rooms: seq[string] = @[]): Channel =
  ## Создает новый канал на сервере
  if server.channels.hasKey(name):
    return server.channels[name]
  
  let channel = newChannel(name, rooms)
  server.channels[name] = channel
  logging.debug fmt"Channel {name} created"
  return channel

proc addRoomToChannel*(server: WebSocketServer, channelName: string, roomName: string): bool =
  ## Добавляет комнату в канал
  if not server.channels.hasKey(channelName):
    discard server.createChannel(channelName)
  
  if not server.rooms.hasKey(roomName):
    logging.error fmt"Room {roomName} not found"
    return false
  
  let channel = server.channels[channelName]
  if roomName notin channel.rooms:
    channel.rooms.add(roomName)
    logging.debug fmt"Room {roomName} added to channel {channelName}"
  
  return true

proc removeRoomFromChannel*(server: WebSocketServer, channelName: string, roomName: string): bool =
  ## Удаляет комнату из канала
  if not server.channels.hasKey(channelName):
    logging.error fmt"Channel {channelName} not found"
    return false
  
  let channel = server.channels[channelName]
  let index = channel.rooms.find(roomName)
  if index == -1:
    logging.error fmt"Room {roomName} not in channel {channelName}"
    return false
  
  channel.rooms.delete(index)
  logging.debug fmt"Room {roomName} removed from channel {channelName}"
  
  # Если канал пуст, удаляем его
  if channel.rooms.len == 0:
    server.channels.del(channelName)
    logging.debug fmt"Channel {channelName} deleted (empty)"
  
  return true

proc sendToClient*(client: WebSocketClient, message: string) {.async.} =
  ## Отправляет сообщение клиенту
  if client.ws.readyState == Open:
    await client.ws.send(message)
    logging.debug fmt"Message sent to client {client.id}"

proc sendToRoom*(server: WebSocketServer, roomName: string, message: string, 
                 excludeClientId: Option[string] = none(string)) {.async.} =
  ## Отправляет сообщение всем клиентам в комнате
  if not server.rooms.hasKey(roomName):
    logging.error fmt"Room {roomName} not found"
    return
  
  let room = server.rooms[roomName]
  var sentCount = 0
  
  for clientId, client in room.clients.pairs:
    if excludeClientId.isSome and clientId == excludeClientId.get:
      continue
    
    if client.ws.readyState == Open:
      await client.ws.send(message)
      sentCount += 1
  
  logging.debug fmt"Message sent to {sentCount} clients in room {roomName}"

proc sendToChannel*(server: WebSocketServer, channelName: string, message: string,
                   excludeClientId: Option[string] = none(string)) {.async.} =
  ## Отправляет сообщение всем клиентам во всех комнатах канала
  if not server.channels.hasKey(channelName):
    logging.error fmt"Channel {channelName} not found"
    return
  
  let channel = server.channels[channelName]
  var sentCount = 0
  
  for roomName in channel.rooms:
    if server.rooms.hasKey(roomName):
      let room = server.rooms[roomName]
      
      for clientId, client in room.clients.pairs:
        if excludeClientId.isSome and clientId == excludeClientId.get:
          continue
        
        if client.ws.readyState == Open:
          await client.ws.send(message)
          sentCount += 1
  
  logging.debug fmt"Message sent to {sentCount} clients in channel {channelName}"

proc broadcast*(server: WebSocketServer, message: string, 
               excludeClientId: Option[string] = none(string)) {.async.} =
  ## Отправляет сообщение всем подключенным клиентам
  var sentCount = 0
  
  for clientId, client in server.clients.pairs:
    if excludeClientId.isSome and clientId == excludeClientId.get:
      continue
    
    if client.ws.readyState == Open:
      await client.ws.send(message)
      sentCount += 1
  
  logging.debug fmt"Message broadcasted to {sentCount} clients"

when isMainModule:
  # Пример использования
  proc testWebSocketRooms() {.async.} =
    let server = newWebSocketServer()
    
    # Создаем комнаты
    discard server.createRoom("room1")
    discard server.createRoom("room2")
    
    # Создаем канал
    discard server.createChannel("channel1", @["room1", "room2"])
    
    echo "WebSocket rooms test completed"
  
  waitFor testWebSocketRooms()