#!/usr/bin/env coffee

sendingAddress = process.argv[2]  # first argument  -- e.g. '127.0.0.1'
port = parseInt(process.argv[3])  # second argument -- e.g. 10000

WebSocketServer = require('websocket').server
http = require('http')

hServer = http.createServer (request, response) ->
  response.writeHead(404)
  response.end()
hServer.listen(port)

wsServer = new WebSocketServer(httpServer: hServer, autoAcceptConnections: false)
wsServer.on 'request', (request) ->
  connection = request.accept(null, request.origin)
  if connection.remoteAddress is sendingAddress
    connection.on 'message', (message) ->
      for c in wsServer.connections
        continue if c is connection
        c.sendBytes(message.binaryData) if c.socket.bufferSize is 0  # minimal buffering for slow connections
